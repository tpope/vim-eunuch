# eunuch.vim

Vim sugar for the UNIX shell commands that need it the most.  Features
include:

* `:Delete`: Delete a buffer and the file on disk simultaneously.
* `:Unlink`: Like `:Delete`, but keeps the now empty buffer.
* `:Move`: Rename a buffer and the file on disk simultaneously.
* `:Rename`: Like `:Move`, but relative to the current file's containing directory.
* `:Chmod`: Change the permissions of the current file.
* `:Mkdir`: Create a directory, defaulting to the parent of the current file.
* `:Cfind`: Run `find` and load the results into the quickfix list.
* `:Clocate`: Run `locate` and load the results into the quickfix list.
* `:Lfind`/`:Llocate`: Like above, but use the location list.
* `:Wall`: Write every open window.  Handy for kicking off tools like [guard][].
* `:SudoWrite`: Write a privileged file with `sudo`.
* `:SudoEdit`: Edit a privileged file with `sudo`.
* File type detection for `sudo -e` is based on original file name.
* New files created with a shebang line are automatically made executable.

[guard]: https://github.com/guard/guard

## Installation

Install using your favorite package manager, or use Vim's built-in package
support:

    mkdir -p ~/.vim/pack/tpope/start
    cd ~/.vim/pack/tpope/start
    git clone https://tpope.io/vim/eunuch.git
    vim -u NONE -c "helptags eunuch/doc" -c q

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
