module MongoMapper
  module Acts
    module Versioned
      VERSION   = '0.0.10'
      CALLBACKS = [:save_version, :save_version?]

      def self.configure(model)
        model.class_eval do
          cattr_accessor :versioned_class_name, :non_versioned_keys

          self.versioned_class_name = :Version
          self.non_versioned_keys   = %w(
            _id _type created_at updated_at creator_id updater_id version
          )

          const_set(versioned_class_name, Class.new).class_eval do
            include MongoMapper::EmbeddedDocument

            key :version,  Integer
            key :modified, Hash
          end

          many :versions, :class => "#{self}::#{versioned_class_name}".constantize do
            def [](given_version)
              detect {|version| version.version.to_s == given_version.to_s }
            end
          end
        end

        model.key :version, Integer
        model.before_save :save_version
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

        def revert_to(version)
          if version.is_a?(self.class.versioned_class)
            return false if version.new_record?
          else
            return false unless version = versions[version]
          end

          clone_attributes(version, self)
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
