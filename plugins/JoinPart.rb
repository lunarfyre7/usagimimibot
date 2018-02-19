require 'cinch'

class JoinPart
  include Cinch::Plugin

  match /join (.+)/, method: :join
  match /part(?: (.+))?/, method: :part

  def initialize(*args)
    super

    @admins = [""]
  end

  def check_user(user)
    user.refresh # be sure to refresh the data, or someone could steal
                 # the nick
    @admins.include?(user.authname)
  end

  def join(m, channel)
    #return unless check_user(m.user)
    Channel(channel).join
  end

  def part(m, channel)
    #return unless check_user(m.user)
    channel ||= m.channel
    Channel(channel).part if channel
  end
end
