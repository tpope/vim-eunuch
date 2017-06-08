" eunuch.vim - Helpers for UNIX
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.1

if exists('g:loaded_eunuch') || &cp || v:version < 700
  finish
endif
let g:loaded_eunuch = 1

function! s:fnameescape(string) abort
  if exists('*fnameescape')
    return fnameescape(a:string)
  elseif a:string ==# '-'
    return '\-'
  else
    return substitute(escape(a:string," \t\n*?[{`$\\%#'\"|!<"),'^[+>]','\\&','')
  endif
endfunction

function! s:separator()
  return !exists('+shellslash') || &shellslash ? '/' : '\\'
endfunction

command! -bar -bang Unlink
      \ if <bang>1 && &modified |
      \   edit |
      \ elseif delete(expand('%')) |
      \   echoerr 'Failed to delete "'.expand('%').'"' |
      \ else |
      \   edit! |
      \ endif

command! -bar -bang Remove
      \ let s:file = fnamemodify(bufname(<q-args>),':p') |
      \ execute 'bdelete<bang>' |
      \ if !bufloaded(s:file) && delete(s:file) |
      \   echoerr 'Failed to delete "'.s:file.'"' |
      \ endif |
      \ unlet s:file

command! -bar -bang Delete
      \ let s:file = fnamemodify(bufname(<q-args>),':p') |
      \ execute 'bdelete<bang>' |
      \ if !bufloaded(s:file) && delete(s:file) |
      \   echoerr 'Failed to delete "'.s:file.'"' |
      \ endif |
      \ unlet s:file

