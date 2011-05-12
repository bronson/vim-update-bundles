# vim-update-bundles

Use Pathogen and Git to manage your Vim plugins.


## Description

To install a plugin, add the following line to your ~/.vimrc:

    " Bundle: git://github.com/scrooloose/nerdtree.git
    " Bundle: scrooloose/nerdtree     # same thing, just shorter

Now run ./vim-update-bundles.  Nerdtree is installed and ready for use.

Type ":help bundles" from within vim to show the list of plugins that you have installed.
Git version numbering is used so nerdtree is at commit g1dd345c, 28 commits past the 4.1.0 tag.
Hit Control-] on the bundle's name to jump to its documentation.

       - |nerdtree|                     4.1.0-28-g1dd345c      2011-03-03
       - |nerdcommenter|                2.2.2-35-gc8d8318      2011-03-01
       - |surround|                     v1.90-5-gd9e6bfd       2011-01-23


## Installation

    $ git clone git://github.com/bronson/vim-update-bundles.git


## Usage

    $ ./vim-update-bundles

If you're not already using Vim, vim-update-bundles will set you up with some useful defaults.
Now edit your ~/.vimrc and run vim-update-bundles whenever you want the changes to take effect.

vim-update-bundles will use ~/.dotfiles if it exists so it works seamlessly with <http://github.com/ryanb/dotfiles> and friends.
It also supports git submodules (see the configuration section below).


## Specifying Plugins

vim-update-bundles reads the plugins you want to be installed from your ~/.vimrc.
Here are the directives it recognizes:

#### Bundle:

Any line of the format '" Bundle: _URL_ _[REV]_' (not case sensitive) will be
interpreted as a bundle to download.  _URL_ is to a git repository, and _REV_ is an
optional refspec (git branch, tag, or sha1).  This allows you to follow a branch
or lock the bundle to a specific tag or commit, i.e.:

    " Bundle: git://github.com/tpope/vim-endwise.git v1.0

You can also abbreviate the repository:

    " Bundle: tpope/vim-endwise    -> git://github.com/tpope/vim-endwise.git
    " Bundle: endwise.vim          -> git://github.com/vim-scripts/endwise.vim.git

#### Bundle Commands:

Some bundles need to be built after they're installed.  No problem, just put
any number of Bundle-Command: directives after the Bundle.  Bundle-command executes
its shell commands within the bundle's directory.  To install the Command-T
plugin and call "rake make" every time it's updated:

    " Bundle: git://git.wincent.com/command-t.git
    " Bundle-Command: rake make

#### Static:

if you have directories in ~/.vim/bundle that you'd like vim-update-bundles
to ignore, just mark them as static.

     " Static: mynewplugin


### Runtime Arguments

* -\-verbose: prints more about what's happening

* -\-submodule: installs bundles as submodules intead of plain git repos.
     Of course, you must create the parent repo to contain the submodules before running vim-update bundles.


## Configuration

All configuration options can be passed on the command line or placed in ~/.vim-update-bundles.conf.
You can put "-\-verbose" in your config file or pass "verbose=1" on the command line -- it's all the same to vim-update-bundles.
Blank lines and comments starting with '#' are ignored.

String interpolation is performed on all values.  First configuration settings are tried, then environment variables.
For instance, this would expand to "/home/_username_/.dotfiles/_username_/vim":

    vimdir_path = $dotfiles_path/$USERNAME/vim

#### Location of .vim and .vimrc

Unless you have a very custom dotfile configuration, you can probably skip this section.

vim-update-bundles tries very hard to figure out where you want to store your .vim directory and .vimrc file.
It first looks for a dotfiles directory (~/.dotfiles or specified by dotfiles\_path).

* dotfiles\_path = $HOME/.dotfiles

If dotfiles\_path exists then vim-update-bundles will use it, otherwise it will use the default location:

* vimdir\_path = $dotfiles\_path/vim
* vimdir\_path = $HOME/.vim

Finally, these are the places that vim-update-bundles will look for a .vimrc:

* vimrc\_path = $dotfiles\_path/vim/vimrc
* vimrc\_path = $dotfiles\_path/vimrc
* vimrc\_path = $HOME/.vim/vimrc
* vimrc\_path = $HOME/.vimrc

It always updates the ~/.vim and ~/.vimrc symlinks so Vim can find the correct files.

#### Location of template files

You can change the initial pathogen.vim and .vimrc used when setting up a new environemnt.
these can be either a path in the filesystem or a URL.  This is mostly used for testing.

* starter\_url = https://github.com/bronson/dotfiles/raw/master/.vimrc
* pathogen\_url = https://github.com/tpope/vim-pathogen/raw/master/autoload/pathogen.vim


## Authors

* Scott Bronson <http://github.com/bronson>
* steeef <http://github.com/steeef>
* Andreas Marienborg <http://github.com/omega>
* Sorin Ionescu <http://github.com/sorin-ionescu>


## Alternatives

Vundle by gmarik is starting to look pretty awesome. <http://github.com/gmarik/vundle>

Also see <http://vim-scripts.org/tools.html>

