Gem::Specification.new do |gem|
  gem.name        = 'mongo_mapper_acts_as_versioned'
  gem.version     = '0.3.4'
  gem.platform    = Gem::Platform::RUBY
  gem.authors     = ['Kenneth De Winter']
  gem.email       = ['kdwinter@protonmail.com']
  gem.homepage    = 'http://github.com/gigamo/mongo_mapper_acts_as_versioned'
  gem.summary     = "Basic MongoMapper port of technoweenie's acts_as_versioned"
  gem.description = gem.summary
  gem.licenses    = ["MIT"]

  gem.rubyforge_project  = 'mongo_mapper_acts_as_versioned'

  gem.require_paths      = ['lib']

  gem.files =
    Dir['{lib,spec}/**/*', 'LICENSE', 'README.md'] & `git ls-files -z`.split("\0")

  gem.add_runtime_dependency 'activesupport'
  gem.add_runtime_dependency 'mongo_mapper'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.required_rubygems_version = '>= 1.3.6'
end
