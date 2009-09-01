# mozomo.rb
# from Didip Kerabat and Quin Hoxie

# run 'gem install hassox-rails_warden'

gem 'rack'
gem 'haml'
gem 'less'
gem 'mocha'
gem 'json_pure', :lib => 'json'
gem 'bcrypt-ruby', :lib => 'bcrypt'
gem 'warden'
gem 'rails_warden'

# Github gems
def github_gem(lib_name)
  gem lib_name, :lib => lib_name.match(/[^-]+-(.*)/)[1], :source => 'http://gems.github.com'
end

[
  'mislav-will_paginate',
  'thoughtbot-factory_girl',
  'thoughtbot-shoulda',
  'thoughtbot-quietbacktrace'
].each do |library|
  github_gem(library)
end

# get all datamapper related gems (assume sqlite3 to be database)
gem "addressable", :lib => "addressable/uri"
gem "do_sqlite3"
gem 'dm-validations'
gem 'dm-types'
gem 'dm-timestamps'

# Rails plugins
plugin "less-for-rails", :git => "git://github.com/augustl/less-for-rails.git"
plugin "flash-message-conductor", :git => "git://github.com/planetargon/flash-message-conductor.git"

rake "gems:install"
rake "gems:unpack"
rake "gems:build"

# install datamapper rake tasks
generate("dm_install")

# fix config files to work with datamapper instead of active_record
run "sed -i config/environment.rb -e 's/#.*config.frameworks.*/config.frameworks -= [ :active_record ]/'"
run "sed -i spec/spec_helper.rb -e 's/^\\s*config[.]/#\\0/'"
run "sed -i test/test_helper.rb -e 's/^[^#]*fixtures/#\\0/'"

# fix a problem with missing class constants for models woth relations
initializer 'preload_models.rb', <<-CODE
require 'datamapper4rails/preload_models'
CODE

# basic layout
file('app/views/layouts/application.html.haml') do
  <<-EOF
!!!

%html
  %head
    %title My Mozomo App
    = stylesheet_link_tag 'screen', :media => 'screen, projection'
    = stylesheet_link_tag 'print', :media => 'print'
  %body
    #container
      = render_flash_messages
      = yield
  = javascript_include_tag 'jquery'
  EOF
end

# basic model objects
file('app/models/user.rb') do
  <<-EOF
class User
  attr_accessor :password, :password_confirmation
  include DataMapper::Resource

  property :id,         Serial
  property :email,      String
  property :encrypted_password, BCryptHash, :nullable => false
  property :created_at, DateTime

  validates_is_confirmed :password

  def password=(pass)
    @password = pass
    self.encrypted_password = pass
  end
end
  EOF
end

initializer('warden.rb') do
  <<-EOF
Rails.configuration.middleware.use RailsWarden::Manager do |manager|
  manager.default_strategies :bcrypt
  manager.failure_app = UserController
end

Warden::Manager.serialize_into_session{ |user| [user.class, user.id] }
Warden::Manager.serialize_from_session{ |klass, id| klass.get(id) }

Warden::Strategies.add(:bcrypt) do
  def valid?
    params[:email] || params[:password]
  end

  def authenticate!
    return fail! unless user = User.first(:email => params[:email])

    if user.encrypted_password == params[:password]
      success!(user)
    else
      errors.add(:login, "Email or Password incorrect")
      fail!
    end
  end
end
  EOF
end

# integrate HAML to rails
run "haml --rails ."

# Download jquery
run 'rm public/javascripts/*'
run 'curl http://jqueryjs.googlecode.com/files/jquery-1.3.2.js > public/javascripts/jquery.js'

# Delete unnecessary files
def rm_file(file)
  run "rm #{file}"
end

[
  'README',
  'doc/README_FOR_APP',
  'public/index.html',
  'public/favicon.ico',
  'public/robots.txt'
].each { |f| rm_file(f) }

