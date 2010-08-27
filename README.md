# ActsAsVersioned for [MongoMapper](http://github.com/jnunemaker/mongomapper)

Basic MongoMapper port of technoweenie's [acts_as_versioned](http://github.com/technoweenie/acts_as_versioned). Stores changed attributes in a Hash key instead of copying all keys from the original model.

## Usage

### Basic Example

    class Page
      include MongoMapper::Document

      plugin ActsAsVersioned

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

* "\_id'
* "created\_at"
* "updated\_at"
* "creator\_id"
* "updater\_id"
* "version"
* the versioned class' foreign key

### Ignoring additional keys

Simply add `self.skipped_keys << 'new_skipped_key'` somewhere in your model.

## Tested with

* MongoMapper 0.8.3
* Ruby 1.9.2

## TODO

* Add loads more options
* Properly document those options
* Support SCI

## Copyright

Copyright (c) 2010 Gigamo &lt;gigamo@gmail.com&gt;. See LICENSE for details.
