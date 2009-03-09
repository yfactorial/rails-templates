gem 'haml', :version => '2.1.0'
gem "yfactorial-utility_scopes", :lib => 'utility_scopes', 
  :source => 'http://gems.github.com/'
gem 'mislav-will_paginate', :lib => 'will_paginate', 
  :source => 'http://gems.github.com'

if yes?("Do you want to use RSpec?")
  plugin "rspec", :git => "git://github.com/dchelimsky/rspec.git"
  plugin "rspec-rails", :git => "git://github.com/dchelimsky/rspec-rails.git"
  generate :rspec
end

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

run "cp config/database.yml config/example_database.yml"
run "rm -rf test"
run "git add * .gitignore"