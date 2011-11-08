require "sinatra"
require "omniauth"
require "omniauth-salesforce"
require "haml"

#OmniAuth.config.on_failure do |env|
#  puts "#{env['omniauth.error'].class.to_s}: #{env['omniauth.error'].message}"
#  env['omniauth.error'].backtrace.each{|b| puts b}
#  puts env['omniauth.error'].response.inspect if env['omniauth.error'].respond_to?(:response)
#  [302, {'Location' => '/auth/failure'}, ['302 Redirect']]
#end

set :root, File.dirname(__FILE__) + '/../'

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :salesforce, ENV['SALESFORCE_KEY'], ENV['SALESFORCE_SECRET']
end

get '/' do
  haml :index
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do
    session[:auth_hash] = env['omniauth.auth']
    redirect '/' unless session[:auth_hash] == nil
  end
end

get '/logout' do
  request.env['rack.session'] = {}
  redirect '/'
end

helpers do
  def htmlize_hash(hash, nested = false)
    output = "<table class='hash'>"
    hash.each_pair do |key, value|
      output << "<tr><th>#{key}</th><td>"
      case value
      when Hash
        if nested
          output << "<span class='object'>Hash</span>"
        else
          output << htmlize_hash(value, true)
        end
      when String
        output << value
      else
        output << "<span class='object'>#{value.class.to_s}</span>"
      end
      output << "</td></tr>"
    end
    output << "</table>"
    output
  end
end