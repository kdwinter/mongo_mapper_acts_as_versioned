require File.expand_path('../lib/acts_as_versioned', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = 'mongo_mapper_acts_as_versioned'
  gem.version     = MongoMapper::Acts::Versioned::VERSION
  gem.platform    = Gem::Platform::RUBY
  gem.authors     = ['Gigamo']
  gem.email       = ['gigamo@gmail.com']
  gem.homepage    = 'http://github.com/gigamo/mongo_mapper_acts_as_versioned'
  gem.summary     = "Basic MongoMapper port of technoweenie's acts_as_versioned"
  gem.description = gem.summary

  gem.rubyforge_project  = 'mongo_mapper_acts_as_versioned'

  gem.require_paths      = ['lib']

  gem.files =
    Dir['{lib,spec}/**/*', 'LICENSE', 'README.md'] & `git ls-files -z`.split("\0")

  gem.add_development_dependency 'rspec'
  gem.required_rubygems_version = '>= 1.3.6'
  # gem.add_dependency 'active_support'
end
