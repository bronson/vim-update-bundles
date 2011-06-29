require 'rake/clean'

CLEAN.include('vim-update-bundles-*.gem')

task :default => [:test]

task :test do
  ruby "test.rb"
end

task :build  do
  system 'gem build vim-update-bundles.gemspec'
end

task :release do
  $load_only = true
  Kernel.load 'vim-update-bundles'
  system "gem push vim-update-bundles-#{Version}.gem"
end
