require "sinatra/base"
require "rack/ssl" unless ENV['RACK_ENV'] == "development"
require "omniauth"
require "omniauth-salesforce"
require "haml"


class OmniAuthSalesforceExample < Sinatra::Base

  use Rack::SSL unless ENV['RACK_ENV'] == "development"
  use Rack::Session::Pool

  configure do
    set :app_file,        __FILE__
    set :port,            ENV['PORT']
    set :raise_errors,    Proc.new { false }
    set :show_exceptions, false
  end

  use OmniAuth::Builder do
    provider :salesforce, 
             ENV['SALESFORCE_KEY'], 
             ENV['SALESFORCE_SECRET']
    provider OmniAuth::Strategies::SalesforceSandbox, 
             ENV['SALESFORCE_SANDBOX_KEY'], 
             ENV['SALESFORCE_SANDBOX_SECRET']
    provider OmniAuth::Strategies::SalesforcePreRelease, 
             ENV['SALESFORCE_PRERELEASE_KEY'], 
             ENV['SALESFORCE_PRERELEASE_SECRET']
    provider OmniAuth::Strategies::DatabaseDotCom, 
             ENV['DATABASE_DOT_COM_KEY'], 
             ENV['DATABASE_DOT_COM_SECRET']
  end

  post '/authenticate' do
    provider = sanitize_provider(params[:options]['provider'])
    auth_params = {
      :display => params[:options]['display'],
      :immediate => params[:options]['immediate'],
      :scope => params[:options].to_a.flatten.keep_if{|v| v.start_with? "scope|"}.collect!{|v| v.sub(/scope\|/,"")}.join(" ")
    }
    auth_params = URI.escape(auth_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
    redirect "/auth/#{provider}?#{auth_params}"
  end

  get '/unauthenticate' do
    request.env['rack.session'] = {}
    redirect '/'  
  end
  
  get '/auth/:provider/callback' do
    session[:auth_hash] = env['omniauth.auth']
    redirect '/' unless session[:auth_hash] == nil
  end

  get '/*' do
    haml :index 
  end

  error do
    haml :error
  end

  helpers do
    def sanitize_provider(provider = nil)
      provider.strip!    unless provider == nil
      provider.downcase! unless provider == nil
      provider = "salesforce" unless %w(salesforcesandbox salesforceprerelease databasedotcom).include? provider
      provider
    end

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
  
  run! if app_file == $0

end


