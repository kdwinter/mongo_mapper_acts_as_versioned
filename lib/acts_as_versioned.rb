require "active_support"
require "active_support/concern"
if ActiveSupport.version >= Gem::Version.new("5.0.0")
  begin
    require "activemodel-serializers-xml"
  rescue LoadError
    warn "Couldn't load AM serializers. Things might break."
  end
end
require "mongo_mapper"
require "active_model"

module MongoMapper
  module Acts
    module Versioned
      class DocumentVersion
        include MongoMapper::Document

        set_collection_name "document_versions"

        key :modified,    Hash
        key :version,     Integer
        key :entity_id,   ObjectId
        key :entity_type, String
        timestamps!

        belongs_to :entity, polymorphic: true
      end

      extend ActiveSupport::Concern

      VERSION   = "0.3.2"
      CALLBACKS = [:save_version, :clear_old_versions]

      included do
        class_attribute :non_versioned_keys, :max_version_limit

        self.max_version_limit    = 0
        self.non_versioned_keys   = %w(
          _id _type created_at updated_at
          creator_id updater_id version
        )

        key :version, Integer
        before_save :save_version
        before_save :clear_old_versions
      end

      def versions
        MongoMapper::Acts::Versioned::DocumentVersion.where(
          entity_type: self.class.name, entity_id: self.id
        )
      end

      def document_version(given_version)
        versions.where(version: given_version).first
      end

      def current_document_version
        document_version(version)
      end

      def save_version
        if new_record? || save_version?
          self.version = next_version

          rev = MongoMapper::Acts::Versioned::DocumentVersion.new
          rev.entity_type = self.class.name
          rev.entity_id = id
          rev.version = version

          clone_attributes(self, rev)

          rev.save
        end
      end

      def clear_old_versions
        return if self.class.max_version_limit == 0
        excess_bagage = version.to_i - self.class.max_version_limit

        if excess_bagage > 0
          versions.select { |v| v.version.to_i <= excess_bagage }.map(&:delete)
        end
      end

      def revert_to(rev)
        if rev.is_a?(MongoMapper::Acts::Versioned::DocumentVersion)
          return false if rev.new_record?
        else
          return false unless rev = document_version(rev)
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
        if orig_model.is_a?(MongoMapper::Acts::Versioned::DocumentVersion)
          orig_model = orig_model.modified
        elsif new_model.is_a?(MongoMapper::Acts::Versioned::DocumentVersion)
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
        new_record? || versions.count == 0 ?
          1 : versions.fields(:version).map(&:version).max.next
      end

      module ClassMethods
        def versioned_keys
          keys.keys - non_versioned_keys.map(&:to_s)
        end

        def do_not_version(*args)
          self.non_versioned_keys |= args
        end

        def max_versions(amount)
          self.max_version_limit = amount
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
      end # ClassMethods
    end # Versioned
  end # Acts
end # MongoMapper
