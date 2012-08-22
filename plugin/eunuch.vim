" eunuch.vim - Helpers for UNIX
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.0

if exists('g:loaded_eunuch') || &cp || v:version < 700
  finish
endif
let g:loaded_eunuch = 1

command! -bar -bang Unlink :
      \ let v:errmsg = '' |
      \ let s:file = fnamemodify(bufname(<q-args>),':p') |
      \ execute 'bdelete<bang>' |
      \ if v:errmsg ==# '' && delete(s:file) |
      \   echoerr 'Failed to delete "'.s:file.'"' |
      \ endif |
      \ unlet s:file

command! -bar -bang Remove :Unlink<bang>

command! -bar -nargs=1 -bang -complete=file Rename :
      \ let s:file = expand('%:p') |
      \ setlocal modified |
      \ keepalt saveas<bang> <args> |
      \ if s:file !=# expand('%:p') |
      \   if delete(s:file) |
      \     echoerr 'Failed to delete "'.s:file.'"' |
      \   else |
      \     execute 'bwipe '.fnameescape(s:file) |
      \   endif |
      \ endif |
      \ unlet s:file

command! -bar -bang -complete=file -nargs=+ Find   :call s:Grep(<q-bang>, <q-args>, 'find')
command! -bar -bang -complete=file -nargs=+ Locate :call s:Grep(<q-bang>, <q-args>, 'locate')
function! s:Grep(bang,args,prg) abort
  let grepprg = &l:grepprg
  let grepformat = &l:grepformat
  try
    let &l:grepprg = a:prg
    setlocal grepformat=%f
    execute 'grep'.a:bang.' '.a:args
  finally
    let &l:grepprg = grepprg
    let &l:grepformat = grepformat
  endtry
endfunction

command! -bar SudoWrite :
      \ setlocal nomodified |
      \ silent exe 'write !sudo tee % >/dev/null' |
      \ let &modified = v:shell_error

command! -bar W :call s:W()
function! s:W() abort
  let tab = tabpagenr()
  let win = winnr()
  let seen = {}
  if !&readonly && expand('%') !=# ''
    let seen[bufnr('')] = 1
    write
  endif
  tabdo windo if !&readonly && expand('%') !=# '' && !has_key(seen, bufnr('')) | silent write | let seen[bufnr('')] = 1 | endif
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
        \   unlet b:chmod_post |
        \ endif
augroup END

" vim:set sw=2 sts=2:
