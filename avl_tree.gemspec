require 'rubygems'
Gem::Specification.new { |s|
  s.name = 'avl_tree'
  s.version = '1.2.1'
  s.date = '2014-09-28'
  s.author = 'Hiroshi Nakamura'
  s.email = 'nahi@ruby-lang.org'
  s.homepage = 'http://github.com/nahi/avl_tree'
  s.platform = Gem::Platform::RUBY
  s.summary = 'AVL tree, Red black tree and Lock-free Red black tree in Ruby'
  s.files = Dir.glob('{lib,bench,test}/**/*') + ['README.md']
  s.require_path = 'lib'
  s.add_runtime_dependency "atomic", "~> 1.1"
}
