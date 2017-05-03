# ActsAsVersioned for [MongoMapper](http://github.com/mongomapper/mongomapper)

Basic MongoMapper port of technoweenie's [acts_as_versioned](http://github.com/technoweenie/acts_as_versioned).
Stores changed attributes in a single collection using a general Hash key.


## Usage

### Basic Example

    class Page
      include MongoMapper::Document

      plugin MongoMapper::Acts::Versioned

      key :title, String
    end

    page = Page.create(:title => 'title')
    page.version              # => 1
    page.versions.size        # => 1

    page.title = 'new title'
    page.save

    page = page.reload
    page.version              # => 2
    page.versions.size        # => 2
    page.title                # => 'new title'

    page.revert_to!(1)

    page = page.reload
    page.version              # => 1
    page.versions.size        # => 2
    page.title                # => 'title'

### Keys that do not trigger new versions

Default ignored keys are:

* "\_id"
* "created\_at"
* "updated\_at"
* "creator\_id"
* "updater\_id"
* "version"
* "\_type"
* "\_versioned\_type"
* versioned\_foreign\_key

### Ignoring additional keys

Simply add `do_not_version 'new_skipped_key', 'another_skipped_key'` somewhere in your model.

## Tested with

* MongoMapper 0.11.1, 0.13.1, 0.14.0
* Ruby 1.9.2 up to 2.4.0

## Older MongoMapper versions

* For MongoMapper <= 0.8.6, see the master branch of this repository.

## Older embedded document versions

* See the next branch of this repository.

## Bundler note

Make sure to specify `:require => 'acts_as_versioned'` in your Gemfile.

## Copyright

See LICENSE.
