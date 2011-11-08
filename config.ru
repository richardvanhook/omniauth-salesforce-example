$:.push File.dirname(__FILE__) + '/lib'

require 'rubygems'
require 'bundler'

Bundler.setup :default, ENV['RACK_ENV']

require 'app'

run Sinatra::Application
