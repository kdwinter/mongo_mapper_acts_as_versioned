require 'rubygems'
require 'rake'
require File.expand_path('../lib/acts_as_versioned', __FILE__)

task :spec do
  files_to_run = Dir['spec/**/*_spec.rb'].join(' ')
  sh "rspec #{files_to_run}"
end

task :default => :spec

desc 'Builds the gem'
task :build do
  sh 'gem build mongo_mapper_acts_as_versioned.gemspec'
end

desc 'Builds and installs the gem'
task :install => :build do
  sh "gem install mongo_mapper_acts_as_versioned-#{MongoMapper::Acts::Versioned::VERSION}"
end

desc 'Tags version, pushes to remote, and pushes gem'
task :release => :build do
  sh "git tag v#{MongoMapper::Acts::Versioned::VERSION}"
  sh 'git push origin master'
  sh "git push origin v#{MongoMapper::Acts::Versioned::VERSION}"
  sh "gem push mongo_mapper_acts_as_versioned-#{MongoMapper::Acts::Versioned::VERSION}.gem"
end
