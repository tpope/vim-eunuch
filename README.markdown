# eunuch.vim

Vim sugar for the UNIX shell commands that need it the most.  Features
include:

* `:Unlink`: Delete a buffer and the file on disk simultaneously.
* `:Remove`: Like `:Unlink`, but doesn't require a neckbeard.
* `:Move`: Rename a buffer and the file on disk simultaneously.
* `:Chmod`: Change the permissions of the current file.
* `:Mkdir`: Create a directory, defaulting to the parent of the current file.
* `:Find`: Run `find` and load the results into the quickfix list.
* `:Locate`: Run `locate` and load the results into the quickfix list.
* `:Wall`: Write every open window.  Handy for kicking off tools like [guard][].
* `:SudoWrite`: Write a privileged file with `sudo`.
* `:SudoEdit`: Edit a privileged file with `sudo`.
* File type detection for `sudo -e` is based on original file name.
* New files created with a shebang line are automatically made executable.

[guard]: https://github.com/guard/guard

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-eunuch.git

Once help tags have been generated, you can view the manual with
`:help eunuch`.

## Contributing

See the contribution guidelines for
[pathogen.vim](https://github.com/tpope/vim-pathogen#readme).

## Self-Promotion

Like eunuch.vim? Follow the repository on
[GitHub](https://github.com/tpope/vim-eunuch) and vote for it on
[vim.org](http://www.vim.org/scripts/script.php?script_id=4300).  And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright (c) Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
