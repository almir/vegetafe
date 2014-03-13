require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'rack/ssl'
require 'securerandom'
require 'csv'

require File.expand_path '../env.rb', __FILE__
require File.expand_path '../main.rb', __FILE__

UPLOADS_PATH = File.join(settings.root, '/uploads')
BIN_PATH = File.join(settings.root, '/bin')

set :run, false
set :raise_errors, true

run Sinatra::Application
