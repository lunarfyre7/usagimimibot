# frozen_string_literal: true

require 'ostruct'
require 'sequel'
require 'singleton'

$help_data ||= {} #bad bad bad

module Usagi
  if ENV['ENVIRONMENT'] == 'test'
    DB = Sequel.sqlite
  else
    DB = Sequel.connect('sqlite://detabesu.db')
  end
  class<<self
    def settings
      @settings ||= OpenStruct.new
    end
  end

  class Store
    ALLOWED_TYPES = %w[String Float Integer Boolean].freeze
    BOOL_TRUE = 't'
    BOOL_FALSE = 'f'
    TRUTHY = %w[t T true True]
    FALSY = %w[f F False false]
    include Singleton
    def initialize
      DB.create_table? :usagi_store do
        primary_key :id
        String :key
        String :type
        index :key, unique: true
        String :value
      end
      @sema = Mutex.new
    end

    def [](key)
      key = key.to_s
      entry = DB[:usagi_store].where(key: key).first
      return unless entry
      throw 'Invalid stored type' unless ALLOWED_TYPES.include? entry[:type]

      val = entry[:value]
      return (val == BOOL_TRUE) if entry[:type] == 'Boolean'
      method(entry[:type]).call val
    end

    def []=(key, value)
      key = key.to_s
      type = 'String'
      # type = 'String'
      # type = 'Float' if value.is_a?(Float) || (value.is_a?(String) && value&.is_float?)
      # type = 'Integer' if value.is_a?(Integer)  || (value.is_a?(String) && value&.is_i?)
      if value.is_a?(String) && value[/(^\'.*\'$)|(^\".*\"$)/]
        value = value[/^['"](.*)['"]$/, 1]
        type = "String"
      elsif value.is_a?(Float) || (value.is_a?(String) && value&.is_float?)
        type = 'Float'
      elsif value.is_a?(Integer)  || (value.is_a?(String) && value&.is_i?)
        type = 'Integer'
      elsif value == 'nil' || value.nil?
        type = 'nil'
      elsif value.is_a?(TrueClass) || value.is_a?(FalseClass) || TRUTHY.include?(value) || FALSY.include?(value)
        type = 'Boolean'
        value = TRUTHY.include?(value) ? BOOL_TRUE : BOOL_FALSE
      end
      @sema.synchronize do
        if type == 'nil'
          DB[:usagi_store].where(key: key).delete
        elsif DB[:usagi_store].where(key: key).first
          DB[:usagi_store].where(key: key).update(value: value, type: type)
        else
          DB[:usagi_store].insert(key: key, value: value.to_s, type: type)
        end
      end
    end
  end
  STORE = Store.instance

  module Sugar
    def command(regex, &block)
      name = (0..20).map{('a'..'z').to_a.sample}.join.to_sym
      match regex, method: name
      define_method(name, &block)
    end
  end

  
  module Help
    def info command, message
      #help is already taken
      $help_data[self.name.downcase] ||= {}
      $help_data[self.name.downcase][command.downcase] = message
      puts 'HELP DATA'
      pp $help_data
    end
  end
end

class String
  def from_json
    JSON.parse(self, object_class: OpenStruct)
  end

  def is_i?
    /\A[-+]?\d+\z/ === self
  end

  def is_float?
  !!Float(self) rescue false
  end
end
