require "sinatra/base"
require "rack/ssl" unless ENV['RACK_ENV'] == "development"
require "oauth2"
require "omniauth"
require "omniauth-oauth2"
require "haml"

module OmniAuth
  module Strategies
    class Salesforce < OmniAuth::Strategies::OAuth2

      MOBILE_USER_AGENTS =  'webos|ipod|iphone|mobile'

      option :client_options, {
        :site          => 'https://login.salesforce.com',
        :authorize_url => '/services/oauth2/authorize',
        :token_url     => '/services/oauth2/token'
      }
      option :authorize_options, [
        :scope,
        :display,
        :immediate,
        :state
      ]

      def request_phase
        req = Rack::Request.new(@env)
        options.update(req.params)
        ua = req.user_agent.to_s
        if !options.has_key?(:display)
          mobile_request = ua.downcase =~ Regexp.new(MOBILE_USER_AGENTS)
          options[:display] = mobile_request ? 'touch' : 'page'
        end
        super
      end

      uid { raw_info['id'] }

      info do
        {
          'name'            => raw_info['display_name'],
          'email'           => raw_info['email'],
          'nickname'        => raw_info['nick_name'],
          'first_name'      => raw_info['first_name'],
          'last_name'       => raw_info['last_name'],
          'location'        => '',
          'description'     => '',
          'image'           => raw_info['photos']['thumbnail'] + "?oauth_token=#{access_token.token}",
          'phone'           => '',
          'urls'            => raw_info['urls']
        }
      end

      def raw_info
        access_token.options[:mode] = :query
        access_token.options[:param_name] = :oauth_token
        @raw_info ||= access_token.post(access_token['id']).parsed
      end

      extra do
        raw_info.merge({
          'instance_url' => access_token.params['instance_url'],
          'pod' => access_token.params['instance_url']
        })
      end
      
    end

    class SalesforceSandbox < OmniAuth::Strategies::Salesforce
      default_options[:client_options][:site] = 'https://test.salesforce.com'
    end
    class DatabaseDotCom < OmniAuth::Strategies::Salesforce
      default_options[:client_options][:site] = 'https://login.database.com'
    end

  end
end

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
    provider OmniAuth::Strategies::Salesforce, 
             ENV['SALESFORCE_KEY'], 
             ENV['SALESFORCE_SECRET']
    provider OmniAuth::Strategies::SalesforceSandbox, 
             ENV['SALESFORCE_SANDBOX_KEY'], 
             ENV['SALESFORCE_SANDBOX_SECRET']
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

  # environment should be www or test
  # this method ensures that
  def sanitize_provider(provider = nil)
    provider.strip!    unless provider == nil
    provider.downcase! unless provider == nil
    provider = "salesforce" if provider != "salesforcesandbox" and provider != "databasedotcom"
    provider
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
  
  run! if app_file == $0

end


