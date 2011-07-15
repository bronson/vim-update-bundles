require 'test/unit'
require 'tempfile'
require 'tmpdir'
require 'fileutils'

# You can specify where the tests will be run instead of mktmpdir's default:
#   TESTDIR=/ramdisk/test ruby test.rb
# You can also tell the tester to preserve the test directory after running:
#   PRESERVE=1 VERBOSE=1 ruby test.rb -n test_multiple_removes
# VERBOSE=1 causes the vim-update-bundles commands to be printed.
# TRACE=1 forces vim-update-bundles to include a stack trace in any errors.


class TestUpdater < Test::Unit::TestCase
  def prepare_test &block
    # Creates a tmp dir to run the test in then yields to the test.
    args = ['vimtest-']
    args.push ENV['TESTDIR'] if ENV['TESTDIR']
    if ENV['PRESERVE']
      tmpdir = Dir.mktmpdir *args
      prepare_test_trampoline tmpdir, block
    else
      Dir.mktmpdir(*args) do |tmpdir|
        prepare_test_trampoline tmpdir, block
      end
    end
  end

  def prepare_test_trampoline tmpdir, block
    create_mock_files tmpdir
    Dir.mkdir "#{tmpdir}/home"
    block.call "#{tmpdir}/home"
  end

  def write_file path, contents
    File.open(path, 'w') { |f| f.write contents }
  end

  def create_mock_files tmpdir
    # Creates mock files to download (it saves on bandwidth and test time).
    write_file "#{tmpdir}/pathogen",      "\" PATHOGEN SCRIPT"
    write_file "#{tmpdir}/starter-vimrc", "\" STARTER VIMRC"
    @starter_urls = "starter_url='#{tmpdir}/starter-vimrc' pathogen_url='#{tmpdir}/pathogen'"
  end

  def create_mock_repo name, author=nil
    Dir.mkdir name
    Dir.chdir name do
      `git init`
      write_file "#{name}/first", "first"
      `git add first`

      command = "git commit -q -m first"
      command = "sh -c 'GIT_AUTHOR_NAME='\\''#{author}'\\'' #{command}'" if author
      `#{command}`
    end
  end

  def update_mock_repo dir, name="second", contents=nil
    Dir.chdir dir do
      write_file "#{dir}/#{name}", contents || name
      `git add '#{name}'`
      `git commit -q -m '#{name}'`
    end
  end

  def update_mock_repo_tagged dir, name, tag, contents=nil
    update_mock_repo dir, name, contents
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
    assert_test ?d, "#{base}/#{vimdir}"
    assert_test ?f, "#{base}/#{vimdir}/autoload/pathogen.vim"
    assert_test ?f, "#{base}/#{vimrc}"
  end


  # runs the command under test and check the exit status
  def vim_update_bundles tmpdir, *args
    options = { :acceptable_exit_codes => [0], :stderr => nil }
    options.merge!(args.pop) if args.last.kind_of?(Hash)

    runner = prearg = ''
    if ENV['RCOV']
      # run 'rake rcov' to run the coverage of all tests
      runner = "rcov -x analyzer --aggregate '#{ENV['RCOV']}' --no-html "
      prearg = ' -- '
    end

    redirects = ' 2>/dev/null' if options[:stderr] == :suppress
    redirects = ' 2>&1' if options[:stderr] == :merge
    command = "HOME='#{tmpdir}' TESTING=1 #{runner} ./vim-update-bundles #{prearg} #{@starter_urls} #{args.join(' ')} #{redirects}"
    STDERR.puts "Running: #{command}" if ENV['VERBOSE']
    result = `#{command}`

    unless options[:acceptable_exit_codes].include?($?.exitstatus)
      raise "vim-update-bundles returned #{$?.exitstatus} " +
        "instead of #{options[:acceptable_exit_codes].inspect} " +
        "RESULT: <<\n#{result}>>"
    end
    result
  end


  def test_standard_run
    # Creates a starter environment then updates a few times.
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir
      check_tree tmpdir
      assert_test ?f, "#{tmpdir}/.vim/doc/bundles.txt"
      assert_test ?d, "#{tmpdir}/.vim/bundle"
      assert_equal ['.', '..'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }

      # Add a repository.
      create_mock_repo "#{tmpdir}/repo"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo"
      vim_update_bundles tmpdir
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"
      assert_match /1 bundle added$/, log

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "second"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"
      assert_match /1 bundle updated$/, log

      # Remove the repository.
      write_file "#{tmpdir}/.vimrc", ""
      vim_update_bundles tmpdir
      refute_test ?d, repo
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"
      assert_match /1 bundle removed$/, log
    end
  end


  def test_dont_blow_away_existing_vimrc
    # Do not destroy an existing .vimrc.
    prepare_test do |tmpdir|
      str = "don't tread on me"
      write_file "#{tmpdir}/.vimrc", str
      vim_update_bundles tmpdir, "--vimrc_path='#{tmpdir}/.vimrc'"
      assert_equal str, File.read("#{tmpdir}/.vimrc")
    end
  end


  def test_submodule_run
    # Creates a starter environment using submodules.
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.vim"
      Dir.chdir("#{tmpdir}/.vim") { `git init` }
      vim_update_bundles tmpdir
      check_tree tmpdir, ".vim", ".vimrc"

      # Add submodule.
      create_mock_repo "#{tmpdir}/repo"
      File.open("#{tmpdir}/.vim-update-bundles.conf", 'w') { |f| f.write "submodule = true" }
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo"

      vim_update_bundles tmpdir
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{tmpdir}/.vim/.gitmodules"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "second"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"

      # Remove the repository.
      write_file "#{tmpdir}/.vimrc", ""
      vim_update_bundles tmpdir
      refute_test ?d, repo

      ['.gitmodules', '.git/config'].each do |filename|
        text = File.read File.join(tmpdir, '.vim', filename)
        assert_no_match /submodule.*repo/, text
      end
    end
  end


  def test_tag_checkout
    # Ensures locking a checkout to a tag and that .vim/vimrc is used if it
    # already exists.
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.vim"
      write_file "#{tmpdir}/.vimrc", ''
      vim_update_bundles tmpdir
      check_tree tmpdir, ".vim", ".vimrc"

      # Make a repository with a tagged commit and commits after that.
      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'

      # Check out the plugin locked at 0.2
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo 0.2"
      vim_update_bundles tmpdir
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      refute_test ?f, "#{tmpdir}/.vim/bundle/repo/third"

      # Pull upstream changes, make sure we're still locked on 0.2.
      update_mock_repo "#{tmpdir}/repo", "fourth"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      refute_test ?f, "#{tmpdir}/.vim/bundle/repo/third"
      refute_test ?f, "#{tmpdir}/.vim/bundle/repo/fourth"

      # Switch to the branch head
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/third"

      # Switch back to the tag
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo 0.2"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      refute_test ?f, "#{tmpdir}/.vim/bundle/repo/third"
    end
  end


  def test_submodule_tag_checkout
    # Ensures locking a checkout to a tag.
    prepare_test do |tmpdir|
      Dir.chdir(tmpdir) { `git init` }
      vim_update_bundles tmpdir, '--submodule=true'
      check_tree tmpdir

      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo 0.2"
      vim_update_bundles tmpdir, '--submodule=1'
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      assert_test ?f, "#{tmpdir}/.gitmodules"
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      `git ls-files --cached .vim/bundle/repo`
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "third"
      vim_update_bundles tmpdir, '--submodule=1'
      assert_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"
      refute_test ?f, "#{repo}/fourth"
    end
  end


  def test_branch_checkout
    # Ensures new commits on a branch are followed.
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir
      check_tree tmpdir

      # Make a repository with another branch.
      create_mock_repo "#{tmpdir}/repo"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q -b abranch` }
      update_mock_repo "#{tmpdir}/repo", 'b-second'
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q master` }
      update_mock_repo "#{tmpdir}/repo", 'second'

      # Clone repository on the given branch.
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo abranch"
      vim_update_bundles tmpdir
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo" # The local repository, not the origin.
      assert_test ?f, "#{repo}/first"
      assert_test ?f, "#{repo}/b-second"
      refute_test ?f, "#{repo}/second"

      # Pull upstream changes.
      update_mock_repo "#{tmpdir}/repo", "third"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q abranch` }
      update_mock_repo "#{tmpdir}/repo", "b-third"
      vim_update_bundles tmpdir
      assert_test ?f, "#{repo}/b-second"
      assert_test ?f, "#{repo}/b-third"
      refute_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"

      # Switch to the master branch
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo"
      vim_update_bundles tmpdir
      assert_test ?f, "#{repo}/second"
      assert_test ?f, "#{repo}/third"
      refute_test ?f, "#{repo}/b-second"
      refute_test ?f, "#{repo}/b-third"

      # And switch back to our branch
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo abranch"
      vim_update_bundles tmpdir
      assert_test ?f, "#{repo}/b-second"
      assert_test ?f, "#{repo}/b-third"
      refute_test ?f, "#{repo}/second"
      refute_test ?f, "#{repo}/third"
    end
  end


  def test_submodule_branch_checkout
    # Ensures locking a checkout to a tag.
    prepare_test do |tmpdir|
      Dir.chdir(tmpdir) { `git init` }
      vim_update_bundles tmpdir, '--submodule=true'
      check_tree tmpdir

      # Make a repository with another branch.
      create_mock_repo "#{tmpdir}/repo"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q -b abranch` }
      update_mock_repo "#{tmpdir}/repo", 'b-second'
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q master` }
      update_mock_repo "#{tmpdir}/repo", 'second'

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo abranch"
      vim_update_bundles tmpdir, '--submodule=1'
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
      vim_update_bundles tmpdir, '--submodule=1'
      assert_test ?f, "#{repo}/b-second"
      assert_test ?f, "#{repo}/b-third"
      refute_test ?f, "#{repo}/third"
    end
  end


  def test_clone_nonexistent_branch
    # Ensures we error out if we find a nonexistent branch or tag (same code path)
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo1"
      create_mock_repo "#{tmpdir}/repo2"

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo1 nobranch\n\" Bundle: #{tmpdir}/repo2"
      vim_update_bundles tmpdir, :acceptable_exit_codes => [1], :stderr => :suppress
      refute_test ?d, "#{tmpdir}/.vim/bundle/repo2"    # ensure we didn't continue cloning repos
    end
  end


  def test_update_to_nonexistent_branch
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo1"
      create_mock_repo "#{tmpdir}/repo2"

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo1"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo1/first"

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo1 v0.2\n\" Bundle: #{tmpdir}/repo2"
      vim_update_bundles tmpdir, :acceptable_exit_codes => [1], :stderr => :suppress
      refute_test ?d, "#{tmpdir}/.vim/bundle/repo2"    # ensure we didn't continue cloning repos
    end
  end


  def test_duplicate_bundle_entries
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo1"
      write_file "#{tmpdir}/.vimrc",
        "\" Bundle: #{tmpdir}/repo1\n" +
        "\" Bundle: #{tmpdir}/repo1\n"
      output = vim_update_bundles tmpdir, :acceptable_exit_codes => [1], :stderr => :merge
      assert_match /duplicate entry for .*repo1/, output
    end
  end


  def test_bundles_with_conflicting_names
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/one"
      Dir.mkdir "#{tmpdir}/two"
      create_mock_repo "#{tmpdir}/one/repo"
      create_mock_repo "#{tmpdir}/two/repo"

      # write a single .vimrc with conflicting bundles
      write_file "#{tmpdir}/.vimrc",
        "\" Bundle: #{tmpdir}/one/repo\n" +
        "\" Bundle: #{tmpdir}/two/repo\n"
      output = vim_update_bundles tmpdir, :acceptable_exit_codes => [1], :stderr => :merge
      assert_match /urls map to the same bundle: .*repo and .*repo/, output
    end
  end


  def test_remote_for_repo_is_changed
    # plugin name stays the same but the Git url changes
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/one"
      Dir.mkdir "#{tmpdir}/two"
      create_mock_repo "#{tmpdir}/one/repo"
      create_mock_repo "#{tmpdir}/two/repo"
      update_mock_repo "#{tmpdir}/two/repo"

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/one/repo"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/repo/second"

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/two/repo"
      output = vim_update_bundles tmpdir, :stderr => :merge
      assert_match /bundle for repo changed/, output

      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"
      assert_match /bundle for repo changed/, log
    end
  end


  def git_sha repo, branch='HEAD'
    # returns the sha of the topmost commit in the named branch
    sha = `git --git-dir='#{repo}/.git' rev-parse #{branch}`.chomp
    assert_match /^[0-9A-Fa-f]{40}/, sha
    sha
  end


  def test_upstream_regenerates_ancestry_resets_repo
    # Test what happens when the checked out git branch loses its ancestry.
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo1"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo1"
      vim_update_bundles tmpdir

      assert_test ?f, "#{tmpdir}/.vim/bundle/repo1/first"
      orig_head = git_sha("#{tmpdir}/.vim/bundle/repo1")
      assert_equal orig_head, git_sha("#{tmpdir}/repo1")

      # delete/regen repo so it looks identical but all SHAs are different
      FileUtils.rm_rf "#{tmpdir}/repo1"
      create_mock_repo "#{tmpdir}/repo1", "Invalid .-. Second Author"
      vim_update_bundles tmpdir, :stderr => :merge

      new_head = git_sha("#{tmpdir}/.vim/bundle/repo1")
      assert_not_equal orig_head, new_head
      assert_equal new_head, git_sha("#{tmpdir}/repo1")
      assert_test ?d, "#{tmpdir}/.vim/Trashed-Bundles/repo1"  # make sure old was trashed
    end
  end


  def test_pull_with_local_changes_resets_repo
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo1"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo1"
      vim_update_bundles tmpdir
      # make sure repo was successfully cloned
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo1/first"
      assert_equal "first", File.read("#{tmpdir}/.vim/bundle/repo1/first")

      # make a conflicting local change and pull again
      update_mock_repo "#{tmpdir}/repo1", "first", "second commit to first file"
      write_file "#{tmpdir}/.vim/bundle/repo1/first", "local change"
      vim_update_bundles tmpdir, :stderr => :merge

      # make sure the local repo matches the latest upstream
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo1/first"
      assert_equal "second commit to first file", File.read("#{tmpdir}/.vim/bundle/repo1/first")
      # and also verify user's changes are preserved in .Trashed-Bundles
      assert_test ?f, "#{tmpdir}/.vim/Trashed-Bundles/repo1/first"
      assert_equal "local change", File.read("#{tmpdir}/.vim/Trashed-Bundles/repo1/first")
    end
  end


  def test_pull_with_conflicting_local_file_resets_repo
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo1"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo1"
      vim_update_bundles tmpdir
      # make sure repo was successfully cloned
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo1/first"
      assert_equal "first", File.read("#{tmpdir}/.vim/bundle/repo1/first")

      # make a conflicting local change and pull again
      update_mock_repo "#{tmpdir}/repo1", "second"
      write_file "#{tmpdir}/.vim/bundle/repo1/second", "changed!"
      output = vim_update_bundles tmpdir, :stderr => :merge

      # make sure the local repo matches the latest upstream
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo1/second"
      assert_equal "second", File.read("#{tmpdir}/.vim/bundle/repo1/second")
      # and also verify user's changes are preserved in .Trashed-Bundles
      assert_test ?f, "#{tmpdir}/.vim/Trashed-Bundles/repo1/second"
      assert_equal "changed!", File.read("#{tmpdir}/.vim/Trashed-Bundles/repo1/second")
    end
  end


  def clone_and_delete_repo tmpdir, suffix
    write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1"
    vim_update_bundles tmpdir
    assert_test ?d, "#{tmpdir}/.vim/bundle/plugin1"

    write_file "#{tmpdir}/.vimrc", ''
    vim_update_bundles tmpdir
    refute_test ?d, "#{tmpdir}/.vim/bundle/plugin1"
    assert_test ?d, "#{tmpdir}/.vim/Trashed-Bundles/plugin1#{suffix}"
  end


  def test_multiple_removes
    # add and remove a plugin multiple times
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/plugin1"
      clone_and_delete_repo tmpdir, ''
      1.upto(5) { |i| clone_and_delete_repo tmpdir, "-#{"%02d" % i}" }
    end
  end


  def test_multiple_remove_failure
    # Plug up Trashed-Bundles so a bundle can't be removed to ensure
    # that vim-update-bundles bails out and prints a decent error.
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/plugin1"
      Dir.mkdir "#{tmpdir}/.vim"
      Dir.mkdir "#{tmpdir}/.vim/Trashed-Bundles"
      Dir.mkdir "#{tmpdir}/.vim/Trashed-Bundles/plugin1"
      1.upto(99) { |i| Dir.mkdir "#{tmpdir}/.vim/Trashed-Bundles/plugin1-%02d" % i }

      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"

      write_file "#{tmpdir}/.vimrc", ''
      output = vim_update_bundles tmpdir, :acceptable_exit_codes => [1], :stderr => :merge
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      assert_match /unable to remove plugin1/, output
    end
  end


  def test_submodule_remove_failure
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.vim"
      Dir.chdir("#{tmpdir}/.vim") { `git init` }
      create_mock_repo "#{tmpdir}/repo"
      # add plugin as a submodule
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo"
      vim_update_bundles tmpdir, '--submodule'
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_test ?f, "#{tmpdir}/.vim/.gitmodules"

      # remove plugin but write-protect .gitmodules to force failure
      write_file "#{tmpdir}/.vimrc", ''
      File.chmod 0444, "#{tmpdir}/.vim/.gitmodules"
      output = vim_update_bundles tmpdir, '--submodule', :acceptable_exit_codes => [1], :stderr => :merge
      assert_match /could not delete repo from \.gitmodules/, output
    end
  end


  def test_vundle_directives
    # ensure vundle directives work
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/repo"
      # test Bundle and BundleCommand
      write_file "#{tmpdir}/.vimrc", "Bundle '#{tmpdir}/repo'\n" +
        "BundleCommand 'echo \"yep''s\" > ''#{tmpdir}/sentinel'''\n"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_equal "yep's\n", File.read("#{tmpdir}/sentinel")

      # make sure Bundle accepts a branch/tag to check out
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'
      write_file "#{tmpdir}/.vimrc", "Bundle \"#{tmpdir}/repo 0.2\""
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      refute_test ?f, "#{tmpdir}/.vim/bundle/repo/third"

      # mark the bundle as static, make sure it isn't removed
      write_file "#{tmpdir}/.vimrc", "Bundle! 'repo'\n"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/.vim/bundle/repo/first"
    end
  end


  def test_bundle_command
    # oops, there's some duplication with test_working_bundle_command
    prepare_test do |tmpdir|
      # ensure BundleCommand is called when adding a repo
      create_mock_repo "#{tmpdir}/plugin1"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1\n\" BundleCommand: touch '#{tmpdir}/sentinel1'"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/sentinel1"

      # ensure BundleCommand is called when updating a repo
      update_mock_repo "#{tmpdir}/plugin1", "second"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1\n\" Bundle-Command: touch '#{tmpdir}/sentinel2'"
      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/sentinel2"

      # ensure BundleCommand is NOT called when updating a repo when --no-updates is on
      update_mock_repo "#{tmpdir}/plugin1", "second"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1\n\" BundleCommand: touch '#{tmpdir}/sentinel3'"
      vim_update_bundles tmpdir, '--no-updates'
      refute_test ?f, "#{tmpdir}/sentinel3"
    end
  end


  def test_working_bundle_command
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir
      check_tree tmpdir
      create_mock_repo "#{tmpdir}/repo"
      write_file "#{tmpdir}/.vimrc", <<-EOL
        " Bundle: #{tmpdir}/repo
        " Bundle command: echo hiya > #{tmpdir}/output
      EOL

      vim_update_bundles tmpdir
      assert_test ?f, "#{tmpdir}/output"
      assert_equal "hiya\n", File.read("#{tmpdir}/output")
    end
  end


  def test_failing_bundle_command
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir, '#{@starter_urls}'
      check_tree tmpdir

      create_mock_repo "#{tmpdir}/repo"
      write_file "#{tmpdir}/.vimrc", <<-EOL
        " Bundle: #{tmpdir}/repo
        " Bundle-Command: oh-no-this-command-does-not-exist
      EOL

      vim_update_bundles tmpdir, :acceptable_exit_codes => [47], :stderr => :suppress
    end
  end


  def test_static_bundle
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir
      Dir.mkdir "#{tmpdir}/.vim/bundle/foreign"
      Dir.mkdir "#{tmpdir}/.vim/bundle/static"
      write_file "#{tmpdir}/.vimrc", '" Static: static'

      vim_update_bundles tmpdir
      assert_test ?d, "#{tmpdir}/.vim/bundle/static"
      refute_test ?d, "#{tmpdir}/.vim/bundle/foreign"
      assert_test ?d, "#{tmpdir}/.vim/Trashed-Bundles/foreign"
    end
  end


  def test_no_updates_run
    # Makes sure we still add and delete even when --no-updates prevents updates
    prepare_test do |tmpdir|
      create_mock_repo "#{tmpdir}/plugin1"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1"
      vim_update_bundles tmpdir, '--no-updates'

      # make sure plugin1 was added even though --no-updates was turned on
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin1/second"

      update_mock_repo "#{tmpdir}/plugin1", "second"
      create_mock_repo "#{tmpdir}/plugin2"
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1\n\" Bundle: #{tmpdir}/plugin2"
      vim_update_bundles tmpdir, '-n'   # test single-letter arg

      # make sure plugin1 hasn't been updated but plugin2 has been added
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin1/second"
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin2/first"

      # Remove the repository.
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/plugin1"
      vim_update_bundles tmpdir, '--no-updates'

      # make sure plugin1 hasn't been updated but plugin2 has been deleted
      assert_test ?f, "#{tmpdir}/.vim/bundle/plugin1/first"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin1/second"
      refute_test ?f, "#{tmpdir}/.vim/bundle/plugin2/first"
    end
  end


  def test_create_skips_dotfile_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.dotfiles"
      vim_update_bundles tmpdir
      check_tree tmpdir, '.vim', '.vimrc'
    end
  end


  def test_dotfiles_are_used_if_present
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.dotfiles"
      Dir.mkdir "#{tmpdir}/.dotfiles/vim"
      write_file "#{tmpdir}/.dotfiles/vimrc", ''
      vim_update_bundles tmpdir

      check_tree tmpdir, '.dotfiles/vim', '.dotfiles/vimrc'
      refute_test ?d, "#{tmpdir}/.vim"
      refute_test ?f, "#{tmpdir}/.vimrc"
    end
  end


  def test_create_custom_vimrc_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/mydots"
      vim_update_bundles tmpdir, "vimrc_path='#{tmpdir}/mydots/vim rc'"
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
      vim_update_bundles tmpdir
      check_tree tmpdir, '.vim', 'parent/child/vv zz'
    end
  end


  def test_interpolation_works
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir, "--vimdir_path='$HOME/vimmy' --vimrc_path='$vimdir_path/vimmyrc'"
      check_tree tmpdir, 'vimmy', 'vimmy/vimmyrc'
    end
  end


  def test_unknown_interpolation_fails
    prepare_test do |tmpdir|
      vim_update_bundles tmpdir, "--verbose='$unknown'", :acceptable_exit_codes => [1], :stderr => :suppress
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
    assert_no_match /\*bundle-log\.txt\*/, log[15..-1]
  end


  def test_bundles_txt_and_logfile
    # ensures .vim/doc/bundles.txt and bundle-log.txt are filled in
    prepare_test do |tmpdir|

      # test logfiles with an empty .vimrc
      Dir.mkdir "#{tmpdir}/.vim"
      write_file "#{tmpdir}/.vimrc", ''
      vim_update_bundles tmpdir

      assert_test ?f, "#{tmpdir}/.vim/doc/bundles.txt"
      assert_test ?f, "#{tmpdir}/.vim/doc/bundle-log.txt"

      # Make a repository with a tagged commit and commits after that.
      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      write_file "#{tmpdir}/.vimrc", "\" Bundle: #{tmpdir}/repo"
      vim_update_bundles tmpdir

      list = File.read "#{tmpdir}/.vim/doc/bundles.txt"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"

      assert_match /\|repo\|\s*0\.2/, list
      assert_no_match /\|repo\|\s*0\.3/, list # duh
      assert_match /Add\s*\|repo\|\s*0\.2/, log

      marker_string = "A marker to ensure the logfile is not changed"
      File.open("#{tmpdir}/.vim/doc/bundle-log.txt", "a") { |f| f.puts marker_string }

      # Pull upstream changes.
      update_mock_repo_tagged "#{tmpdir}/repo", 'third', '0.3'
      vim_update_bundles tmpdir

      list = File.read "#{tmpdir}/.vim/doc/bundles.txt"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"

      assert_no_match /\|repo\|\s*0\.2/, list
      assert_match /\|repo\|\s*0\.3/, list
      assert_match /Add\s*\|repo\|\s*0\.2/, log
      assert_match /up\s*\|repo\|\s*0\.3\s*<-\s*0\.2/, log
      ensure_marker log, marker_string

      # won't bother changing the remote since vim-update-bundles handles it
      # as a delete followed by an add.  might be worth testing though.

      write_file "#{tmpdir}/.vimrc", ''
      vim_update_bundles tmpdir

      list = File.read "#{tmpdir}/.vim/doc/bundles.txt"
      log = File.read "#{tmpdir}/.vim/doc/bundle-log.txt"

      assert_no_match /\|repo\|\s*0\.2/, list
      assert_no_match /\|repo\|\s*0\.3/, list
      assert_match /Add\s*\|repo\|\s*0\.2/, log
      assert_match /up\s*\|repo\|\s*0\.3\s*<-\s*0\.2/, log
      assert_match /Del\s*\|repo\|\s*0\.3/, log
      ensure_marker log, marker_string
    end
  end

  def test_unknown_argument
    result = vim_update_bundles '/dev/null', '--yarg', :acceptable_exit_codes => [1], :stderr => :merge
    assert_match /Unknown option.*"yarg"/, result

    result = vim_update_bundles '/dev/null', '-y', :acceptable_exit_codes => [1], :stderr => :merge
    assert_match /Unknown option.*"y"/, result

    result = vim_update_bundles '/dev/null', 'y', :acceptable_exit_codes => [1], :stderr => :merge
    assert_match /Unknown option.*"y"/, result
  end

  def test_usage
    result = vim_update_bundles '/dev/null', '--help'
    assert_match /--no-updates/, result
  end

  def test_version
    $load_only = true
    Kernel.load 'vim-update-bundles'
    result = vim_update_bundles '/dev/null', '--version'
    assert_match /vim-update-bundles #{Version}/, result
  end

  def test_verbose
    prepare_test do |tmpdir|
      result = vim_update_bundles tmpdir, '--verbose'
      assert_match /submodule = false/, result
      assert_match /verbose = 1/, result
      assert_match /vimdir_path = "#{tmpdir}\/\.vim"/, result
      assert_match /vimrc_path = "#{tmpdir}\/\.vimrc"/, result
    end
  end
end

