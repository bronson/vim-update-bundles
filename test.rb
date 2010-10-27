require 'minitest/unit'
require 'tempfile'
require 'tmpdir'
MiniTest::Unit.autorun


# This is actually functional testing the updater since we call
# the executable directly.  We just use minitest for the helpers
# and output.

class TestUpdater < MiniTest::Unit::TestCase
  def run_test
    Dir.mktmpdir('vimtest-') do |tmpdir|
      create_files tmpdir
      Dir.mkdir "#{tmpdir}/home"
      ENV['HOME']="#{tmpdir}/home"
      ENV['TESTING']='1'
      yield "#{tmpdir}/home"
    end
  end

  def create_files tmpdir
    # create local mocks for the files we'd download
    File.open("#{tmpdir}/pathogen", 'w') { |f|
      f.write "\" PATHOGEN SCRIPT"
    }
    File.open("#{tmpdir}/starter-vimrc", 'w') { |f|
      f.write "\" STARTER VIMRC"
    }
    @stdargs = "starter_url='#{tmpdir}/starter-vimrc' pathogen_url='#{tmpdir}/pathogen'"
  end

  def check_tree base, dotvim, vimrc
    assert test ?l, "#{base}/.vimrc"
    assert_equal File.readlink("#{base}/.vimrc"), "#{base}/#{vimrc}"
    assert test ?f, "#{base}/#{vimrc}"
    assert test ?f, "#{base}/#{dotvim}/autoload/pathogen.vim"
  end


  def test_create_environment
    run_test do |tmpdir|
      `./vim-update-bundles #{@stdargs}`
      check_tree tmpdir, ".vim", ".vim/vimrc"
    end
  end


  def test_create_dotfile_environment
    run_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.dotfiles"
      `./vim-update-bundles #{@stdargs}`
      check_tree tmpdir, '.dotfiles/vim', '.dotfiles/vimrc'
    end
  end


  def test_create_custom_vimrc_environment
    run_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/mydots"
      `./vim-update-bundles #{@stdargs} vimrc='#{tmpdir}/mydots/vim rc'`
      check_tree tmpdir, '.vim', 'mydots/vim rc'
    end
  end


  def test_create_custom_conffile_environment
    run_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/parent"
      Dir.mkdir "#{tmpdir}/parent/child"
      File.open("#{tmpdir}/.vim-update-bundles.yaml", 'w') { |f|
        f.write "vimrc : '#{tmpdir}/parent/child/vv zz'"
      }
      `./vim-update-bundles #{@stdargs}`
      check_tree tmpdir, '.vim', 'parent/child/vv zz'
    end
  end


  # def test_update_standard_environment
    # skip "needs work"
  # end
end

