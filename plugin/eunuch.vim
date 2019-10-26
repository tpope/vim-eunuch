" eunuch.vim - Helpers for UNIX
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.2

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

if !exists('s:loaded')
  let s:loaded = {}
endif
function! s:ffn(fn, path) abort
  let ns = tr(matchstr(a:path, '^\a\a\+:'), ':', '#')
  let fn = ns . a:fn
  if len(ns) && !exists('*' . fn) && !has_key(s:loaded, ns) && len(findfile('autoload/' . ns[0:-2] . '.vim', escape(&rtp, ' ')))
    exe 'runtime! autoload/' . ns[0:-2] . '.vim'
    let s:loaded[ns] = 1
  endif
  if len(ns) && exists('*' . fn)
    return fn
  else
    return a:fn
  endif
endfunction

function! s:fcall(fn, path, ...) abort
  return call(s:ffn(a:fn, a:path), [a:path] + a:000)
endfunction

function! EunuchRename(src, dst) abort
  if a:src !~# '^\a\a\+:' && a:dst !~# '^\a\a\+:'
    return rename(a:src, a:dst)
  endif
  try
    let fn = s:ffn('writefile', a:dst)
    let copy = call(fn, [s:fcall('readfile', a:src, 'b'), a:dst])
    if copy == 0
      let delete = s:fcall('delete', a:src)
      if delete == 0
        return 0
      else
        call s:fcall('delete', a:dst)
        return -1
      endif
    endif
  catch
    return -1
  endtry
endfunction

function! s:mkdir_p(path) abort
  let ns = tr(matchstr(a:path, '^\a\a\+:'), ':', '#')
  if !s:fcall('isdirectory', a:path) && s:fcall('filewritable', a:path) !=# 2 && exists('*' . ns . 'mkdir')
    call call(ns . 'mkdir', [a:path, 'p'])
  endif
endfunction

command! -bar -bang Unlink
      \ if <bang>1 && &modified |
      \   edit |
      \ elseif s:fcall('delete', expand('%')) |
      \   echoerr 'Failed to delete "'.expand('%').'"' |
      \ else |
      \   edit! |
      \ endif

command! -bar -bang Remove Unlink<bang>

command! -bar -bang Delete
      \ let s:file = fnamemodify(bufname(<q-args>),':p') |
      \ execute 'bdelete<bang>' |
      \ if !bufloaded(s:file) && s:fcall('delete', s:file) |
      \   echoerr 'Failed to delete "'.s:file.'"' |
      \ endif |
      \ unlet s:file

