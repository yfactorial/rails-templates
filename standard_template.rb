gem 'haml', :version => '2.1.0'
gem "yfactorial-utility_scopes", :lib => 'utility_scopes', 
  :source => 'http://gems.github.com/'
gem 'mislav-will_paginate', :lib => 'will_paginate', 
  :source => 'http://gems.github.com'
  
plugin "rspec", :git => "git://github.com/dchelimsky/rspec.git"
plugin "rspec-rails", :git => "git://github.com/dchelimsky/rspec-rails.git"
plugin "cucumber", :git => "git://github.com/aslakhellesoy/cucumber.git"
plugin "webrat", :git => "git://github.com/brynary/webrat.git"
plugin 'exception_notifier', :git => 'git://github.com/rails/exception_notification.git'
plugin "dataset", :git => "git://github.com/aiwilliams/dataset.git"
plugin "make_resourceful", :git => "git://github.com/hcatlin/make_resourceful.git"

generate :rspec
run "haml --rails ."
  
rake "gems:install"
rake "gems:unpack"
rake "rails:freeze:gems"

file ".gitignore", <<-END
.DS_Store
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
*.tmproj
END

generate :controller, "root"
route "map.root :controller => :root"

route "map.login 'login', :controller => :sessions, :action => 'new'"
route "map.logout 'logout', :controller => :sessions, :action => 'destroy', :conditions => { :method => :delete }"

generate :resource, "user", "login:string", "email:string", "salt:string", "crypted_password:string"
route "map.register 'register', :controller => :users, :action => 'new'"

route "map.resources :sessions, :only => [:new, :create, :destroy]"
route "map.resources :users, :only => [:new, :create]"

initializer 'will_paginate.rb', <<-CODE
ActiveRecord::Base.class_eval { def self.per_page; 10; end }
CODE

rakefile("db.rake") do
  <<-TASK
  namespace :db do
    desc "Drop the dbs, and does a full migrate to bring it back up"
    task :revert => ['db:drop', 'db:create', 'db:migrate']
  end
  TASK
end

# TODO: We should put this crap into a generator
file "app/models/authentication/user_auth.rb", <<-END
require 'digest/sha2'

module Authentication
  module User
    
    module ClassMethods
      
      def digest(password, salt)
        Digest::SHA512.hexdigest("\#{password}\#{salt}")
      end
      
      def authenticate(login, password)
        u = find_by_login(login)
        return (u && u.crypted_password == digest(password, u.salt)) ? u : nil      
      end
    end
    
    module InstanceMethods
      
      def hash_password
        if password_changed?
          self.salt = ActiveSupport::SecureRandom.hex(10) if !salt
          self.crypted_password = self.class.digest(password, salt)
        end
      end
      
      def password_changed?
        new_record? or !password.blank? or !password_confirmation.blank?
      end
    end
  end
end
END

file "app/models/user.rb", <<-END
require 'authentication/user_auth'

class User < ActiveRecord::Base
  
  attr_accessor :password, :password_confirmation
  
  extend Authentication::User::ClassMethods
  include Authentication::User::InstanceMethods
  
  validates_presence_of :password, :if => :password_changed?
  validates_confirmation_of :password, :if => :password_changed?
  
  before_validation :hash_password
end
END

file "app/controllers/sessions_controller.rb", <<-END
class SessionsController < ApplicationController
  
  make_resourceful do
    
    actions :new, :create, :destroy
    
    response_for :create do |wants|
      wants.html do
        flash[:notice] = "You've successfully logged in."
        redirect_back_or home_path
      end
    end
    
    response_for :create_fails do |wants|
      wants.html do
        flash[:error] = "Could not find a user with that login and password.  Please try again or register as a new user."
        render :action => 'new'
      end
    end
    
    response_for :destroy do |wants|
      wants.html do
        flash[:notice] = "You've successfully logged out."
        redirect_to root_path
      end
    end
  end
  
  def create
    u = User.authenticate(params[:email], params[:password])
    if u
      login(u)
      response_for :create
    else
      response_for :create_fails
    end
  end
  
  def destroy
    logout
    response_for :destroy
  end
end
END

