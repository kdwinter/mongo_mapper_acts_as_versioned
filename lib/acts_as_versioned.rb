require "active_support"
require "active_support/concern"
if ActiveSupport.version >= Gem::Version.new("5.0.0")
  begin
    # MongoMapper doesn't work without this since it was extracted from Rails in 5.0+
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
      VERSION = "0.3.3"

      # This model stores all version information.
      class DocumentVersion
        include MongoMapper::Document
        # Manually set the collection name to
        #   "document_versions"
        # instead of the default
        #   "mongo_mapper.acts.versioned.document_versions"
        set_collection_name "document_versions"

        key :modified,    Hash
        key :version,     Integer
        key :entity_id,   ObjectId
        key :entity_type, String
        timestamps!

        belongs_to :entity, polymorphic: true
      end

      # Required in order to act as a MM plugin.
      extend ActiveSupport::Concern

      # Callbacks that should be silenced when saving without revision.
      CALLBACKS = [:save_version, :clear_old_versions]

      # Set defaults when plugin is included into model.
      included do
        class_attribute :non_versioned_keys, :max_version_limit

        self.max_version_limit  = 0
        self.non_versioned_keys = %w(
          _id _type created_at updated_at
          creator_id updater_id version
        )

        # The document's current version.
        key :version, Integer

        before_save :save_version
        before_save :clear_old_versions
      end

      # All DocumentVersion documents belonging to this document.
      # Returns +Plucky::Query+.
      def versions
        MongoMapper::Acts::Versioned::DocumentVersion.where(
          entity_type: self.class.name, entity_id: self.id
        )
      end

      # Grab a specific DocumentVersion document by +given_version+ number.
      def document_version(given_version)
        versions.where(version: given_version).first
      end

      # Grab the DocumentVersion document corresponding with this document's
      # current +version+.
      def current_document_version
        document_version(version)
      end

      # Save a new version for this document.
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

      # Change the current document's attributes to those of a given +revision+.
      def revert_to(revision)
        if revision.is_a?(MongoMapper::Acts::Versioned::DocumentVersion)
          return false if revision.new_record?
        else
          return false unless revision = document_version(revision)
        end

        clone_attributes(revision, self)
        self.version = revision.version

        true
      end

      # Change the current document's attributes to those of a given +revision+,
      # and save the document.
      def revert_to!(revision)
        revert_to(revision) and save_without_revision or false
      end

      # Save this document without creating a new version.
      def save_without_revision
        without_revision { save }
      end

      # Save this document without creating a new version. Raises on save
      # failure.
      def save_without_revision!
        without_revision { save! }
      end

      # Forwards to +self.class.without_revision+.
      def without_revision(&block)
        self.class.without_revision(&block)
      end

    protected

      # Clear old versions based on +self.class.max_version_limit+.
      # If this limit is 0, no versions are removed.
      def clear_old_versions
        return if self.class.max_version_limit == 0
        excess_bagage = version.to_i - self.class.max_version_limit

        if excess_bagage > 0
          versions.select { |v| v.version.to_i <= excess_bagage }.map(&:delete)
        end
      end

      # Copy the attributes specified in +self.class.versioned_keys+ from either
      # a +DocumentVersion+ into this document, or from this document into a
      # +DocumentVersion+.
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

      # Should a new version be saved?
      def save_version?
        (self.class.versioned_keys & changed).any?
      end

      # Do nothing.
      def empty_callback
      end

      # Next version number, based on current version.
      def next_version
        new_record? || versions.count == 0 ?
          1 : versions.fields(:version).map(&:version).max.next
      end

      module ClassMethods
        # Keys/attributes that should be saved in versions.
        #
        # Returns all available keys minus those found in the
        # +non_versioned_keys+ list.
        def versioned_keys
          keys.keys - non_versioned_keys.map(&:to_s)
        end

        # Add given +args+ to the +non_versioned_keys+ list.
        def do_not_version(*args)
          self.non_versioned_keys |= args
        end

        # Set +max_version_limit+ as +amount+.
        def max_versions(amount)
          self.max_version_limit = amount
        end

        # Versioning-related are silenced within given +&block+.
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