command! -bar -nargs=1 -bang -complete=file Move
      \ let s:src = expand('%:p') |
      \ let s:dst = expand(<q-args>) |
      \ if s:fcall('isdirectory', s:dst) || s:dst[-1:-1] =~# '[\\/]' |
      \   let s:dst .= (s:dst[-1:-1] =~# '[\\/]' ? '' : s:separator()) .
      \     fnamemodify(s:src, ':t') |
      \ endif |
      \ call s:mkdir_p(fnamemodify(s:dst, ':h')) |
      \ let s:dst = substitute(s:fcall('simplify', s:dst), '^\.\'.s:separator(), '', '') |
      \ if <bang>1 && s:fcall('filereadable', s:dst) |
      \   exe 'keepalt saveas '.s:fnameescape(s:dst) |
      \ elseif EunuchRename(s:src, s:dst) |
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
  call map(files, 'v:val[strlen(prefix) : -1] . (isdirectory(v:val) ? sep : "")')
  return join(files + ['..'.s:separator()], "\n")
endfunction

command! -bar -nargs=1 -bang -complete=custom,s:Rename_complete Rename
      \ Move<bang> %:h/<args>

let s:permlookup = ['---','--x','-w-','-wx','r--','r-x','rw-','rwx']
function! s:Chmod(bang, perm, ...) abort
  let file = a:0 ? expand(join(a:000, ' ')) : @%
  if !a:bang && exists('*setfperm')
    let perm = ''
    if a:perm =~# '^\0*[0-7]\{3\}$'
      let perm = substitute(a:perm[-3:-1], '.', '\=s:permlookup[submatch(0)]', 'g')
    elseif a:perm ==# '+x'
      let perm = substitute(s:fcall('getfperm', file), '\(..\).', '\1x', 'g')
    elseif a:perm ==# '-x'
      let perm = substitute(s:fcall('getfperm', file), '\(..\).', '\1-', 'g')
    endif
    if len(perm) && !s:fcall('setfperm', file, perm)
      return ''
    endif
  endif
  if !executable('chmod')
    return 'echoerr "No chmod command in path"'
  endif
  let out = get(split(system('chmod '.(a:bang ? '-R ' : '').a:perm.' '.shellescape(file)), "\n"), 0, '')
  return len(out) ? 'echoerr ' . string(out) : ''
endfunction

command! -bar -bang -nargs=+ Chmod
      \ exe s:Chmod(<bang>0, <f-args>) |

command! -bar -bang -nargs=? -complete=dir Mkdir
      \ call call(<bang>0 ? 's:mkdir_p' : 'mkdir', [empty(<q-args>) ? expand('%:h') : <q-args>]) |
      \ if empty(<q-args>) |
      \  silent keepalt execute 'file' s:fnameescape(expand('%')) |
      \ endif

command! -bar -bang -complete=file -nargs=+ Cfind   exe s:Grep(<q-bang>, <q-args>, 'find', '')
command! -bar -bang -complete=file -nargs=+ Clocate exe s:Grep(<q-bang>, <q-args>, 'locate', '')
command! -bar -bang -complete=file -nargs=+ Lfind   exe s:Grep(<q-bang>, <q-args>, 'find', 'l')
command! -bar -bang -complete=file -nargs=+ Llocate exe s:Grep(<q-bang>, <q-args>, 'locate', 'l')
function! s:Grep(bang, args, prg, type) abort
  let grepprg = &l:grepprg
  let grepformat = &l:grepformat
  let shellpipe = &shellpipe
  try
    let &l:grepprg = a:prg
    setlocal grepformat=%f
    if &shellpipe ==# '2>&1| tee' || &shellpipe ==# '|& tee'
      let &shellpipe = "| tee"
    endif
    execute a:type.'grep! '.a:args
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
  let local_nvim = has('nvim') && len($DISPLAY . $SECURITYSESSIONID)
  if !has('gui_running') && !local_nvim
    return ['silent', cmd]
  elseif !empty($SUDO_ASKPASS) ||
        \ filereadable('/etc/sudo.conf') &&
        \ len(filter(readfile('/etc/sudo.conf', 50), 'v:val =~# "^Path askpass "'))
    return ['silent', cmd . ' -A']
  else
    return [local_nvim ? 'silent' : '', cmd]
  endif
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

let s:nomodeline = v:version > 703 ? '<nomodeline>' : ''

function! s:SudoReadCmd() abort
  if &shellpipe =~ '|&'
    return 'echoerr ' . string('eunuch.vim: no sudo read support for csh')
  endif
  silent %delete_
  silent exe 'doautocmd' s:nomodeline 'BufReadPre'
  let [silent, cmd] = s:SilentSudoCmd('cat')
  execute silent 'read !' . cmd . ' "%" 2> ' . s:error_file
  let exit_status = v:shell_error
  silent 1delete_
  setlocal nomodified
  if exit_status
    return 'echoerr ' . string(s:SudoError())
  else
    return 'silent doautocmd BufReadPost'
  endif
endfunction

function! s:SudoWriteCmd() abort
  silent exe 'doautocmd' s:nomodeline 'BufWritePre'
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
    return 'silent doautocmd ' . s:nomodeline . ' BufWritePost'
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
  autocmd BufNewFile  * let b:eunuch_new_file = 1
  autocmd BufWritePost * unlet! b:eunuch_new_file
  autocmd BufWritePre *
        \ if exists('b:eunuch_new_file') && getline(1) =~ '^#!\s*/' |
        \   let b:chmod_post = '+x' |
        \ endif
  autocmd BufWritePost,FileWritePost * nested
        \ if exists('b:chmod_post') |
        \   call s:Chmod(0, b:chmod_post, '<afile>') |
        \   edit |
        \   unlet b:chmod_post |
        \ endif
augroup END

" vim:set sw=2 sts=2:
