require 'active_support/concern' unless defined?(ActiveSupport)

module MongoMapper
  module Acts
    module Versioned
      extend ActiveSupport::Concern

      VERSION   = '0.0.11'
      CALLBACKS = [:save_version, :clear_old_versions]

      included do
        cattr_accessor :versioned_class_name, :non_versioned_keys, :max_version_limit

        self.versioned_class_name = :Version
        self.max_version_limit = 0
        self.non_versioned_keys = %w(
          _id _type created_at updated_at creator_id updater_id version
        )

        const_set(versioned_class_name, Class.new).class_eval do
          include MongoMapper::EmbeddedDocument

          key :version,  Integer
          key :modified, Hash
        end

        many :versions, :class => "#{self}::#{versioned_class_name}".constantize do
          def [](version)
            detect { |doc| doc.version.to_s == version.to_s }
          end
        end

        key :version, Integer
        before_save :save_version
        before_save :clear_old_versions
      end

      module InstanceMethods
        def save_version
          if new_record? || save_version?
            self.version = next_version

            rev = self.class.versioned_class.new
            clone_attributes(self, rev)
            rev.version = version

            self.versions << rev
          end
        end

        def clear_old_versions
          return if self.class.max_version_limit == 0
          excess_bagage = version.to_i - self.class.max_version_limit

          if excess_bagage > 0
            versions.reject! { |v| v.version.to_i <= excess_bagage }
          end
        end

        def revert_to(rev)
          if rev.is_a?(self.class.versioned_class)
            return false if rev.new_record?
          else
            return false unless rev = versions[rev]
          end

          clone_attributes(rev, self)
          self.version = rev.version

          true
        end

        def revert_to!(rev)
          revert_to(rev) and save_without_revision or false
        end

        def save_without_revision
          save_without_revision!
          true
        rescue
          false
        end

        def save_without_revision!
          without_revision { save! }
        end

        def clone_attributes(orig_model, new_model)
          if orig_model.is_a?(self.class.versioned_class)
            orig_model = orig_model.modified
          elsif new_model.is_a?(self.class.versioned_class)
            new_model = new_model.modified
          end

          self.class.versioned_keys.each do |attribute|
            new_model[attribute] = orig_model[attribute]
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