file "app/controllers/application_controller.rb", <<-END
class ApplicationController < ActionController::Base
  
  include ExceptionNotifiable
  
  helper :all
  protect_from_forgery
  filter_parameter_logging :password
  
  # Let our views use these methods
  helper_method :current_user, :logged_in?
  
  # Always watch for redirect_tos
  before_filter :save_redirect_to
  
  #-- Authentication support

  def current_user
    @current_user ||= logged_in? ? User.find(session[:user_id]) : nil
  end
  
  def logged_in?
    (@logged_in ||= (!session[:user_id].blank? and User.exists?(session[:user_id])) ? 1 : 0) > 0
  end
  
  # Log this user in
  def login(user)
    session[:user_id] = user.id
    @logged_in = nil
  end
  
  def logout
    session[:user_id] = nil
    @logged_in = nil
  end
  
  #-- Session state helpers
  
  def redirect_back_or(location)
    back = session[:redirect_to]
    redirect_to(back || location)
    session[:redirect_to] = nil
  end
  
  #-- Paging
  
  def paging_params
    { :page => params[:page] || 1 }
  end
  
  #-- Common filters
  
  def save_redirect_to
    session[:redirect_to] = params[:redirect_to] if params[:redirect_to]
  end
  
  def require_logged_in
    if not logged_in?
      respond_to do |wants|
        wants.html do
          flash[:error] = "You must be logged-in to access that page."
          session[:redirect_to] = request.request_uri
          redirect_to login_path
        end
        wants.js { head :status => 401 }
      end
    end
  end

end
END

file "app/helpers/application_helper", <<-END
module ApplicationHelper

  # Print out all flash messages in a span of the same
  # class as the message type
  def flash_messages
    html = flash.collect do |type, message|
      content_tag(:div, message, :class => type)
    end
    flash.clear # Not sure why we have to manually do this sometimes
    html
  end
  
  # Are there any flash messages to display?
  def flash_messages?; flash.any?; end
  
  # Set the page title
  def page_title(title)
    content_for :page_title, title
  end
  
  # Set the html header title
  def head_title(title)
    content_for :head_title, title
  end
  
  # Get the authenticity token (useful for an ajax call)
  def auth_token
    (protect_against_forgery? ? form_authenticity_token : nil)
  end
end
END

file "app/views/layouts/application.html.haml", <<-END
!!! Strict
%html{:xmlns=>"http://www.w3.org/1999/xhtml"}
  %head
    %title= "AppName: \#{(yield :head_title) || (yield :page_title)}"
    
  %body
    #container  
      #page
        #masthead
          %h1= link_to('AppName', root_path)
          %ul#user_nav
            - if logged_in?
              %li= link_to 'Logout', logout_path, :method => :delete
              %li= "You are logged in as #{current_user}"
            - else
              %li= link_to 'Login', login_path
        #page-title
          %h3= "\#{yield :page_title}"

          - if flash_messages?
            #messages
              = flash_messages
        
        = yield
        .clear
END

file "app/views/sessions/new.html.haml", <<-END
- page_title 'Login'

- form_tag sessions_path do

  = label_tag :login
  = text_field_tag :login, params[:login]
  %br/
  
  = label_tag :password
  = password_field_tag :password, params[:password]
  %br/

  .submit
    = submit_tag "Login"
    = link_to 'Register', register_path
END

file "app/controllers/users_controller.rb", <<-END
class UsersController < ApplicationController
  
  make_resourceful do
    actions :new, :create
    
    response_for :create do |wants|
      wants.html do
        flash[:notice] = "You have been logged in."
        redirect_to root_path
      end
    end
  end
end
END

file "app/views/users/new.html.haml", <<-END
- page_title "Register"

- form_for @user do |f|

  = f.error_messages

  = f.label :login
  = f.text_field :login
  %br/
  
  = f.label :password
  = f.password_field :password
  %br/

  = f.label 'Confirm Password:'
  = f.password_field :password_confirmation
  %br/
  
  .submit
    = f.submit "Register"
    = link_to 'Cancel', root_path
END

generate :migration, "release001"

run "rm -rf test"
run "rm public/index.html"
run "cp config/database.yml config/example_database.yml"
run "git add * .gitignore"