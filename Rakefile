require 'rubygems'
require 'rake'
require File.expand_path('../lib/acts_as_versioned/version', __FILE__)

task :spec do
  files_to_run = Dir['spec/**/*_spec.rb'].join(' ')
  sh "rspec -cfs #{files_to_run}"
end

task :default => :spec

desc 'Builds the gem'
task :build do
  sh "gem build mongo_mapper_acts_as_versioned.gemspec"
end

desc 'Builds and installs the gem'
task :install => :build do
  sh "gem install mongo_mapper_acts_as_versioned-#{MongoMapper::ActsAsVersioned::Version}"
end

desc 'Tags version, pushes to remote, and pushes gem'
task :release => :build do
  sh "git tag v#{MongoMapper::ActsAsVersioned::Version}"
  sh "git push origin master"
  sh "git push origin v#{MongoMapper::ActsAsVersioned::Version}"
  sh "gem push mongo_mapper_acts_as_versioned-#{MongoMapper::ActsAsVersioned::Version}.gem"
end
