require 'minitest/unit'
require 'tmpdir'
MiniTest::Unit.autorun


# This is actually functional testing the updater since we call
# the executable directly.  We just use minitest for the helpers
# and output.

class TestUpdater < MiniTest::Unit::TestCase
  def test_create_environment
    Dir.mktmpdir('vimtest-') do |tmpdir|
      ENV['HOME']=tmpdir
      ENV['TESTING']='1'

      `./vim-update-bundles`

      assert test ?l, "#{tmpdir}/.vimrc"
      assert_equal File.readlink("#{tmpdir}/.vimrc"), "#{tmpdir}/.vim/vimrc"
      assert test ?f, "#{tmpdir}/.vim/vimrc"
      assert test ?f, "#{tmpdir}/.vim/autoload/pathogen.vim"
    end
  end

  def test_create_dotfile_environment
    Dir.mktmpdir('vimtest-') do |tmpdir|
      ENV['HOME']=tmpdir
      ENV['TESTING']='1'

      Dir.mkdir "#{tmpdir}/.dotfiles"
      `./vim-update-bundles`

      assert test ?l, "#{tmpdir}/.vimrc"
      assert_equal File.readlink("#{tmpdir}/.vimrc"), "#{tmpdir}/.dotfiles/vimrc"
      assert test ?f, "#{tmpdir}/.dotfiles/vimrc"
      assert test ?f, "#{tmpdir}/.dotfiles/vim/autoload/pathogen.vim"
    end
  end

  def test_create_custom_vimrc_environment
    Dir.mktmpdir('vimtest-') do |tmpdir|
      ENV['HOME']=tmpdir
      ENV['TESTING']='1'

      Dir.mkdir "#{tmpdir}/mydots"
      `./vim-update-bundles vimrc="#{tmpdir}/mydots/vim rc"`

      assert test ?l, "#{tmpdir}/.vimrc"
      assert_equal File.readlink("#{tmpdir}/.vimrc"), "#{tmpdir}/mydots/vim rc"
      assert test ?f, "#{tmpdir}/mydots/vim rc"
      assert test ?f, "#{tmpdir}/.vim/autoload/pathogen.vim"
    end
  end

  def test_create_custom_conffile_environment
    Dir.mktmpdir('vimtest-') do |tmpdir|
      ENV['HOME']=tmpdir
      ENV['TESTING']='1'

      Dir.mkdir "#{tmpdir}/parent"
      Dir.mkdir "#{tmpdir}/parent/child"
      File.open("#{tmpdir}/.vim-update-bundles.yaml", 'w') { |f|
        f.write "vimrc : '#{tmpdir}/parent/child/vv zz'"
      }

      `./vim-update-bundles`

      assert test ?l, "#{tmpdir}/.vimrc"
      assert_equal File.readlink("#{tmpdir}/.vimrc"), "#{tmpdir}/parent/child/vv zz"
      assert test ?f, "#{tmpdir}/parent/child/vv zz"
      assert test ?f, "#{tmpdir}/.vim/autoload/pathogen.vim"
    end
  end

  # def test_update_standard_environment
    # skip "needs work"
  # end
end

