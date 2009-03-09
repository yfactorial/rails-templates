gem 'haml', :version => '2.1.0'
gem "yfactorial-utility_scopes", :lib => 'utility_scopes', 
  :source => 'http://gems.github.com/'
gem 'mislav-will_paginate', :lib => 'will_paginate', 
  :source => 'http://gems.github.com'
  
plugin "rspec", :git => "git://github.com/dchelimsky/rspec.git"
plugin "rspec-rails", :git => "git://github.com/dchelimsky/rspec-rails.git"
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
END

generate :controller, "root"
route "map.root :controller => :root"

generate :controller, "session"
route "map.login :controller => :sessions, :action => :new"
route "map.logout :controller => :sessions, :action => :destroy, :conditions => { :method => :delete }"

generate :resource, "user", "login:string", "email:string", "salt:string", "crypted_password:string"
route "map.register :controller => :users, :action => :new"

route "map.resources :sessions, :only => [:new, :create, :destroy]"

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

run "rm -rf test"
run "rm public/index.html"
run "cp config/database.yml config/example_database.yml"
run "git add * .gitignore"