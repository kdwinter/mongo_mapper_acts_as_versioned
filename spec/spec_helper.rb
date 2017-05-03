require 'mongo_mapper'
require 'rspec'
require File.expand_path('../../lib/acts_as_versioned', __FILE__)

MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017)
MongoMapper.database = 'test'
MongoMapper.database.collections.each(&:drop_indexes)

def remove_collections
  MongoMapper.database.collections.each do |collection|
    collection.remove unless collection.name =~ /(.*\.)?system\..*/
    collection.drop_indexes
  end
end
remove_collections

RSpec.configure do |config|
  config.after(:each) { remove_collections }
end
