" eunuch.vim - Helpers for UNIX
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.0

if exists('g:loaded_eunuch') || &cp || v:version < 700
  finish
endif
let g:loaded_eunuch = 1

function! s:separator()
  return !exists('+shellslash') || &shellslash ? '/' : '\\'
endfunction

command! -bar -bang Unlink :
      \ let s:file = fnamemodify(bufname(<q-args>),':p') |
      \ execute 'bdelete<bang>' |
      \ if !bufloaded(s:file) && delete(s:file) |
      \   echoerr 'Failed to delete "'.s:file.'"' |
      \ endif |
      \ unlet s:file

command! -bar -bang Remove :Unlink<bang>

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
      \   exe 'keepalt saveas '.fnameescape(s:dst) |
      \ elseif rename(s:src, s:dst) |
      \   echoerr 'Failed to rename "'.s:src.'" to "'.s:dst.'"' |
      \ else |
      \   setlocal modified |
      \   exe 'keepalt saveas! '.fnameescape(s:dst) |
      \   if s:src !=# expand('%:p') |
      \     execute 'bwipe '.fnameescape(s:src) |
      \   endif |
      \ endif |
      \ unlet s:src |
      \ unlet s:dst

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

command! -bar -bang -complete=file -nargs=+ Find   :call s:Grep(<q-bang>, <q-args>, 'find')
command! -bar -bang -complete=file -nargs=+ Locate :call s:Grep(<q-bang>, <q-args>, 'locate')
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
    execute 'grep'.a:bang.' '.a:args
  finally
    let &l:grepprg = grepprg
    let &l:grepformat = grepformat
    let &shellpipe = shellpipe
  endtry
endfunction

function! s:SudoSetup(file) abort
  if !filereadable(a:file) && !exists('#BufReadCmd#'.fnameescape(a:file))
    execute 'autocmd BufReadCmd ' fnameescape(a:file) 'call s:SudoReadCmd()'
  endif
  if !filewritable(a:file) && !exists('#BufWriteCmd#'.fnameescape(a:file))
    execute 'autocmd BufWriteCmd ' fnameescape(a:file) 'call s:SudoWriteCmd()'
  endif
endfunction

function! s:SudoReadCmd() abort
  silent %delete_
  execute (has('gui_running') ? '' : 'silent') 'read !sudo cat %'
  silent 1delete_
  set nomodified
endfunction

function! s:SudoWriteCmd() abort
  execute (has('gui_running') ? '' : 'silent') 'write !sudo tee % >/dev/null'
  let &modified = v:shell_error
endfunction

command! -bar -bang -complete=file -nargs=? SudoEdit
      \ call s:SudoSetup(fnamemodify(empty(<q-args>) ? expand('%') : <q-args>, ':p')) |
      \ if !&modified || !empty(<q-args>) |
      \   edit<bang> <args> |
      \ endif |
      \ if empty(<q-args>) || expand('%:p') ==# fnamemodify(<q-args>, ':p') |
      \   set noreadonly |
      \ endif

command! -bar SudoWrite
      \ call s:SudoSetup(expand('%:p')) |
      \ write!

command! -bar W :call s:W()
function! s:W() abort
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

augroup shebang_chmod
  autocmd!
  autocmd BufNewFile  * let b:brand_new_file = 1
  autocmd BufWritePost * unlet! b:brand_new_file
  autocmd BufWritePre *
        \ if exists('b:brand_new_file') |
        \   if getline(1) =~ '^#!' |
        \     let b:chmod_post = '+x' |
        \   endif |
        \ endif
  autocmd BufWritePost,FileWritePost *
        \ if exists('b:chmod_post') && executable('chmod') |
        \   silent! execute '!chmod '.b:chmod_post.' "<afile>"' |
        \   edit |
        \   unlet b:chmod_post |
        \ endif
augroup END

" vim:set sw=2 sts=2:
