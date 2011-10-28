require 'mongo_mapper'
require 'mongo_mapper/version'
puts MongoMapper::Version
require 'rspec'
require File.expand_path('../../lib/acts_as_versioned', __FILE__)

MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017)
MongoMapper.database = 'test'
MongoMapper.database.collections.each {|c| c.drop_indexes }

Rspec.configure do |config|
  config.after :each do
    MongoMapper.database.collections.each do |collection|
      collection.remove unless collection.name =~ /(.*\.)?system\..*/
      collection.drop_indexes
    end
  end
end
