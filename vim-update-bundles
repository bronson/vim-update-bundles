#!/usr/bin/env ruby

# Reads the bundles you want installed out of your $HOME/.vimrc file,
# then synchronizes .vim/bundles to match, downloading new repositories
# as needed.  It also removes bundles that are no longer used.
#
# To specify a bundle in your .vimrc, just add a line like this:
#   " BUNDLE: git://git.wincent.com/command-t.git
# If you want a branch other than 'master', add the branch name on the end:
#   " Bundle: git://github.com/vim-ruby/vim-ruby.git noisy
# Or tag or sha1: (this results in a detached head, see 'git help checkout')
#   " bundle: git://github.com/bronson/vim-closebuffer.git 0.2
#   " bundle: git://github.com/tpope/vim-rails.git 42bb0699
#
# If your .vim folder is stored in a git repository, you can add bundles
# as submodules by putting "submodule=true" in ~/.vim-update-bundles.conf.
#
# todo: windows compatibility?

require 'fileutils'
require 'open-uri'


def dotfiles *path
  # autodetects a ~/.dotfiles directory.
  dir = File.join ENV['HOME'], '.dotfiles'
  return File.join(dir, *path) if test ?d, dir
end

def dotvim *path
  # Path to files inside your .vim directory, i.e. dotvim('autoload', 'pathogen')
  File.join $dotvim, *path
end

def ensure_dir dir
  Dir.mkdir dir unless test ?d, dir
end

def download_file url, file
  open(url) do |r|
    File.open(file, 'w') do |w|
      w.write(r.read)
    end
  end
end

def run *cmd
  # runs cmd, returns its stdout, bails on error
  # arg, IO.popen only accepts a string on 1.8 so rewrite it here.
  puts "-> #{[cmd].join(" ")}" if $verbose
  outr, outw = IO::pipe
  pid = fork {
    outr.close; STDOUT.reopen outw; outw.close
    exec *cmd.flatten.map { |c| c.to_s }
  }
  outw.close
  result = outr.read
  outr.close
  Process.waitpid pid
  raise "command <<#{[cmd].join(" ")}>> exited with error #{$?.exitstatus}" unless $?.success?
  result
end

def git *cmd
  if !$verbose && %w{checkout clone fetch pull}.include?(cmd.first.to_s)
    cmd.insert 1, '-q'
  end
  run :git, *cmd
end


def print_bundle dir, doc
  version = date = ''
  Dir.chdir(dir) do
    version = `git describe --tags 2>/dev/null`.chomp
    version = "n/a" if version == ''
    date = git(:log, '-1', '--pretty=format:%ai').chomp
  end
  doc.printf "  - %-30s %-22s %s\n", "|#{dir}|", version, date.split(' ').first
end


def ignore_doc_tags
  exclude = File.read ".git/info/exclude"
  if exclude !~ /doc\/tags/
    File.open(".git/info/exclude", "w") { |f|
      f.write exclude.chomp + "\ndoc/tags\n"
    }
  end
end


def in_git_root inpath=nil
  # submodules often require the cwd to be the git root.  if you pass a path
  # relative to the cwd, your block receives it relative to the root.
  path = File.join Dir.pwd, inpath if inpath
  Dir.chdir("./" + git('rev-parse', '--show-cdup').chomp) do
    path.sub! /^#{Dir.pwd}\/?/, '' if path
    yield path
  end rescue nil   # git deletes the bundle dir if it's empty
end


def clone_bundle dir, url, tagstr
  unless $submodule
    puts "cloning #{dir} from #{url}#{tagstr}"
    git :clone, url, dir
  else
    puts "adding submodule #{dir} from #{url}#{tagstr}"
    in_git_root(dir) { |mod| git :submodule, :add, url, mod }
  end
end


def download_bundle dir, url, tag, doc
  tagstr = " at #{tag}" if tag
  if test ?d, dir
    remote = Dir.chdir(dir)  { git(:config, '--get', 'remote.origin.url').chomp }
    if remote == url
      puts "updating #{dir} from #{url}#{tagstr}"
      Dir.chdir(dir) { git :fetch }
    else
      puts "repo has changed from #{remote} to #{url}"
      remove_bundle dir
      ensure_dir dotvim('bundle')  # if it was the last bundle, git removed the dir
      clone_bundle dir, url, tagstr
    end
  else
    clone_bundle dir, url, tagstr
  end

  Dir.chdir(dir) do
    # if branch is checked out then it must be pulled, not checked out again
    if tag && !test(?f, ".git/refs/heads/#{tag}")
      git :checkout, tag
    else
      git :pull, :origin, tag || :master
    end
    ignore_doc_tags
  end
  in_git_root(dir) { |mod| git :add, mod } if $submodule
  print_bundle(dir, doc)
end


def read_vimrc
  File.open("#{ENV['HOME']}/.vimrc") do |file|
    file.each_line { |line| yield line }
  end
