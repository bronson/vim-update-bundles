require 'rubygems'
require 'minitest/unit'
require 'tempfile'
require 'tmpdir'
MiniTest::Unit.autorun

# todo: test that tagstr sha1 works
#   also switching from a branch/tag/sha to master and back.
#   also with submodules
# todo: test BUNDLE-COMMAND
# todo: test removing bundles multiple times.
# todo: what happens when checking out a branch or tag and it doesn't exist?

# We actually shell out to the executable.  This isn't really unit
# testing but I'd rather have end-to-end testing in this case anyway.


class TestUpdater < MiniTest::Unit::TestCase
  def prepare_test
    # creates a tmpdir to run the test in then yields to the test
    Dir.mktmpdir('vimtest-') do |tmpdir|
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
    # create local mocks for the files would download, saves net traffic and test time.
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

  def check_tree base, dotvim, vimrc
    # makes sure that the dir looks like a plausible vim installation
    assert test ?l, "#{base}/.vimrc"
    assert_equal File.readlink("#{base}/.vimrc"), "#{base}/#{vimrc}"
    assert test ?f, "#{base}/#{vimrc}"
    assert test ?f, "#{base}/#{dotvim}/autoload/pathogen.vim"
  end


  def test_standard_run
    # creates a starter environment then updates a few times
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vim/vimrc"
      assert test ?f, "#{tmpdir}/.vim/doc/bundles.txt"
      assert test ?d, "#{tmpdir}/.vim/bundle"
      assert_equal ['.', '..'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }

      # add a repo
      create_mock_repo "#{tmpdir}/repo"
      write_file tmpdir, ".vim/vimrc", "\" BUNDLE: #{tmpdir}/repo"
      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo"  # the local repo, not the origin
      assert test ?f, "#{repo}/first"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # pull some upstream changes
      update_mock_repo "#{tmpdir}/repo", "second"
      `./vim-update-bundles`
      assert test ?f, "#{tmpdir}/.vim/bundle/repo/second"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # remove the repo
      write_file tmpdir, ".vim/vimrc", ""
      `./vim-update-bundles`
      assert !test(?d, repo)
    end
  end


  def test_dont_blow_away_existing_vimrc
    # don't want to destroy a previously existing .vimrc
    prepare_test do |tmpdir|
      str = "don't tread on me"
      write_file tmpdir, '.vimrc', str
      `./vim-update-bundles #{@starter_urls} --dotvimrc='#{tmpdir}/.vimrc'`
      assert_equal str, File.read("#{tmpdir}/.vimrc")
    end
  end


  def test_submodule_run
    # creates a starter environment using submodules
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.vim"
      Dir.chdir("#{tmpdir}/.vim") { `git init` }
      `./vim-update-bundles #{@starter_urls}`
      # check_tree tmpdir, ".vim", ".vim/vimrc"

      # add submodule
      create_mock_repo "#{tmpdir}/repo"
      File.open("#{tmpdir}/.vim-update-bundles.conf", 'w') { |f| f.write "submodule = true" }
      write_file tmpdir, ".vim/vimrc", "\" BUNDLE: #{tmpdir}/repo"

      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo"  # the local repo, not the origin
      assert test ?f, "#{repo}/first"
      assert test ?f, "#{tmpdir}/.vim/.gitmodules"
      assert_equal 1, File.read("#{repo}/.git/info/exclude").scan("doc/tags").size

      # pull some upstream changes
      update_mock_repo "#{tmpdir}/repo", "second"
      `./vim-update-bundles`
      assert test ?f, "#{tmpdir}/.vim/bundle/repo/second"

      # remove the repo
      write_file tmpdir, ".vim/vimrc", ""
      `./vim-update-bundles`
      assert !test(?d, repo)
    end
  end


  def test_tagstr_checkout
    # ensures that you can lock a checkout to a particular tag
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vim/vimrc"

      # make a repo with a tagged commit, and commits after that
      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'

      write_file tmpdir, ".vim/vimrc", "\" BUNDLE: #{tmpdir}/repo 0.2"
      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo"  # the local repo, not the origin
      assert test ?f, "#{repo}/first"
      assert test ?f, "#{repo}/second"
      assert !test(?f, "#{repo}/third")

      # pull some upstream changes
      update_mock_repo "#{tmpdir}/repo", "fourth"
      `./vim-update-bundles`
      assert test(?f, "#{repo}/second")
      assert !test(?f, "#{repo}/third")
      assert !test(?f, "#{repo}/fourth")

      # TODO: switch to master and back, and to another tag and back
    end
  end


  def test_submodule_tagstr_checkout
    # ensures that you can lock a checkout to a particular tag
    prepare_test do |tmpdir|
      Dir.chdir(tmpdir) { `git init` }
      `./vim-update-bundles #{@starter_urls} --submodule=true`
      check_tree tmpdir, ".vim", ".vim/vimrc"

      create_mock_repo "#{tmpdir}/repo"
      update_mock_repo_tagged "#{tmpdir}/repo", 'second', '0.2'
      update_mock_repo "#{tmpdir}/repo", 'third'

      write_file tmpdir, ".vim/vimrc", "\" BUNDLE: #{tmpdir}/repo 0.2"
      `./vim-update-bundles --submodule=1`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      assert test ?f, "#{tmpdir}/.gitmodules"
      repo = "#{tmpdir}/.vim/bundle/repo"  # the local repo, not the origin
      `git ls-files --cached .vim/bundle/repo`
      assert test ?f, "#{repo}/first"
      assert test ?f, "#{repo}/second"
      assert !test(?f, "#{repo}/third")

      # pull some upstream changes
      update_mock_repo "#{tmpdir}/repo", "third"
      `./vim-update-bundles --submodule=1`
      assert test(?f, "#{repo}/second")
      assert !test(?f, "#{repo}/third")
      assert !test(?f, "#{repo}/fourth")
    end
  end


  def test_branch_checkout
    # ensures it will still follow new commits on a branch
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vim/vimrc"

      # make a repo with another branch
      create_mock_repo "#{tmpdir}/repo"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q -b abranch` }
      update_mock_repo "#{tmpdir}/repo", 'b-second'
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q master` }
      update_mock_repo "#{tmpdir}/repo", 'second'

      # clone that repo on the given branch
      write_file tmpdir, ".vim/vimrc", "\" BUNDLE: #{tmpdir}/repo abranch"
      `./vim-update-bundles`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      repo = "#{tmpdir}/.vim/bundle/repo"  # the local repo, not the origin
      assert test ?f, "#{repo}/first"
      assert test ?f, "#{repo}/b-second"
      assert !test(?f, "#{repo}/second")

      # pull some upstream changes
      update_mock_repo "#{tmpdir}/repo", "third"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q abranch` }
      update_mock_repo "#{tmpdir}/repo", "b-third"
      `./vim-update-bundles`
      assert test(?f, "#{repo}/b-second")
      assert test(?f, "#{repo}/b-third")
      assert !test(?f, "#{repo}/third")

      # TODO: switch to master and back, and to another branch and back
    end
  end


  def test_submodule_branch_checkout
    # ensures that you can lock a checkout to a particular tag
    prepare_test do |tmpdir|
      Dir.chdir(tmpdir) { `git init` }
      `./vim-update-bundles #{@starter_urls} --submodule=true`
      check_tree tmpdir, ".vim", ".vim/vimrc"

      # make a repo with another branch
      create_mock_repo "#{tmpdir}/repo"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q -b abranch` }
      update_mock_repo "#{tmpdir}/repo", 'b-second'
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q master` }
      update_mock_repo "#{tmpdir}/repo", 'second'

      write_file tmpdir, ".vim/vimrc", "\" BUNDLE: #{tmpdir}/repo abranch"
      `./vim-update-bundles --submodule=1`
      assert_equal ['.', '..', 'repo'], Dir.open("#{tmpdir}/.vim/bundle") { |d| d.sort }
      assert test ?f, "#{tmpdir}/.gitmodules"
      repo = "#{tmpdir}/.vim/bundle/repo"  # the local repo, not the origin
      `git ls-files --cached .vim/bundle/repo`
      assert test ?f, "#{repo}/first"
      assert test ?f, "#{repo}/b-second"
      assert !test(?f, "#{repo}/second")

      # pull some upstream changes
      update_mock_repo "#{tmpdir}/repo", "third"
      Dir.chdir("#{tmpdir}/repo") { `git checkout -q abranch` }
      update_mock_repo "#{tmpdir}/repo", "b-third"
      `./vim-update-bundles --submodule=1`
      assert test(?f, "#{repo}/b-second")
      assert test(?f, "#{repo}/b-third")
      assert !test(?f, "#{repo}/third")

      # TODO: switch to master and back, and to another branch and back
    end
  end


  def test_working_bundle_command
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vim/vimrc"
      create_mock_repo "#{tmpdir}/repo"
      write_file tmpdir, ".vim/vimrc", <<-EOL
        " Bundle: #{tmpdir}/repo
        " Bundle command: echo hiya > #{tmpdir}/output
      EOL
      `./vim-update-bundles`

      assert test(?f, "#{tmpdir}/output")
      assert_equal "hiya\n", File.read("#{tmpdir}/output")
    end
  end


  def test_failing_bundle_command
    prepare_test do |tmpdir|
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, ".vim", ".vim/vimrc"
      create_mock_repo "#{tmpdir}/repo"
      write_file tmpdir, ".vim/vimrc", <<-EOL
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
      write_file tmpdir, ".vim/vimrc", <<-EOL
        " Static: static
      EOL
      `./vim-update-bundles`
      assert test(?d, "#{tmpdir}/.vim/bundle/static")
      assert !test(?d, "#{tmpdir}/.vim/bundle/foreign")
      assert test(?d, "#{tmpdir}/.vim/Trashed-Bundles/foreign-01")
    end
  end


  def test_create_dotfile_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/.dotfiles"
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, '.dotfiles/vim', '.dotfiles/vimrc'
    end
  end


  def test_create_custom_vimrc_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/mydots"
      `./vim-update-bundles #{@starter_urls} dotvimrc='#{tmpdir}/mydots/vim rc'`
      check_tree tmpdir, '.vim', 'mydots/vim rc'
    end
  end


  def test_create_custom_conffile_environment
    prepare_test do |tmpdir|
      Dir.mkdir "#{tmpdir}/parent"
      Dir.mkdir "#{tmpdir}/parent/child"
      File.open("#{tmpdir}/.vim-update-bundles.conf", 'w') { |f|
        f.write "dotvimrc = '#{tmpdir}/parent/child/vv zz'"
      }
      `./vim-update-bundles #{@starter_urls}`
      check_tree tmpdir, '.vim', 'parent/child/vv zz'
    end
  end


  # def test_update_standard_environment
    # skip "needs work"
  # end
end

