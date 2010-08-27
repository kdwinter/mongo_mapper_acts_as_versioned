# MongoMapper::ActsAsVersioned

Basic MongoMapper port of technoweenie's [acts_as_versioned](http://github.com/technoweenie/acts_as_versioned).

# Basic Usage

    class Page
      include MongoMapper::Document

      plugin ActsAsVersioned

      key :title,   String
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

## Tested with

* MongoMapper 0.8.3
* Ruby 1.9.2

## TODO

* Add loads more options
* Properly document those options

## Copyright

Copyright (c) 2010 Gigamo &lt;gigamo@gmail.com&gt;. See LICENSE for details.
