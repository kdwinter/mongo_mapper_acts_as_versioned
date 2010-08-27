module MongoMapper
  module Acts
    module Versioned
      VERSION   = '0.0.4'
      CALLBACKS = [:set_new_version, :save_version, :save_version?]

      def self.configure(model)
        model.class_eval do
          cattr_accessor :versioned_class_name, :versioned_foreign_key,
                         :versioned_collection_name, :non_versioned_keys

          self.versioned_class_name      = :Version
          self.versioned_foreign_key     = self.to_s.foreign_key
          self.versioned_collection_name = "#{collection_name.singularize}_versions"
          self.non_versioned_keys        = [
            '_id', 'created_at', 'updated_at', 'creator_id',
            'updater_id', 'version', versioned_foreign_key,
            '_type', '_version_type'
          ]

          const_set(versioned_class_name, Class.new).class_eval do
            include MongoMapper::Document

            class << self
              delegate :versioned_foreign_key, :to => :original_class
            end

            key :version,            Integer
            key :changed_attributes, Hash

            if type_key = keys['_type']
              key :_version_type, type_key.type, type_key.options
            end

            def self.before(version)
              where(
                versioned_foreign_key => version[versioned_foreign_key],
                :version.lt           => version.version
              ).sort(:version.desc).first
            end

            def self.after(version)
              where(
                versioned_foreign_key => version[versioned_foreign_key],
                :version.gt           => version.version
              ).sort(:version.asc).first
            end

            def previous
              self.class.before(self)
            end

            def next
              self.class.after(self)
            end
          end

          versioned_class.cattr_accessor :original_class
          versioned_class.original_class = self
          versioned_class.set_collection_name versioned_collection_name
          versioned_class.belongs_to self.to_s.demodulize.underscore.to_sym,
            :class_name  => self.to_s,
            :foreign_key => versioned_foreign_key

          key :version, Integer

          many :versions,
            :class_name => "#{self}::#{versioned_class_name}",
            :foreign_key => versioned_foreign_key,
            :dependent => :destroy do
            def earliest
              query.sort(:version).first
            end

            def latest
              query.sort(:version.desc).first
            end
          end

          before_save :set_new_version
          after_save  :save_version
        end
      end

      module InstanceMethods
        def save_version
          if @saving_version
            @saving_version = nil

            rev = self.class.versioned_class.new
            clone_versioned_model(self, rev)
            rev.version = version
            rev[self.class.versioned_foreign_key] = id
            rev.save!
          end
        end

        def revert_to(version)
          if version.is_a?(self.class.versioned_class)
            return false unless version[self.class.versioned_foreign_key] == id and !version.new_record?
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
            new_model['_type'] = orig_model['_version_type']
            orig_model = orig_model.changed_attributes
          elsif new_model.is_a?(self.class.versioned_class)
            new_model['_version_type'] = orig_model['_type']
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
          new_record? || versions.empty? ? 1 : versions.map(&:version).max.next
        end
      end

      module ClassMethods
        def versioned_class
          const_get versioned_class_name
        end

        def versioned_keys
          keys.keys - non_versioned_keys
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
      end
    end
  end
end
