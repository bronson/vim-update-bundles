require 'rubygems'
require 'minitest/autorun'
require 'tempfile'
require 'tmpdir'

# You can specify the directory where the tests will be run:
#   TESTDIR=/ramdisk/test ruby test.rb
#
# TODO: test checking out a SHA1
# TODO: test Switching from a branch/tag/SHA1 to master and back.
# TODO: test Bundle-Command.
# TODO: test adding and removing a bundle multiple times
# TODO: what happens when checking out a branch or tag and it doesn't exist?
# TODO: test when .vimrc and .vim/vimrc both exist, the former is preferred
#
# We shell to the executable; so, this isn't actually unit testing.
# Has anyone written a functional test framework for executables?


class TestUpdater < MiniTest::Unit::TestCase
  def prepare_test
    # Creates a tmp dir to run the test in then yields to the test.
    args = ['vimtest-']
    args.push ENV['TESTDIR'] if ENV['TESTDIR']
    Dir.mktmpdir(*args) do |tmpdir|
      create_mock_files tmpdir
      Dir.mkdir "#{tmpdir}/home"
      ENV['HOME']="#{tmpdir}/home"
      ENV['TESTING']='1'
      yield "#{tmpdir}/home"
    end
  end

  def write_file base, path, contents
    File.open(File.join(base, path), 'w') { |f| f.write contents }
  end

  def create_mock_files tmpdir
    # Creates mock files to download (it saves on bandwidth and test time).
    write_file tmpdir, "pathogen",      "\" PATHOGEN SCRIPT"
    write_file tmpdir, "starter-vimrc", "\" STARTER VIMRC"
    @starter_urls = "starter_url='#{tmpdir}/starter-vimrc' pathogen_url='#{tmpdir}/pathogen'"
  end

  def create_mock_repo name
    Dir.mkdir name
    Dir.chdir name do
      `git init`
      write_file name, "first", "first"
      `git add first`
      `git commit -q -m first`
    end
  end

  def update_mock_repo dir, name
    Dir.chdir dir do
      write_file dir, name, name
      `git add '#{name}'`
      `git commit -q -m '#{name}'`
    end
  end

  def update_mock_repo_tagged dir, name, tag
    update_mock_repo dir, name
    Dir.chdir(dir) { `git tag -a #{tag} -m 'tag #{tag}'` }
  end

  def assert_test cmd, *files
    files.each do |f|
      assert test(?e, f), "#{f} does not exist!"
      assert test(cmd, f), "#{f} is not a '#{cmd}'"
    end
  end

  def refute_test cmd, *files
    files.each do |f|
      assert !test(cmd, f), "#{f} is a '#{cmd}'"
    end
  end

  def check_tree base, vimdir='.vim', vimrc='.vimrc'
    # Makes sure .vim, .vimrc, and the symlinks are set up correctly.

    if vimdir == '.vim'
      # No symlinks are needed.
      assert_test ?d, "#{base}/.vim"
    else
      assert_test ?l, "#{base}/.vim"
      assert_equal File.readlink("#{base}/.vim"), "#{base}/#{vimdir}"
    end

    if vimrc == '.vimrc'
      assert_test ?f, "#{base}/.vimrc"
    else
      assert_test ?l, "#{base}/.vimrc"
      assert_equal File.readlink("#{base}/.vimrc"), "#{base}/#{vimrc}"
    end

    assert_test ?f, "#{base}/#{vimdir}/autoload/pathogen.vim"
    assert_test ?d, "#{base}/#{vimdir}"
    assert_test ?f, "#{base}/#{vimrc}"
  end


  def test_standard_run
    # Creates a starter environment then updates a few times.
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir
      assert_test ?f, "#{tmpdir}/.vim/doc/bundles.txt"
      assert_test ?d, "#{tmpdir}/.vim/bundle"
      assert_equal ['.', '..'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }

      # Add a repository.
      create_mock_repo "#{tmpdir}/repo"
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/repo"
      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "second"
      `./vim-update-bundles`
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # Remove the repository.
      write_file tmpdir, ".vimrc", ""
      `./vim-update-bundles`
      refute_test ?d, repo
    end
  end


  def test_dont_blow_away_existing_vimrc
    # Do not destroy an existing .vimrc.
    prepare_test do |tmpdir|
      str = "don't tread on me"
      write_file tmpdir, '.vimrc', str
      `./vim-update-bundles #{@starter_urls} --vimrc_path='#{tmpdir}/.vimrc'`
      assert_equal str, File.read("#{tmpdir}/.vimrc")
    end
  end


  def test_submodule_run
    # Creates a starter environment using submodules.
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.vim"
      Dir.chdir("#{tmpdir}/.vim") { `git init` }
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vimrc"

      # Add submodule.
      create_mock_repo "#{tmpdir}/repo"
      File.open("#{tmpdir}/.vim-update-bundles.conf", 'w') { |f| f.write "submodule = true" }
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/repo"

      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{tmpdir}/.vim/.gitmodules"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "second"
      `./vim-update-bundles`
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"

      # Remove the repository.
      write_file tmpdir, ".vimrc", ""
      `./vim-update-bundles`
      refute_test ?d, repo

      ['.gitmodules', '.git/config'].each do |filename|
        text = File.read File.join(tmpdir, '.vim', filename)
        refute_match /submodule.*repo/, text
      end
    end
  end


  def test_tagstr_checkout
    # Ensures locking a checkout to a tag and that .vim/vimrc is used if it
    # already exists.
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.vim"
      write_file tmpdir, ".vim/vimrc", ''
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vim/vimrc"

      # Make a repository with a tagged commit and commits after that.
      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'

      write_file tmpdir, ".vim/vimrc", "\" Bundle: #{tmpdir}/repo 0.2"
      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "fourth"
      `./vim-update-bundles`
      assert_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"
      refute_test ?f, "#{repo}/fourth"

      # TODO: Switch to master and back and to another tag and back.
    end
  end


  def test_submodule_tagstr_checkout
    # Ensures locking a checkout to a tag.
    prepare_test do |tmpdir|
      Dir.chdir(tmpdir) { `git init` }
      `./vim-update-bundles #{@starter_urls} --submodule=true`
      check_tree tmpdir

      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'

      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/repo 0.2"
      `./vim-update-bundles --submodule=1`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      assert_test ?f, "#{tmpdir}/.gitmodules"
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      `git ls-files --cached .vim/bundle/repo`
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "third"
      `./vim-update-bundles --submodule=1`
      assert_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"
      refute_test ?f, "#{repo}/fourth"
    end
  end


  def test_branch_checkout
    # Ensures new commits on a branch are followed.
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir

      # Make a repository with another branch.
      create_mock_repo "#{tmpdir}/repo"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q -b abranch` }
      update_mock_repo "#{tmpdir}/repo", 'b-second'
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q master` }
      update_mock_repo "#{tmpdir}/repo", 'second'

      # Clone repository on the given branch.
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/repo abranch"
      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{repo}/b-second"
      refute_test ?f, "#{repo}/second"

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "third"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q abranch` }
      update_mock_repo "#{tmpdir}/repo", "b-third"
      `./vim-update-bundles`
      assert_test ?f, "#{repo}/b-second"
      assert_test ?f, "#{repo}/b-third"
      refute_test ?f, "#{repo}/third"

      # TODO: Switch to master and back and to another tag and back.
    end
  end


  def test_submodule_branch_checkout
    # Ensures locking a checkout to a tag.
    prepare_test do |tmpdir|
      Dir.chdir(tmpdir) { `git init` }
      `./vim-update-bundles #{@starter_urls} --submodule=true`
      check_tree tmpdir

      # Make a repository with another branch.
      create_mock_repo "#{tmpdir}/repo"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q -b abranch` }
      update_mock_repo "#{tmpdir}/repo", 'b-second'
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q master` }
      update_mock_repo "#{tmpdir}/repo", 'second'

      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/repo abranch"
      `./vim-update-bundles --submodule=1`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      assert_test ?f, "#{tmpdir}/.gitmodules"
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      `git ls-files --cached .vim/bundle/repo`
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{repo}/b-second"
      refute_test ?f, "#{repo}/second"

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "third"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q abranch` }
      update_mock_repo "#{tmpdir}/repo", "b-third"
      `./vim-update-bundles --submodule=1`
      assert_test ?f, "#{repo}/b-second"
      assert_test ?f, "#{repo}/b-third"
      refute_test ?f, "#{repo}/third"

      # TODO: Switch to master and back and to another tag and back.
    end
  end


  def test_working_bundle_command
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir
      create_mock_repo "#{tmpdir}/repo"
      write_file tmpdir, ".vimrc", <<-EOL
        " Bundle: #{tmpdir}/repo
        " Bundle command: echo hiya > #{tmpdir}/output
      EOL

      `./vim-update-bundles`
      assert_test ?f, "#{tmpdir}/output"
      assert_equal "hiya\n", File.read("#{tmpdir}/output")
    end
  end


  def test_failing_bundle_command
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir

      create_mock_repo "#{tmpdir}/repo"
      write_file tmpdir, ".vimrc", <<-EOL
        " Bundle: #{tmpdir}/repo
        " Bundle-Command: oh-no-this-command-does-not-exist
      EOL

      `./vim-update-bundles`
      assert $?.exitstatus == 47, "the bundle-command should have produced 47, not #{$?.exitstatus}"
    end
  end


  def test_static_bundle
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      Dir.mkdir "#{tmpdir}/.vim/bundle/foreign"
      Dir.mkdir "#{tmpdir}/.vim/bundle/static"
      write_file tmpdir, ".vimrc", '" Static: static'

      `./vim-update-bundles`
      assert_test ?d, "#{tmpdir}/.vim/bundle/static"
      refute_test ?d, "#{tmpdir}/.vim/bundle/foreign"
      assert_test ?d, "#{tmpdir}/.vim/Trashed-Bundles/foreign-01"
    end
  end


  def test_no_updates_run
    # Makes sure we still add and delete even when --no-updates prevents updates
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/plugin1"
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/plugin1"
      `./vim-update-bundles --no-updates`

      # make sure plugin1 was added
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin1/second"

      update_mock_repo "#{tmpdir}/plugin1", "second"
      create_mock_repo "#{tmpdir}/plugin2"
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/plugin1\n\" Bundle: #{tmpdir}/plugin2"
      `./vim-update-bundles -n`   # test single-letter arg

      # make sure plugin1 hasn't been updated but plugin2 has been added
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin1/second"
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin2/first"

      # Remove the repository.
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/plugin1"
      `./vim-update-bundles --no-updates`

      # make sure plugin1 hasn't been updated but plugin2 has been deleted
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin1/second"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin2/first"
    end
  end


  def test_create_dotfile_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.dotfiles"
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, '.dotfiles/vim', '.dotfiles/vimrc'
    end
  end


  def test_create_dotfile_environment_with_vimrc_in_vim
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/zedots"
      Dir.mkdir "#{tmpdir}/zedots/vim"
      write_file tmpdir, "zedots/vim/vimrc", '" ignored'

      `./vim-update-bundles #{@starter_urls} --dotfiles_path='#{tmpdir}/zedots'`
      check_tree tmpdir, 'zedots/vim', 'zedots/vim/vimrc'
      refute_test ?e, "#{tmpdir}/.dotfiles/.vimrc"
      refute_test ?e, "#{tmpdir}/zedots/.vimrc"
    end
  end


  def test_create_custom_vimrc_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/mydots"
      `./vim-update-bundles #{@starter_urls} vimrc_path='#{tmpdir}/mydots/vim rc'`
      check_tree tmpdir, '.vim', 'mydots/vim rc'
    end
  end


  def test_create_custom_conffile_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/parent"
      Dir.mkdir "#{tmpdir}/parent/child"
      ENV['PARENT'] = 'parent'
      File.open("#{tmpdir}/.vim-update-bundles.conf", 'w') { |f|
        f.write "vimrc_path = #{tmpdir}/$PARENT/child/vv zz"
      }
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, '.vim', 'parent/child/vv zz'
    end
  end


  def test_interpolation_works
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls} --vimdir_path='$HOME/vimmy' --vimrc_path='$vimdir_path/vimmyrc'`
      check_tree tmpdir, 'vimmy', 'vimmy/vimmyrc'
    end
  end


  def test_unknown_interpolation_fails
    prepare_test do |tmpdir|
      `./vim-update-bundles --verbose='$unknown' 2>/dev/null`
      assert $?.exitstatus == 1, "the bundle-command should have produced 1, not #{$?.exitstatus}"
      # Make sure it didn't create any files.
      refute_test ?e, "#{tmpdir}/.vim"
      refute_test ?e, "#{tmpdir}/.vimrc"
    end
  end


  def ensure_marker log, marker_string
    # ensure marker is still in file but not at the top
    assert_match /#{marker_string}/, log
    assert_equal "*bundle-log.txt*", log[0..15]
    # also ensure the header only appears once
    refute_match /\*bundle-log\.txt\*/, log[15..-1]
  end


  def test_bundles_txt_and_logfile
    # ensures .vim/doc/bundles.txt and bundle-log.txt are filled in
    prepare_test do |tmpdir|

      # test logfiles with an empty .vimrc
      Dir.mkdir "#{tmpdir}/.vim"
      write_file tmpdir, ".vimrc", ''
      `./vim-update-bundles #{@starter_urls}`

      assert_test ?f, "#{tmpdir}/.vim/doc/bundles.txt"
      assert_test ?f, "#{tmpdir}/.vim/doc/bundle-log.txt"

      # Make a repository with a tagged commit and commits after that.
      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      write_file tmpdir, ".vimrc", "\" Bundle: #{tmpdir}/repo"
      `./vim-update-bundles`

      list = File.read "#{tmpdir}/.vim/doc/bundles.txt"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"

      assert_match /\|repo\|\s*0\.2/, list
      refute_match /\|repo\|\s*0\.3/, list # duh
      assert_match /Add\s*\|repo\|\s*0\.2/, log

      marker_string = "A marker to ensure the logfile is not changed"
      File.open("#{tmpdir}/.vim/doc/bundle-log.txt", "a") { |f| f.puts marker_string }

      # Pull upstream changes.
      update_mock_repo_tagged "#{tmpdir}/repo", 'third', '0.3'
      `./vim-update-bundles`

      list = File.read "#{tmpdir}/.vim/doc/bundles.txt"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"

      refute_match /\|repo\|\s*0\.2/, list
      assert_match /\|repo\|\s*0\.3/, list
      assert_match /Add\s*\|repo\|\s*0\.2/, log
      assert_match /up\s*\|repo\|\s*0\.2 -> 0\.3/, log
      ensure_marker log, marker_string

      # won't bother changing the remote since vim-update-bundles handles it
      # as a delete followed by an add.  might be worth testing though.

      write_file tmpdir, ".vimrc", ''
      `./vim-update-bundles`

      list = File.read "#{tmpdir}/.vim/doc/bundles.txt"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"

      refute_match /\|repo\|\s*0\.2/, list
      refute_match /\|repo\|\s*0\.3/, list
      assert_match /Add\s*\|repo\|\s*0\.2/, log
      assert_match /up\s*\|repo\|\s*0\.2 -> 0\.3/, log
      assert_match /Del\s*\|repo\|\s*0\.3/, log
      ensure_marker log, marker_string
    end
  end

  # def test_update_standard_environment
    # skip "needs work"
  # end
end

