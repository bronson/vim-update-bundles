require 'guard/guard'

# It's a shame we can't use guard-test to run these tests but it can only run
# files like: Dir.glob('test/**/test_*.rb') + Dir.glob('test/**/*_test.rb')

module ::Guard
  class Test < Guard
    def run_all
      run_on_change []
    end

    def run_on_change paths
      system "ruby test.rb"
    end
  end
end

guard 'test' do
  watch 'vim-update-bundles'
  watch 'test.rb'
end
