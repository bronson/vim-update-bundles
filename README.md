# vim-update-bundles

Use Pathogen and Git to manage your Vim plugins.


# End of Life

It's [official](https://github.com/bronson/dotfiles/commit/5eec6f3cf83ba59ff0f32eab30964c142560cec9).
This has been a great run, thanks to everyone who supplied patches.
Now I'm watching [Vim Mode Plus](https://github.com/t9md/atom-vim-mode-plus) with great interest.

Nothing has changed in the code, vim-update-bundles should work as well
as it always has.


## Description

To install plugins, put lines like this in your ~/.vimrc:

    Bundle 'jQuery'                                  # https://github.com/vim-scripts/jQuery
    Bundle 'scrooloose/nerdtree'                     # https://github.com/scrooloose/nerdtree
    Bundle 'git://git.wincent.com/command-t.git'     # Full URL to the repo to clone

When you run `./vim-update-bundles`, your plugins will be installed and ready for use.

Type `:help bundles` from within Vim to show the list of plugins that you have installed.
Hit Control-] on the bundle's name to jump to its documentation.
Also look at `:help bundle-log`.

It works with [~/.dotfiles](http://github.com/ryanb/dotfiles) and Git submodules.

If you're not already using Vim, just run `./vim-update-bundles` and a full environment
will be set up for you.


## Installation

One of:

* git clone: `git clone https://github.com/bronson/vim-update-bundles.git`
* rubygem: `gem install vim-update-bundles`
* no install: `curl -s https://raw.github.com/bronson/vim-update-bundles/master/vim-update-bundles | ruby`


## Usage

Just run `./vim-update-bundles` to install and remove plugins to match
the ones named in your ~/.vimrc.

* _-n -\-no-updates_ Adds and deletes bundles but doesn't update them.
  This prevents vim-update-bundles from laboriously scrubbing through every
  bundle in your .vimrc when you just want to make a quick change.

* _-v -\-verbose_ prints more information about what's happening.
  Pass multiple -v -v -v for more verbosity.

* _-\-vimdir-path=path_ specifies the .vim directory that will contain
  your autoload and bundles.

* _-\-vimrc-path_ specifies the location of your ~/.vimrc file.

* _-\-help_ prints usage information.

Submodules and dotfiles are autodetected.  Run with --verbose to ensure
that everything is being detected correctly.


## Specifying Plugins

vim-update-bundles reads the plugins you want installed from comments in your ~/.vimrc.
Here are the directives it recognizes:

#### Bundle:

Any line of the format `" Bundle: URL [REV]` (not case sensitive) will be
interpreted as a bundle to download.  _URL_ points to a Git repository and
_REV_ is an optional refspec (Git branch, tag, or hash). This allows you to
follow a branch or lock the bundle to a specific tag or commit, i.e.:

    Bundle: https://github.com/tpope/vim-endwise.git v1.0

If the script lives on vim-scripts or GitHub, the URL can be abbreviated:

    Bundle: tpope/vim-endwise    ->    https://github.com/tpope/vim-endwise.git
    Bundle: endwise.vim          ->    https://github.com/vim-scripts/endwise.vim.git

vim-update-bundles never deletes files.  When you uninstall a plugin, it moves it to the .vim/Trashed-Bundles directory.

#### BundleCommand:

To execute a shell command every time vim-update-bundles is run, specify a
BundleCommand.  You can have any number of BundleCommands in your .vimrc.
The following would install Command-T and run its rake make:

    " Bundle: https://git.wincent.com/command-t.git
    " BundleCommand: cd command-t && rake make

#### Static:

If you have directories in ~/.vim/bundle that you'd like vim-update-bundles to
ignore, mark them as static.

     " Static: my-plugin

### Vundle

vim-update-bundles also supports Vundle-style directives.  This allows you to use
either tool to manage your bundles -- use whichever is more convenient at the time.


## Location of .vim and .vimrc

vim-update-bundles will use ~/.vim and ~/.vimrc if they exist.
Since this is also what Vim uses, most people can stop reading here.

If ~/.dotfiles exists, vim-update-bundles will look for .dotfiles/vim and .dotfiles/vimrc.

If your dotfiles are in a custom place, you can specify --vimdir-path and --vimrc-path
on the command line or in vim-update-bundles.conf.

If vim-update-bundles still can't find a Vim environment, it will create one for you.
It creates the ~/.vim directory, downloads a default ~/.vimrc, then installs the default
set of plugins.

If you're unsure which vimdir_path and vimrc_path are being used,
`vim-update-bundles --verbose` will tell you.


## Runtime Path

If you want to use Pathogen, place this at the top of your .vimrc:

    runtime bundle/vim-pathogen/autoload/pathogen.vim
    " Bundle: tpope/vim-pathogen
    call pathogen#infect()

Or, if you want to use Vundle, use this:

    set rtp+=~/.vim/bundle/vundle/
    call vundle#rc()
    " Tell Vim to ignore BundleCommand until vundle supports it
    com! -nargs=? BundleCommand
    Bundle 'https://github.com/gmarik/vundle'

If you're wondering why you're being asked to delete pathogen.vim, it's because
of a big improvement to the way vim-update-bundles works.  Now, instead of
downloading Pathogen and then never updating it, vim-update-bundles will use
the plugin manager you specify in your .vimrc and keep it up to date with the
rest of your plugins.


## Authors

This software is released under the [MIT License](http://en.wikipedia.org/wiki/Mit_license).

* [Scott Bronson](http://github.com/bronson)
* [Sorin Ionescu](http://github.com/sorin-ionescu)
* [steeef](http://github.com/steeef)
* [Andreas Marienborg](http://github.com/omega)


## Alternatives

[Vundle](http://github.com/gmarik/vundle) by [gmarik](http://github.com/gmarik) is starting to look pretty awesome. 

Additionally, see vim-scripts.org's [tools page](http://vim-scripts.org/vim/tools.html).

