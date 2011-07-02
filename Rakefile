require 'rake/clean'

coverage_file = "aggregate.rcov"
CLEAN.include('vim-update-bundles-*.gem', 'coverage', coverage_file)

task :default => [:test]

task :test do
  ruby "test.rb"
end

task :rcov do
  system "rm -rf coverage #{coverage_file}"
  ENV['RCOV'] = coverage_file
  ruby "test.rb"
  system "rcov -x analyzer --aggregate #{coverage_file} -t"
  puts 'Open coverage/index.html to see rcov results.'
end

task :build  do
  system 'gem build vim-update-bundles.gemspec'
end

task :release do
  $load_only = true
  Kernel.load 'vim-update-bundles'
  system "gem push vim-update-bundles-#{Version}.gem"
end
