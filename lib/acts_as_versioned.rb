require 'mongo_mapper' unless Object.const_defined?(:MongoMapper)

module ActsAsVersioned
  CALLBACKS = [:set_new_version, :save_version, :save_version?]

  def self.configure(model)
    model.class_eval do
      const_set(:Version, Class.new).class_eval do
        include MongoMapper::Document

        key :version,            Integer
        key :changed_attributes, Hash

        def self.before(version)
          where(
            super_foreign_key => version[super_foreign_key],
            :version.lt       => version.version
          ).sort(:version.desc).first
        end

        def self.after(version)
          where(
            super_foreign_key => version[super_foreign_key],
            :version.gt       => version.version
          ).sort(:version.asc).first
        end

        def previous
          self.class.before(self)
        end

        def next
          self.class.after(self)
        end

        def self.super_foreign_key
          original_class.to_s.foreign_key
        end

        class << self
          protected :super_foreign_key
        end
      end

      versioned_class.cattr_accessor :original_class
      versioned_class.original_class = self
      versioned_class.set_collection_name "#{self.collection_name.singularize}_versions"
      versioned_class.belongs_to self.to_s.demodulize.underscore.to_sym,
                                 :class_name  => "::#{self}",
                                 :foreign_key => self.to_s.foreign_key
    end

    model.key :version, Integer
    model.many :versions, :class_name => "#{model}::Version",
               :foreign_key => model.to_s.foreign_key, :dependent => :destroy do
      def earliest
        query.sort(:version).first
      end

      def latest
        query.sort(:version.desc).first
      end
    end
    model.before_save :set_new_version
    model.after_save  :save_version
  end

  module InstanceMethods
    def save_version
      if @saving_version
        @saving_version = nil

        rev = self.class.versioned_class.new
        clone_versioned_model(self, rev)
        rev.version = version
        rev[self.class.to_s.foreign_key] = id
        rev.save!
      end
    end

    def revert_to(version)
      if version.is_a?(self.class.versioned_class)
        return false unless version[self.class.to_s.foreign_key] == id and !version.new_record?
      else
        return false unless version = versions.where(:version => version).first
      end

      clone_versioned_model(version, self)
      self.version = version.version

      true
    end

    def revert_to!(version)
      revert_to(version) ? save_without_revision : false
    end

    def save_without_revision
      save_without_revision!
      true
    rescue
      false
    end

    def save_without_revision!
      without_revision do
        save!
      end
    end

    def clone_versioned_model(orig_model, new_model)
      if orig_model.is_a?(self.class.versioned_class)
        orig_model = orig_model.changed_attributes
      end

      if new_model.is_a?(self.class.versioned_class)
        new_model = new_model.changed_attributes 
      end

      self.class.versioned_keys.each do |col|
        new_model[col] = orig_model[col]
      end
    end

    def save_version?
      (self.class.versioned_keys & changed).any?
    end

    def without_revision(&block)
      self.class.without_revision(&block)
    end

    def empty_callback
    end

  protected

    def set_new_version
      @saving_version = new_record? || save_version?
      self.version = next_version if @saving_version
    end

    def next_version
      (new_record? ? 0 : versions.map(&:version).max) + 1
    end
  end

  module ClassMethods
    def versioned_class
      const_get(:Version)
    end

    def versioned_keys
      keys.keys - skipped_keys
    end

    def without_revision
      class_eval do
        CALLBACKS.each do |attr_name|
          alias_method :"orig_#{attr_name}", attr_name
          alias_method attr_name, :empty_callback
        end
      end
      yield
    ensure
      class_eval do
        CALLBACKS.each do |attr_name|
          alias_method attr_name, :"orig_#{attr_name}"
        end
      end
    end

    def skipped_keys
      @skipped_keys ||= [
        '_id', 'created_at', 'updated_at', 'creator_id',
        'updater_id', 'version', self.class.to_s.foreign_key
      ]
    end
  end
end
