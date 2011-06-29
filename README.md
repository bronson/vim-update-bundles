# vim-update-bundles

Use Pathogen and Git to manage your Vim plugins.

[![Travis Build Status](http://travis-ci.org/bronson/vim-update-bundles.png)](http://travis-ci.org/bronson/vim-update-bundles)


## Description

To install a plugin, put lines like this in your ~/.vimrc:

    " Bundle: jQuery                                      # https://github.com/vim-scripts/jQuery
    " Bundle: scrooloose/nerdtree                         # https://github.com/scrooloose/nerdtree
    " Bundle: https://github.com/scrooloose/nerdtree.git  # Full URL to the repository.

Now, run `./vim-update-bundles`.  Your plugins are installed and ready for use.

Type `:help bundles` from within Vim to show the list of plugins that you have installed.
Hit Control-] on the bundle's name to jump to its documentation.
Also make sure to look at the bundle-log.


## Installation

One of:

* git clone: `git clone https://github.com/bronson/vim-update-bundles.git`
* rubygem: `gem install vim-update-bundles`
* no install: `curl -s https://raw.github.com/bronson/vim-update-bundles/master/vim-update-bundles | ruby`


## Usage

    $ ./vim-update-bundles --help

If you're not already using Vim, vim-update-bundles will set up a typical vim environment.
Edit your ~/.vimrc and run vim-update-bundles whenever you want changes to take effect.

vim-update-bundles will use ~/.dotfiles if it exists; so, it works seamlessly
with <http://github.com/ryanb/dotfiles> and friends. It also supports Git
submodules (see the configuration section below).

* _-n -\-no-updates_ Adds and deletes bundles but doesn't update them.
  This prevents vim-update-bundles from laboriously scrubbing through every
  bundle in your .vimrc when you just want to make a quick change.

* _-s -\-submodule_ installs bundles as submodules intead of plain Git
  repositories. You must create the parent repository to contain the
  submodules before running vim-update bundles.

* _-v -\-verbose_ prints more information about what's happening.


## Specifying Plugins

vim-update-bundles reads the plugins you want installed from your ~/.vimrc.
Here are the directives it recognizes:

#### Bundle:

Any line of the format `" Bundle: URL [REV]` (not case sensitive) will be
interpreted as a bundle to download.  _URL_ points to a Git repository and
_REV_ is an optional refspec (Git branch, tag, or hash). This allows you to
follow a branch or lock the bundle to a specific tag or commit, i.e.:

    " Bundle: https://github.com/tpope/vim-endwise.git v1.0

If the script lives on vim-scripts or GitHub, the URL can be abbreviated:

    " Bundle: tpope/vim-endwise    ->    https://github.com/tpope/vim-endwise.git
    " Bundle: endwise.vim          ->    https://github.com/vim-scripts/endwise.vim.git

vim-update-bundles never deletes files.  When you uninstall a plugin, it moves it to the .vim/Trashed-Bundles directory.

#### BundleCommand:

Some bundles need to be built after they're installed. Place any number of
`BundleCommand:` directives after `Bundle:` to execute shell commands within
the bundle's directory. To install Command-T and ensure "rake make" is called
every time it's updated:

    " Bundle: https://git.wincent.com/command-t.git
    " BundleCommand: rake make

#### Static:

If you have directories in ~/.vim/bundle that you'd like vim-update-bundles to
ignore, mark them as static.

     " Static: my-plugin


## Configuration File

All configuration options can be passed on the command line or placed in ~/.vim-update-bundles.conf.
Putting "submodules=1" in the config file is the same as passing -s or --submodules on the command line.
Blank lines and comments starting with '#' are ignored.

String interpolation is performed on all values. First configuration settings
are tried then environment variables. For instance, this would expand to
"/home/_username_/.dotfiles/_username_/vim":

    vimdir_path = $dotfiles_path/$USERNAME/vim


## Location of .vim and .vimrc

Unless you have a custom dotfiles configuration, you can probably skip this
section.

vim-update-bundles tries hard to figure out where you want to store your .vim
directory and .vimrc file. It first looks for a dotfiles directory (~/.dotfiles
or specified by dotfiles\_path).

* dotfiles\_path = $HOME/.dotfiles

If dotfiles\_path exists, then vim-update-bundles will use it; otherwise, it
will use the default location:

* vimdir\_path = $dotfiles\_path/vim
* vimdir\_path = $HOME/.vim

Finally, these are the places that vim-update-bundles will look for a .vimrc:

* vimrc\_path = $dotfiles\_path/vim/vimrc
* vimrc\_path = $dotfiles\_path/vimrc
* vimrc\_path = $HOME/.vim/vimrc
* vimrc\_path = $HOME/.vimrc

It always updates the ~/.vim and ~/.vimrc symlinks; so, Vim can find the correct
files.


## Authors

* [Scott Bronson](http://github.com/bronson)
* [Sorin Ionescu](http://github.com/sorin-ionescu)
* [steeef](http://github.com/steeef)
* [Andreas Marienborg](http://github.com/omega)


## Alternatives

[Vundle](http://github.com/gmarik/vundle) by [gmarik](http://github.com/gmarik) is starting to look pretty awesome. 

Additionally, see vim-scripts.org's [tools page](http://vim-scripts.org/vim/tools.html).