command! -bar -nargs=1 -bang -complete=file Move :
      \ let s:src = expand('%:p') |
      \ let s:dst = expand(<q-args>) |
      \ if isdirectory(s:dst) || s:dst[-1:-1] =~# '[\\/]' |
      \   let s:dst .= (s:dst[-1:-1] =~# '[\\/]' ? '' : s:separator()) .
      \     fnamemodify(s:src, ':t') |
      \ endif |
      \ if !isdirectory(fnamemodify(s:dst, ':h')) |
      \   call mkdir(fnamemodify(s:dst, ':h'), 'p') |
      \ endif |
      \ let s:dst = substitute(simplify(s:dst), '^\.\'.s:separator(), '', '') |
      \ if <bang>1 && filereadable(s:dst) |
      \   exe 'keepalt saveas '.s:fnameescape(s:dst) |
      \ elseif rename(s:src, s:dst) |
      \   echoerr 'Failed to rename "'.s:src.'" to "'.s:dst.'"' |
      \ else |
      \   setlocal modified |
      \   exe 'keepalt saveas! '.s:fnameescape(s:dst) |
      \   if s:src !=# expand('%:p') |
      \     execute 'bwipe '.s:fnameescape(s:src) |
      \   endif |
      \   filetype detect |
      \ endif |
      \ unlet s:src |
      \ unlet s:dst |
      \ filetype detect

function! s:Rename_complete(A, L, P) abort
  let sep = s:separator()
  let prefix = expand('%:p:h').sep
  let files = split(glob(prefix.a:A.'*'), "\n")
  call filter(files, 'simplify(v:val) !=# simplify(expand("%:p"))')
  call map(files, 'v:val[strlen(prefix) : -1] . (isdirectory(v:val) ? sep : "")')
  return join(files + ['..'.s:separator()], "\n")
endfunction

command! -bar -nargs=1 -bang -complete=custom,s:Rename_complete Rename
      \ Move<bang> %:h/<args>

command! -bar -nargs=1 Chmod :
      \ echoerr get(split(system('chmod '.<q-args>.' '.shellescape(expand('%'))), "\n"), 0, '') |

command! -bar -bang -nargs=? -complete=dir Mkdir
      \ call mkdir(empty(<q-args>) ? expand('%:h') : <q-args>, <bang>0 ? 'p' : '') |
      \ if empty(<q-args>) |
      \  silent keepalt execute 'file' s:fnameescape(expand('%')) |
      \ endif

command! -bar -bang -complete=file -nargs=+ Find   exe s:Grep(<q-bang>, <q-args>, 'find')
command! -bar -bang -complete=file -nargs=+ Locate exe s:Grep(<q-bang>, <q-args>, 'locate')
function! s:Grep(bang,args,prg) abort
  let grepprg = &l:grepprg
  let grepformat = &l:grepformat
  let shellpipe = &shellpipe
  try
    let &l:grepprg = a:prg
    setlocal grepformat=%f
    if &shellpipe ==# '2>&1| tee' || &shellpipe ==# '|& tee'
      let &shellpipe = "| tee"
    endif
    execute 'grep! '.a:args
    if empty(a:bang) && !empty(getqflist())
      return 'cfirst'
    else
      return ''
    endif
  finally
    let &l:grepprg = grepprg
    let &l:grepformat = grepformat
    let &shellpipe = shellpipe
  endtry
endfunction

function! s:SilentSudoCmd(editor) abort
  let cmd = 'env SUDO_EDITOR=' . a:editor . ' VISUAL=' . a:editor . ' sudo -e'
  if !has('gui_running')
    return ['silent', cmd]
  elseif !empty($SUDO_ASKPASS) ||
        \ filereadable('/etc/sudo.conf') &&
        \ len(filter(readfile('/etc/sudo.conf', 50), 'v:val =~# "^Path askpass "'))
    return ['silent', cmd . ' -A']
  else
    return ['', cmd]
endfunction

function! s:SudoSetup(file) abort
  if !filereadable(a:file) && !exists('#BufReadCmd#'.s:fnameescape(a:file))
    execute 'autocmd BufReadCmd ' s:fnameescape(a:file) 'exe s:SudoReadCmd()'
  endif
  if !filewritable(a:file) && !exists('#BufWriteCmd#'.s:fnameescape(a:file))
    execute 'autocmd BufReadPost ' s:fnameescape(a:file) 'set noreadonly'
    execute 'autocmd BufWriteCmd ' s:fnameescape(a:file) 'exe s:SudoWriteCmd()'
  endif
endfunction

let s:error_file = tempname()

function! s:SudoError() abort
  let error = join(readfile(s:error_file), " | ")
  if error =~# '^sudo' || v:shell_error
    return len(error) ? error : 'Error invoking sudo'
  else
    return error
  endif
endfunction

function! s:SudoReadCmd() abort
  if &shellpipe =~ '|&'
    return 'echoerr ' . string('eunuch.vim: no sudo read support for csh')
  endif
  silent %delete_
  let [silent, cmd] = s:SilentSudoCmd('cat')
  execute silent 'read !' . cmd . ' "%" 2> ' . s:error_file
  let exit_status = v:shell_error
  silent 1delete_
  setlocal nomodified
  if exit_status
    return 'echoerr ' . string(s:SudoError())
  endif
endfunction

function! s:SudoWriteCmd() abort
  let [silent, cmd] = s:SilentSudoCmd('tee')
  let cmd .= ' "%" >/dev/null'
  if &shellpipe =~ '|&'
    let cmd = '(' . cmd . ')>& ' . s:error_file
  else
    let cmd .= ' 2> ' . s:error_file
  endif
  execute silent 'write !'.cmd
  let error = s:SudoError()
  if !empty(error)
    return 'echoerr ' . string(error)
  else
    setlocal nomodified
    return ''
  endif
endfunction

command! -bar -bang -complete=file -nargs=? SudoEdit
      \ call s:SudoSetup(fnamemodify(empty(<q-args>) ? expand('%') : <q-args>, ':p')) |
      \ if !&modified || !empty(<q-args>) |
      \   edit<bang> <args> |
      \ endif |
      \ if empty(<q-args>) || expand('%:p') ==# fnamemodify(<q-args>, ':p') |
      \   set noreadonly |
      \ endif

if exists(':SudoWrite') != 2
command! -bar SudoWrite
      \ call s:SudoSetup(expand('%:p')) |
      \ write!
endif

function! s:SudoEditInit() abort
  let files = split($SUDO_COMMAND, ' ')[1:-1]
  if len(files) ==# argc()
    for i in range(argc())
      execute 'autocmd BufEnter' s:fnameescape(argv(i))
            \ 'if empty(&filetype) || &filetype ==# "conf"'
            \ '|doautocmd filetypedetect BufReadPost' s:fnameescape(files[i])
            \ '|endif'
    endfor
  endif
endfunction
if $SUDO_COMMAND =~# '^sudoedit '
  call s:SudoEditInit()
endif

command! -bar -nargs=? Wall
      \ if empty(<q-args>) |
      \   call s:Wall() |
      \ else |
      \   call system('wall', <q-args>) |
      \ endif
if exists(':W') !=# 2
  command! -bar W Wall
endif
function! s:Wall() abort
  let tab = tabpagenr()
  let win = winnr()
  let seen = {}
  if !&readonly && expand('%') !=# ''
    let seen[bufnr('')] = 1
    write
  endif
  tabdo windo if !&readonly && &buftype =~# '^\%(acwrite\)\=$' && expand('%') !=# '' && !has_key(seen, bufnr('')) | silent write | let seen[bufnr('')] = 1 | endif
  execute 'tabnext '.tab
  execute win.'wincmd w'
endfunction

augroup eunuch
  autocmd!
  autocmd BufNewFile  * let b:brand_new_file = 1
  autocmd BufWritePost * unlet! b:brand_new_file
  autocmd BufWritePre *
        \ if exists('b:brand_new_file') |
        \   if getline(1) =~ '^#!' |
        \     let b:chmod_post = '+x' |
        \   endif |
        \ endif
  autocmd BufWritePost,FileWritePost * nested
        \ if exists('b:chmod_post') && executable('chmod') |
        \   silent! execute '!chmod '.b:chmod_post.' "<afile>"' |
        \   edit |
        \   unlet b:chmod_post |
        \ endif

  autocmd BufNewFile /etc/init.d/*
        \ if filereadable("/etc/init.d/skeleton") |
        \   keepalt read /etc/init.d/skeleton |
        \   1delete_ |
        \ endif |
        \ set ft=sh
augroup END

" vim:set sw=2 sts=2:
