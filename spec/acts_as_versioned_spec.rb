require 'spec_helper'

describe MongoMapper::Acts::Versioned do
  before :all do
    class Landmark
      include MongoMapper::Document

      plugin MongoMapper::Acts::Versioned

      self.non_versioned_keys << 'depth'

      key :title, String
      key :depth, Integer
      timestamps!
    end

    class Sublandmark < Landmark
      key :location, String
    end
  end

  it 'should set the correct properties on the version class' do
    Landmark::Version.original_class.should == Landmark
    Landmark::Version.collection_name.should == 'landmark_versions'
    Landmark.versioned_class.should == Landmark::Version
    Sublandmark::Version.original_class.should == Landmark
    Sublandmark::Version.collection_name.should == 'landmark_versions'
    Sublandmark.versioned_class.should == Landmark::Version
  end

  it 'should save a versioned copy' do
    l = Landmark.create(:title => 'title')
    l.new_record?.should be_false
    l.versions.size.should == 1
    l.version.should == 1
    l.versions.first.should be_a(Landmark.versioned_class)
  end

  it 'should save without revision' do
    l = Landmark.create(:title => 'title')
    l.version.should == 1

    l.update_attributes(:title => 'changed')
    l = l.reload
    l.version.should == 2

    old_versions = l.versions.size

    l.save_without_revision

    l.without_revision do
      l.update_attributes :title => 'changed again'
    end

    l.reload.versions.size.should == old_versions
  end

  it 'should rollback with version number' do
    l = Landmark.create(:title => 'title')
    (2..10).each do |i|
      l = Landmark.first
      l.update_attributes(:title => "title#{i}")
    end

    l = l.reload
    l.version.should == 10
    l.versions.size.should == 10
    l.title.should == 'title10'

    l.revert_to!(7).should be_true
    l = l.reload
    l.version.should == 7
    l.versions.size.should == 10
    l.title.should == 'title7'
  end

  it 'should rollback with version class' do
    l = Landmark.create(:title => 'title')
    (2..10).each do |i|
      l = Landmark.first
      l.update_attributes(:title => "title#{i}")
    end

    l = l.reload
    l.version.should == 10
    l.versions.size.should == 10
    l.title.should == 'title10'

    l.revert_to!(l.versions.find_by_version(7)).should be_true
    l = l.reload
    l.version.should == 7
    l.versions.size.should == 10
    l.title.should == 'title7'
  end

  it 'should have versioned records belong to its parent' do
    l = Landmark.create(:title => 'title')
    (2..10).each do |i|
      l = Landmark.first
      l.update_attributes(:title => "title#{i}")
    end

    l_version = l.reload.versions.last
    l_version.landmark.should == l.reload
  end

  it 'should not create new versions for skipped keys' do
    l = Landmark.create(:title => 'title')
    l.update_attributes(:depth => 1)
    l = l.reload
    l.version.should == 1
    l.versions.size.should == 1
  end

  it 'should create a new version even if a skipped key is added' do
    l = Landmark.create(:title => 'title')
    l.update_attributes(:title => 'new title', :depth => 1)
    l = l.reload
    l.version.should == 2
    l.versions.size.should == 2
  end

  it 'should remember skipped keys through versions' do
    l = Landmark.create(:title => 'title')
    l.update_attributes(:title => 'new title')
    l = l.reload
    l.version.should == 2
    l.versions.size.should == 2

    l.update_attributes(:depth => 1)
    l = l.reload
    l.version.should == 2
    l.versions.size.should == 2
    l.depth.should == 1
    l.title.should == 'new title'

    l.revert_to!(1)
    l = l.reload
    l.version.should == 1
    l.versions.size.should == 2
    l.depth.should == 1
    l.title.should == 'title'
  end

  it 'should store changes in a hash' do
    l = Landmark.create(:title => 'title')
    l.versions[0].changed_attributes.should == {'title' => 'title'}

    l.update_attributes(:title => 'changed title', :depth => 1)
    l.reload.versions[1].changed_attributes.should == {'title' => 'changed title'}
  end

  context 'finders' do
    before :each do
      @l = Landmark.create(:title => 'title')
      (2..5).each do |i|
        Landmark.first.update_attributes(:title => "title#{i}")
      end
      @l = @l.reload
    end

    it 'should find the earliest version' do
      @l.versions.earliest.should == @l.versions.find_by_version(1)
    end

    it 'should find the latest version' do
      @l.versions.latest.should == @l.versions.find_by_version(5)
    end

    it 'should find the previous version' do
      @l.versions[1].previous.should == @l.versions[0]
    end

    it 'should find the next version' do
      @l.versions[0].next.should == @l.versions[1]
    end
  end

  it 'should save a versioned class with sci' do
    s = Sublandmark.create!(:title => 'first title')
    s.new_record?.should be_false
    s.version.should == 1

    s.versions.size.should == 1
    s.versions.first.should be_a(Landmark.versioned_class)
    s.versions.first.attributes.keys.should include('_version_type')
    s.versions.first._version_type.should == 'Sublandmark'
    s.versions.first.landmark.should == s
  end

  it 'should rollback with sti' do
    s = Sublandmark.create(:title => 'title')
    (2..5).each do |i|
      s = Sublandmark.first
      s.update_attributes(:title => "title#{i}")
    end

    s = s.reload
    s.version.should == 5
    s.versions.size.should == 5
    s.title.should == 'title5'
    s.revert_to!(3).should be_true
    s = s.reload
    s.version.should == 3
    s.versions.size.should == 5
    s.title.should == 'title3'

    s.versions.each do |version|
      version._version_type.should == 'Sublandmark'
    end

    l = Landmark.create(:title => 'other title')
    (2..5).each do |i|
      l = Landmark.first
      l.update_attributes(:title => "other title#{i}")
    end

    l = l.reload
    l.versions.should_not == s.versions
    l.version.should == 5
    l.versions.size.should == 5
    l.title.should == 'other title5'
    l.revert_to!(3).should be_true
    l = l.reload
    l.version.should == 3
    l.versions.size.should == 5
    l.title.should == 'other title3'

    Landmark::Version.count.should == 10
  end
end
