require "sinatra"
require "omniauth"
require "omniauth-salesforce"
require "haml"

set :root, File.dirname(__FILE__) + '/../'

OmniAuth.config.on_failure do |env|
  puts "#{env['omniauth.error'].class.to_s}: #{env['omniauth.error'].message}"
  env['omniauth.error'].backtrace.each{|b| puts b}
  puts env['omniauth.error'].response.inspect if env['omniauth.error'].respond_to?(:response)

  [302, {'Location' => '/auth/failure'}, ['302 Redirect']]
end

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
  def htmlize_hash(title, hash)
    hashes = nil
    strings = nil
    hash.each_pair do |key, value|
      case value
      when Hash
        hashes ||= ""
        hashes << htmlize_hash(key,value)
      else
        strings ||= "<table>"
        strings << "<tr><th scope='row'>#{key}</th><td>#{value}</td></tr>"
      end
    end
    output = "<div data-role='collapsible' data-theme='b' data-content-theme='b'><h3>#{title}</h3>"
    output << strings unless strings.nil?
    output << "</table>" unless strings.nil?
    output << hashes unless hashes.nil?
    output << "</div>"
    output
  end
end