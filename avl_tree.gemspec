require 'rubygems'
Gem::Specification.new { |s|
  s.name = 'avl_tree'
  s.version = '1.1.3'
  s.date = '2012-05-09'
  s.author = 'Hiroshi Nakamura'
  s.email = 'nahi@ruby-lang.org'
  s.homepage = 'http://github.com/nahi/avl_tree'
  s.platform = Gem::Platform::RUBY
  s.summary = 'AVL tree and Red black tree (rbtree) in Ruby'
  s.files = Dir.glob('{lib,bench,test}/**/*') + ['README']
  s.require_path = 'lib'
}
