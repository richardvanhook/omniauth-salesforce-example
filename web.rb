require "sinatra/base"
require "oauth2"
require "omniauth"
require "omniauth-oauth2"
require "haml"

module OmniAuth
  module Strategies
    class Salesforce < OmniAuth::Strategies::OAuth2
      option :client_options, {
        :site          => 'https://login.salesforce.com',
        :authorize_url => '/services/oauth2/authorize',
        :token_url     => '/services/oauth2/token'
      }
      def request_phase
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
          'urls'            => raw_info['urls'],
          'organizationid'  => raw_info['organization_id'],
          'userid'          => raw_info['user_id'],
          'username'        => raw_info['username'],
          'organization_id' => raw_info['organization_id'],
          'user_id'         => raw_info['user_id'],
          'user_name'       => raw_info['username']
        }
      end

      def raw_info
        access_token.options[:mode] = :query
        access_token.options[:param_name] = :oauth_token
        @raw_info ||= access_token.post(access_token['id']).parsed
      end
    end

  end
end

module OmniAuth
  module Strategies
    class SalesforceTest < OmniAuth::Strategies::Salesforce
      default_options[:client_options][:site] = 'https://test.salesforce.com'
    end
    class SalesforcePreRelease < OmniAuth::Strategies::Salesforce
      default_options[:client_options][:site] = 'https://prerellogin.pre.salesforce.com'
    end
  end
end


class OmniAuthSalesforceExample < Sinatra::Base

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
    provider OmniAuth::Strategies::SalesforceTest, 
             ENV['SALESFORCE_TEST_KEY'], 
             ENV['SALESFORCE_TEST_SECRET']
    #provider OmniAuth::Strategies::SalesforceTest, 
    #         ENV['SALESFORCE_PRERELEASE_KEY'], 
    #         ENV['SALESFORCE_PRERELEASE_SECRET']
  end

  post '/authenticate' do
    environment = sanitize_environment(params[:options]['environment'])
    redirect "/auth/salesforce#{environment}"
  end

  get '/unauthenticate' do
    request.env['rack.session'] = {}
    redirect '/'  
  end
  
  get '/auth/:provider/callback' do
    session[:auth_hash] = env['omniauth.auth']
    p session[:auth_hash]
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
  def sanitize_environment(environment = nil)
    environment.strip!    unless environment == nil
    environment.downcase! unless environment == nil
    environment = "" if environment != "test"
    environment
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