end


def remove_bundle_to dir, destination
  puts "Erasing #{dir}, find it in #{destination}"
  FileUtils.mv dir, destination
  if $submodule
    in_git_root(dir) { |mod| git :rm, mod }
    puts "  Also delete its lines from .gitmodules and .git/config"
  end
end


def remove_bundle dir
  trash_dir = dotvim("Trashed-Bundles")
  ensure_dir trash_dir
  1.upto(100) do |i|
    destination = "#{trash_dir}/#{dir}-#{'%02d' % i}"
    unless test ?d, destination
      remove_bundle_to dir, destination
      return
    end
  end
  raise "unable to remove #{dir}, please delete #{trash_dir}"
end


def run_bundle_command dir, cmd
  puts "  running: #{cmd}"
  status = Dir.chdir(dir) { system(cmd); $? }
  unless status.success?
    puts "  BUNDLE-COMMAND command failed!"
    exit 47
  end
end


def update_bundles doc
  existing_bundles = Dir['*']
  dir = nil
  read_vimrc do |line|
    if line =~ /^\s*"\s*bundle:\s*(.*)$/i
      url, tag = $1.split
      dir = url.split('/').last.gsub(/^vim-|\.git$/, '')
      download_bundle dir, url, tag, doc
      existing_bundles.delete dir
    elsif line =~ /^\s*"\s*bundle[ -]command:\s*(.*)$/i
      raise "BUNDLE-COMMAND must come after BUNDLE" if dir.nil?
      run_bundle_command dir, $1
    end
  end
  existing_bundles.each { |dir| remove_bundle(dir) }

  if $submodule
    in_git_root do
      puts "  updating submodules"
      git :submodule, :init
      git :submodule, :update
    end
  end
end


def update_bundles_and_docs
  ensure_dir dotvim('doc')
  File.open(dotvim('doc', 'bundles.txt'), "w") do |doc|
    doc.printf "%-32s %s %32s\n\n", "*bundles.txt*", "Bundles", "Version 0.1"
    doc.puts "These are the bundles installed on your system, along with their\n" +
      "versions and release dates.  Downloaded on #{Time.now}.\n\n" +
      "A version number of 'n/a' means upstream hasn't tagged any releases.\n"

    bundle_dir = dotvim('bundle')
    ensure_dir bundle_dir
    Dir.chdir(bundle_dir) { update_bundles(doc) }
    doc.puts "\n"
  end
end


def create_new_vim_environment vimrc, starter_url, pathogen_url
  puts 'Creating a new Vim environment.'
  puts "Downloading starter vimrc..."
  ensure_dir dotvim
  download_file starter_url, vimrc unless test ?e, vimrc
  run :ln, '-s', vimrc, "#{ENV['HOME']}/.vimrc" unless test ?e, "#{ENV['HOME']}/.vimrc"
  run :ln, '-s', dotvim, "#{ENV['HOME']}/.vim" unless test ?e, "#{ENV['HOME']}/.vim"

  puts "Downloading Pathogen..."
  ensure_dir dotvim('autoload')
  download_file pathogen_url, dotvim('autoload', 'pathogen.vim')
end


# the files that get installed when creating a brand new vim environment
starter_url   = "http://github.com/bronson/vim-update-bundles/raw/master/vimrc-starter"
pathogen_url  = "http://github.com/tpope/vim-pathogen/raw/master/autoload/pathogen.vim"
# dotvim is the directory that contains vim bundles, doc, autoload, etc dirs.
dotvim        = dotfiles('vim')   || File.join(ENV['HOME'], '.vim')
dotvimrc      = dotfiles('vimrc') || File.join(dotvim, 'vimrc')
verbose       = nil     # make git quiet by default, verbose=true to hear everything
submodule     = false   # clone dirs normally unless submodule = 1


# config file is written in ruby
conf_file = File.join ENV['HOME'], '.vim-update-bundles.conf'
eval(File.read(conf_file), binding, conf_file) if test(?f, conf_file)
# interpret vars on command line (only useful for testing)
ARGV.each() { |arg| k,v = arg.split('=',2); k.sub! /^--/, '';
  eval "#{k}='#{(v||'').gsub('//', '////').split("'").join("\\'")}'" }

$dotvim, $submodule, $verbose = dotvim, submodule, verbose
if ensure_dir(dotvim) || !test(?f, dotvimrc)
  create_new_vim_environment dotvimrc, starter_url, pathogen_url
  update_bundles_and_docs
  puts 'Done!  Now enable some plugins in your ~/.vimrc file.'
else
  update_bundles_and_docs
  puts "updating helptags..."
  run :vim, '-e', '-c', 'call pathogen#helptags()', '-c', 'q' unless ENV['TESTING']
  puts "done!  Start Vim and type ':help bundles' to see what you have installed."
end

