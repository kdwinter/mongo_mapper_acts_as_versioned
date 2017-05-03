require 'spec_helper'

describe MongoMapper::Acts::Versioned do
  context 'landmarks and generally' do
    before :all do
      class Landmark
        include MongoMapper::Document

        plugin MongoMapper::Acts::Versioned
        do_not_version :depth

        key :title, String
        key :depth, Integer
        timestamps!
      end

      class Sublandmark < Landmark
        key :location, String
      end
    end

    it 'should save a versioned copy' do
      l = Landmark.create(:title => 'title')
      expect(l.new_record?).to be_falsy
      expect(l.versions.size).to eq 1
      expect(l.version).to eq 1
      expect(l.versions.first).to be_a(MongoMapper::Acts::Versioned::DocumentVersion)
    end

    it 'should clear old versions when a limit is set' do
      Landmark.max_version_limit = 3

      l = Landmark.create(:title => 'title')
      (2..10).each do |i|
        l = Landmark.first
        l.update_attributes(:title => "title#{i}")
      end

      l = l.reload
      expect(l.versions.size).to eq 3
      expect(l.versions.first.version).to eq 8
      expect(l.versions.last.version).to eq 10

      Landmark.max_version_limit = 0
    end

    it 'should save without revision' do
      l = Landmark.create(:title => 'title')
      expect(l.version).to eq 1

      l.update_attributes(:title => 'changed')
      l = l.reload
      expect(l.version).to eq 2

      old_versions = l.versions.size

      l.save_without_revision

      l.without_revision do
        l.update_attributes :title => 'changed again'
      end

      expect(l.reload.versions.size).to eq old_versions
    end

    it 'should rollback with version number' do
      l = Landmark.create(:title => 'title')
      (2..10).each do |i|
        l = Landmark.first
        l.update_attributes(:title => "title#{i}")
      end

      l = l.reload
      expect(l.version).to eq 10
      expect(l.versions.size).to eq 10
      expect(l.title).to eq 'title10'

      expect(l.revert_to!(7)).to be_truthy
      l = l.reload
      expect(l.version).to eq 7
      expect(l.versions.size).to eq 10
      expect(l.title).to eq 'title7'
    end

    it 'should rollback with version class' do
      l = Landmark.create(:title => 'title')
      (2..10).each do |i|
        l = Landmark.first
        l.update_attributes(:title => "title#{i}")
      end

      l = l.reload
      expect(l.version).to eq 10
      expect(l.versions.size).to eq 10
      expect(l.title).to eq 'title10'

      expect(l.revert_to!(l.document_version(7))).to be_truthy
      l = l.reload
      expect(l.version).to eq 7
      expect(l.versions.size).to eq 10
      expect(l.title).to eq 'title7'
    end

    it 'should have versioned records belong to its parent' do
      l = Landmark.create(:title => 'title')
      (2..10).each do |i|
        l = Landmark.first
        l.update_attributes(:title => "title#{i}")
      end

      l_version = l.reload.versions.last
      expect(l_version.entity).to eq l.reload
    end

    it 'should not create new versions for skipped keys' do
      l = Landmark.create(:title => 'title')
      l.update_attributes(:depth => 1)
      l = l.reload
      expect(l.version).to eq 1
      expect(l.versions.size).to eq 1
    end

    it 'should create a new version even if a skipped key is added' do
      l = Landmark.create(:title => 'title')
      l.update_attributes(:title => 'new title', :depth => 1)
      l = l.reload
      expect(l.version).to eq 2
      expect(l.versions.size).to eq 2
    end

    it 'should remember skipped keys through versions' do
      l = Landmark.create(:title => 'title')
      l.update_attributes(:title => 'new title')
      l = l.reload
      expect(l.version).to eq 2
      expect(l.versions.size).to eq 2

      l.update_attributes(:depth => 1)
      l = l.reload
      expect(l.version).to eq 2
      expect(l.versions.size).to eq 2
      expect(l.depth).to eq 1
      expect(l.title).to eq 'new title'

      l.revert_to!(1)
      l = l.reload
      expect(l.version).to eq 1
      expect(l.versions.size).to eq 2
      expect(l.depth).to eq 1
      expect(l.title).to eq 'title'
    end

    it 'should store changes in a hash' do
      l = Landmark.create(:title => 'title')
      expect(l.document_version(1).modified).to eq({'title' => 'title'})

      l.update_attributes(:title => 'changed title', :depth => 1)
      expect(l.reload.document_version(2).modified).to eq({'title' => 'changed title'})
    end

    it 'should save when a version was created' do
      l = Landmark.create(:title => 'title')
      expect(l.document_version(1).created_at).to be_instance_of(Time)
    end

    it 'should save a versioned class with sci' do
      s = Sublandmark.create!(:title => 'first title')
      expect(s.new_record?).to be_falsy
      expect(s.version).to eq 1

      expect(s.versions.size).to eq 1
      expect(s.versions.first).to be_a(MongoMapper::Acts::Versioned::DocumentVersion)
      expect(s.versions.first.entity_type).to eq "Sublandmark"
    end

    it 'should rollback with sci' do
      l = Landmark.create(:title => 'other title')
      (2..5).each do |i|
        l = Landmark.first
        l.update_attributes(:title => "other title#{i}")
      end

      l = l.reload
      expect(l.version).to eq 5
      expect(l.versions.size).to eq 5
      expect(l.title).to eq 'other title5'
      expect(l.revert_to!(3)).to be_truthy
      l = l.reload
      expect(l.version).to eq 3
      expect(l.versions.size).to eq 5
      expect(l.title).to eq 'other title3'

      s = Sublandmark.create(:title => 'title')
      (2..5).each do |i|
        s = Sublandmark.first
        s.update_attributes(:title => "title#{i}")
      end

      s = s.reload
      expect(s.versions).not_to eq l.versions
      expect(s.version).to eq 5
      expect(s.versions.size).to eq 5
      expect(s.title).to eq 'title5'
      expect(s.revert_to!(3)).to be_truthy
      s = s.reload
      expect(s.version).to eq 3
      expect(s.versions.size).to eq 5
      expect(s.title).to eq 'title3'
    end
  end

  context 'nodes' do
    before :all do
      class Node
        include MongoMapper::Document

        key :title, String
      end

      class Page < Node
        plugin MongoMapper::Acts::Versioned
      end

      class Post < Node
        plugin MongoMapper::Acts::Versioned
      end
    end

    it 'should version only the subclass' do
      page = Page.create(:title => 'page title')
      post = Post.create(:title => 'post title')
      expect(page.version).to eq 1
      expect(page.versions.size).to eq 1
      expect(post.version).to eq 1
      expect(post.versions.size).to eq 1
    end
  end
end
