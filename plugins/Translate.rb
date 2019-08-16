require 'cinch'
require 'net/http'
require 'json'
require 'cgi'

class Translate
  include Cinch::Plugin

  match /2en (.+)/, method: :auto2eng
  match /trans (.+)/, method: :trans
  def auto2eng(m, query)
    m.reply fetch(query, from: 'auto', to: 'en')
  end

  def trans(m, query)
    params = Hash[query.split(/\; ?/).map {|x| x.split(/\: ?/)}]
    m.reply fetch(params['text'] || params.key(nil), from: params['from'] || 'auto', to: params['to'] || 'en')
  end


  def fetch(text, from: 'auto', to: 'en')
    uri = URI('https://translate.googleapis.com/translate_a/single')
    uri.query = URI.encode_www_form({
      client: :gtx,
      sl: from,
      tl: to,
      dt: :t,
      q: CGI.escape(text),
      format: :text
    })
    res = Net::HTTP.get_response(uri)
    return "Bad request" unless res.is_a? Net::HTTPOK
    CGI.unescape(JSON.parse(res.body).first.first.first.delete(' ')).sub(/^ /, '')
  end
end
