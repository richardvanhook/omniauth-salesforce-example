require "sinatra/base"
require "rack/ssl" unless ENV['RACK_ENV'] == "development"
require "haml"
require "omniauth"
require "omniauth-salesforce"

class OmniAuthSalesforceExample < Sinatra::Base

  configure do
    enable :logging
    set :app_file,        __FILE__
    set :root,            File.expand_path("../..",__FILE__)
    set :port,            ENV['PORT']
    set :raise_errors,    Proc.new { false }
    set :show_exceptions, false
  end

  use Rack::SSL unless ENV['RACK_ENV'] == "development"
  use Rack::Session::Pool

  OmniAuth.config.on_failure do |env|
    
    logger.info "#{env['omniauth.error'].class.to_s}: #{env['omniauth.error'].message}"
    logger.info "code: #{env['omniauth.error'].code}"
    logger.info "response: #{env['omniauth.error'].response}"
    env['omniauth.error'].backtrace.each{|b| logger.info b}
    logger.info env['omniauth.error'].response.inspect if env['omniauth.error'].respond_to?(:response)

    logger.info "env['SCRIPT_NAME']: #{env['SCRIPT_NAME']}"
    logger.info "OmniAuth.config.path_prefix: #{OmniAuth.config.path_prefix}"

    message_key = env['omniauth.error.type']
    new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{message_key}"
    logger.info "new_path: #{new_path}"
    Rack::Response.new(["302 Moved"], 302, 'Location' => new_path).finish
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

  before do
    logger.info "hit: #{request.path_info}"
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

  get '/error' do
    haml :error, :locals => { :message => "Message goes here 123" } 
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


