# vim-update-bundles

Use Pathogen and Git to manage your Vim plugins.


## Description

To install a plugin, use either of the following lines in your ~/.vimrc:

    " Bundle: https://github.com/scrooloose/nerdtree.git  # Full URL to the repository.
    " Bundle: scrooloose/nerdtree                         # GitHub username/repository. 

Now, run `./vim-update-bundles`. NERD tree is installed and ready for use.

Type `:help bundles` from within Vim to show the list of plugins that you have installed.
Git version numbering is used; so, NERD tree is at commit g1dd345c, 28 commits past the 4.1.0 tag.
Hit Control-] on the bundle's name to jump to its documentation.

       - |nerdtree|                     4.1.0-28-g1dd345c      2011-03-03
       - |nerdcommenter|                2.2.2-35-gc8d8318      2011-03-01
       - |surround|                     v1.90-5-gd9e6bfd       2011-01-23


## Installation

    $ git clone https://github.com/bronson/vim-update-bundles.git


## Usage

    $ ./vim-update-bundles

If you're not already using Vim, vim-update-bundles will set up useful
defaults. Edit your ~/.vimrc and run vim-update-bundles whenever you want
changes to take effect.

vim-update-bundles will use ~/.dotfiles if it exists; so, it works seamlessly
with <http://github.com/ryanb/dotfiles> and friends. It also supports Git
submodules (see the configuration section below).


## Specifying Plugins

vim-update-bundles reads the plugins you want installed from your ~/.vimrc.
Here are the directives it recognizes:

#### Bundle:

Any line of the format `" Bundle: URL [REV]` (not case sensitive) will be
interpreted as a bundle to download.  _URL_ points to a Git repository and
_REV_ is an optional refspec (Git branch, tag, or hash). This allows you to
follow a branch or lock the bundle to a specific tag or commit, i.e.:

    " Bundle: https://github.com/tpope/vim-endwise.git v1.0

You can also abbreviate the repository:

    " Bundle: tpope/vim-endwise    ->    https://github.com/tpope/vim-endwise.git
    " Bundle: endwise.vim          ->    https://github.com/vim-scripts/endwise.vim.git

#### Bundle Commands:

Some bundles need to be built after they're installed. Place any number of
`Bundle-Command:` directives after `Bundle:` to execute shell commands within
the bundle's directory. To install the Command-T plugin and call "rake make"
every time it's updated, put:

    " Bundle: https://git.wincent.com/command-t.git
    " Bundle-Command: rake make

#### Static:

If you have directories in ~/.vim/bundle that you'd like vim-update-bundles to
ignore, mark them as static.

     " Static: vim-endwise 


### Runtime Arguments

* _-\-verbose_ prints more information about what's happening.

* _-\-submodule_ installs bundles as submodules intead of plain Git
  repositories. You must create the parent repository to contain the
  submodules before running vim-update bundles.


## Configuration

All configuration options can be passed on the command line or placed in
~/.vim-update-bundles.conf. You can put "-\-verbose" in your config file or
pass "verbose=1" on the command line -- it's all the same to
vim-update-bundles. Blank lines and comments starting with '#' are ignored.

String interpolation is performed on all values. First configuration settings
are tried then environment variables. For instance, this would expand to
"/home/_username_/.dotfiles/_username_/vim":

    vimdir_path = $dotfiles_path/$USERNAME/vim

#### Location of .vim and .vimrc

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

#### Location of template files

You can change the initial pathogen.vim and .vimrc used when setting up a new
environemnt. These can be either a path in the filesystem or a URL. It is
mostly used for testing.

* starter\_url = https://github.com/bronson/dotfiles/raw/master/.vimrc
* pathogen\_url = https://github.com/tpope/vim-pathogen/raw/master/autoload/pathogen.vim


## Authors

* [Scott Bronson](http://github.com/bronson)
* [steeef](http://github.com/steeef)
* [Andreas Marienborg](http://github.com/omega)
* [Sorin Ionescu](http://github.com/sorin-ionescu)


## Alternatives

[Vundle](http://github.com/gmarik/vundle) by [gmarik](http://github.com/gmarik) is starting to look pretty awesome. 

Additionally, see Vim Script's [tools](http://vim-scripts.org/vim/tools.html).

