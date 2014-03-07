# config.ru
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'rack/ssl'
require 'securerandom'
require 'csv'

require File.expand_path '../main.rb', __FILE__

use Rack::SSL

use Rack::Auth::Basic, 'Restricted Area' do |username, password|
  [username, password] == %w(admin password)
end

UPLOADS_PATH = File.join(settings.root, '/uploads')
BIN_PATH = File.join(settings.root, '/bin')

set :run, false
set :raise_errors, true

run Sinatra::Application
