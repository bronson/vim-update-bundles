# -*- encoding: utf-8 -*-

$load_only = true
Kernel.load 'vim-update-bundles'

Gem::Specification.new do |s|
  s.name = 'vim-update-bundles'
  s.version = Version
  s.authors = ['Scott Bronson', 'Sorin Ionescu', 'Steeef']
  s.email = ['brons_vim-update-bundles@rinspin.com']
  s.homepage = 'https://github.com/bronson/vim-update-bundles/'

  s.summary = 'Manages your Vim plugins'
  s.description = 'A utility that uses Git to install and remove your Vim plugins.'

  s.files = %w(vim-update-bundles CHANGES README.md Rakefile test.rb)
  s.test_files = %w(test.rb)
  s.executables = %w(vim-update-bundles)
  s.bindir = '.'
end
