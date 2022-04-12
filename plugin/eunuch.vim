" eunuch.vim - Helpers for UNIX
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.2

if exists('g:loaded_eunuch') || &cp || v:version < 704
  finish
endif
let g:loaded_eunuch = 1

let s:slash_pat = exists('+shellslash') ? '[\/]' : '/'

function! s:separator() abort
  return !exists('+shellslash') || &shellslash ? '/' : '\\'
endfunction

function! s:ffn(fn, path) abort
  return get(get(g:, 'io_' . matchstr(a:path, '^\a\a\+\ze:'), {}), a:fn, a:fn)
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
  if !s:fcall('isdirectory', a:path) && s:fcall('filewritable', a:path) !=# 2
    let ns = matchstr(a:path, '^\a\a\+\ze:')
    if exists('g:io_' . ns . '.mkdir')
      call g:io_{ns}.mkdir(a:path, 'p')
    elseif empty(ns)
      call mkdir(a:path, 'p')
    endif
  endif
endfunction

function! s:Delete(path) abort
  if has('patch-7.4.1107') && isdirectory(a:path)
    return delete(a:path, 'd')
  else
    return s:fcall('delete', a:path)
  endif
endfunction

command! -bar -bang Unlink
      \ if <bang>1 && &modified |
      \   edit |
      \ elseif s:Delete(@%) |
      \   echoerr 'Failed to delete "'.expand('%').'"' |
      \ else |
      \   edit! |
      \   silent exe 'doautocmd <nomodeline> User FileUnlinkPost' |
      \ endif

command! -bar -bang Remove Unlink<bang>

command! -bar -bang Delete
      \ let s:file = fnamemodify(bufname(<q-args>),':p') |
      \ execute 'bdelete<bang>' |
      \ if !bufloaded(s:file) && s:Delete(s:file) |
      \   echoerr 'Failed to delete "'.s:file.'"' |
      \ endif |
      \ unlet s:file

command! -bar -nargs=1 -bang -complete=file Move
      \ let s:src = expand('%:p') |
      \ let s:dst = expand(<q-args>) |
      \ if s:fcall('isdirectory', s:dst) || s:dst[-1:-1] =~# s:slash_pat |
      \   let s:dst .= (s:dst[-1:-1] =~# s:slash_pat ? '' : s:separator()) .
      \     fnamemodify(s:src, ':t') |
      \ endif |
      \ call s:mkdir_p(fnamemodify(s:dst, ':h')) |
      \ let s:dst = substitute(s:fcall('simplify', s:dst), '^\.\'.s:separator(), '', '') |
      \ if <bang>1 && s:fcall('filereadable', s:dst) |
      \   exe 'keepalt saveas' fnameescape(s:dst) |
      \ elseif s:fcall('filereadable', s:src) && EunuchRename(s:src, s:dst) |
      \   echoerr 'Failed to rename "'.s:src.'" to "'.s:dst.'"' |
      \ else |
      \   setlocal modified |
      \   exe 'keepalt saveas!' fnameescape(s:dst) |
      \   if s:src !=# expand('%:p') |
      \     execute 'bwipe' fnameescape(s:src) |
      \   endif |
      \   filetype detect |
      \ endif |
      \ unlet s:src |
      \ unlet s:dst |
      \ filetype detect

" ~/f, $VAR/f, /f, C:/f, url://f, ./f, ../f
let s:absolute_pat = '^[~$]\|^' . s:slash_pat . '\|^\a\+:\|^\.\.\=\%(' . s:slash_pat . '\|$\)'

function! s:RenameComplete(A, L, P) abort
  let sep = s:separator()
  if a:A =~# s:absolute_pat
    let prefix = ''
  else
    let prefix = expand('%:h') . sep
  endif
  let files = split(glob(prefix.a:A.'*'), "\n")
  call map(files, 'fnameescape(strpart(v:val, len(prefix))) . (isdirectory(v:val) ? sep : "")')
  return files
endfunction

function! s:RenameArg(arg) abort
  if a:arg =~# s:absolute_pat
    return a:arg
  else
    return '%:h/' . a:arg
  endif
endfunction

command! -bar -nargs=1 -bang -complete=customlist,s:RenameComplete Rename
      \ exe 'Move<bang>' escape(s:RenameArg(<q-args>), '"|')

command! -bar -nargs=1 -bang -complete=custom,s:RenameComplete Duplicate
      \ let s:src = expand('%:p') |
      \ let s:dst = expand(escape(s:RenameArg(<q-args>, '"|'))) |
      \ if s:fcall('isdirectory', s:dst) || s:dst[-1:-1] =~# '[\\/]' |
      \   let s:dst .= (s:dst[-1:-1] =~# '[\\/]' ? '' : s:separator()) .
      \     fnamemodify(s:src, ':t') |
      \ endif |
      \ call s:mkdir_p(fnamemodify(s:dst, ':h')) |
      \ let s:dst = substitute(s:fcall('simplify', s:dst), '^\.\'.s:separator(), '', '') |
      \ execute 'keepalt saveas<bang> '.s:fnameescape(s:dst) |
      \ unlet s:src |
      \ unlet s:dst |
      \ filetype detect

let s:permlookup = ['---','--x','-w-','-wx','r--','r-x','rw-','rwx']
function! s:Chmod(bang, perm, ...) abort
  let autocmd = 'silent doautocmd <nomodeline> User FileChmodPost'
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
    if len(perm) && file =~# '^\a\a\+:' && !s:fcall('setfperm', file, perm)
      return autocmd
    endif
  endif
  if !executable('chmod')
    return 'echoerr "No chmod command in path"'
  endif
  let out = get(split(system('chmod '.(a:bang ? '-R ' : '').a:perm.' '.shellescape(file)), "\n"), 0, '')
  return len(out) ? 'echoerr ' . string(out) : autocmd
endfunction

command! -bar -bang -nargs=+ Chmod
      \ exe s:Chmod(<bang>0, <f-args>)

command! -bar -bang -nargs=? -complete=dir Mkdir
      \ call call(<bang>0 ? 's:mkdir_p' : 'mkdir', [empty(<q-args>) ? expand('%:h') : <q-args>]) |
      \ if empty(<q-args>) |
      \  silent keepalt execute 'file' fnameescape(expand('%')) |
      \ endif

command! -bang -complete=file -nargs=+ Cfind   exe s:Grep(<q-bang>, <q-args>, 'find', '')
command! -bang -complete=file -nargs=+ Clocate exe s:Grep(<q-bang>, <q-args>, 'locate', '')
command! -bang -complete=file -nargs=+ Lfind   exe s:Grep(<q-bang>, <q-args>, 'find', 'l')
command! -bang -complete=file -nargs=+ Llocate exe s:Grep(<q-bang>, <q-args>, 'locate', 'l')
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
  let local_nvim = has('nvim') && len($DISPLAY . $SECURITYSESSIONID . $TERM_PROGRAM)
  if !has('gui_running') && !local_nvim
    return ['silent', cmd]
  elseif !empty($SUDO_ASKPASS) ||
        \ filereadable('/etc/sudo.conf') &&
        \ len(filter(readfile('/etc/sudo.conf', '', 50), 'v:val =~# "^Path askpass "'))
    return ['silent', cmd . ' -A']
  else
    return [local_nvim ? 'silent' : '', cmd]
  endif
endfunction

function! s:SudoSetup(file, resolve_symlink) abort
  let file = a:file
  if a:resolve_symlink && getftype(file) ==# 'link'
    let file = resolve(file)
    if file !=# a:file
      silent keepalt exe 'file' fnameescape(file)
    endif
  endif
  if !filereadable(file) && !exists('#BufReadCmd#'.fnameescape(file))
    execute 'autocmd BufReadCmd ' fnameescape(a:file) 'exe s:SudoReadCmd()'
  endif
  if !filewritable(file) && !exists('#BufWriteCmd#'.fnameescape(file))
    execute 'autocmd BufReadPost ' fnameescape(file) 'set noreadonly'
    execute 'autocmd BufWriteCmd ' fnameescape(file) 'exe s:SudoWriteCmd()'
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

function! s:SudoReadCmd(bang) abort
  if &shellpipe =~ '|&'
    return 'echoerr ' . string('eunuch.vim: no sudo read support for csh')
  endif
  silent %delete_
  silent doautocmd <nomodeline> BufReadPre
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
  silent doautocmd <nomodeline> BufWritePre
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
    return 'silent doautocmd <nomodeline> BufWritePost'
  endif
endfunction

command! -bar -bang -complete=file -nargs=? SudoEdit
      \ let s:arg = resolve(expand(<q-args>)) |
      \ call s:SudoSetup(fnamemodify(empty(s:arg) ? @% : s:arg, ':p'), empty(s:arg) && <bang>0) |
      \ if !&modified || !empty(s:arg) || <bang>0 |
      \   exe 'edit<bang>' fnameescape(s:arg) |
      \ endif |
      \ if empty(<q-args>) || expand('%:p') ==# fnamemodify(s:arg, ':p') |
      \   set noreadonly |
      \ endif |
      \ unlet s:arg

if exists(':SudoWrite') != 2
command! -bar -bang SudoWrite
      \ call s:SudoSetup(expand('%:p'), <bang>0) |
      \ write!
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
  if !&readonly && &buftype =~# '^\%(acwrite\)\=$' && expand('%') !=# ''
    let seen[bufnr('')] = 1
    write
  endif
  tabdo windo if !&readonly && &buftype =~# '^\%(acwrite\)\=$' && expand('%') !=# '' && !has_key(seen, bufnr('')) | silent write | let seen[bufnr('')] = 1 | endif
  execute 'tabnext '.tab
  execute win.'wincmd w'
endfunction

" Adapted from autoload/dist/script.vim.
let s:interpreters = {
      \ '.': '/bin/sh',
      \ 'sh': '/bin/sh',
      \ 'bash': 'bash',
      \ 'csh': 'csh',
      \ 'tcsh': 'tcsh',
      \ 'zsh': 'zsh',
      \ 'tcl': 'tclsh',
      \ 'expect': 'expect',
      \ 'gnuplot': 'gnuplot',
      \ 'make': 'make -f',
      \ 'pike': 'pike',
      \ 'lua': 'lua',
      \ 'perl': 'perl',
      \ 'php': 'php',
      \ 'python': 'python3',
      \ 'groovy': 'groovy',
      \ 'raku': 'raku',
      \ 'ruby': 'ruby',
      \ 'javascript': 'node',
      \ 'bc': 'bc',
      \ 'sed': 'sed',
      \ 'ocaml': 'ocaml',
      \ 'awk': 'awk',
      \ 'wml': 'wml',
      \ 'scheme': 'scheme',
      \ 'cfengine': 'cfengine',
      \ 'erlang': 'escript',
      \ 'haskell': 'haskell',
      \ 'scala': 'scala',
      \ 'clojure': 'clojure',
      \ 'pascal': 'instantfpc',
      \ 'fennel': 'fennel',
      \ 'routeros': 'rsc',
      \ 'fish': 'fish',
      \ 'forth': 'gforth',
      \ }

function! s:NormalizeInterpreter(str) abort
  if empty(a:str) || a:str =~# '^[ /]'
    return a:str
  elseif a:str =~# '[ \''"#]'
    return '/usr/bin/env -S ' . a:str
  else
    return '/usr/bin/env ' . a:str
  endif
endfunction

function! s:FileTypeInterpreter() abort
  try
    let ft = get(split(&filetype, '\.'), 0, '.')
    let configured = get(g:, 'eunuch_interpreters', {})
    if type(get(configured, ft)) == type(function('tr'))
      return call(configured[ft], [])
    elseif get(configured, ft) is# 1 || get(configured, ft) is# get(v:, 'true', 1)
      return ft ==# '.' ? s:interpreters['.'] : '/usr/bin/env ' . ft
    elseif empty(get(configured, ft, 1))
      return ''
    elseif type(get(configured, ft)) == type('')
      return s:NormalizeInterpreter(get(configured, ft))
    endif
    return s:NormalizeInterpreter(get(s:interpreters, ft, ''))
  endtry
endfunction

function! EunuchNewLine(...) abort
  if a:0 && type(a:1) == type('')
    return a:1 . (a:1 =~# "\r" ? "\<C-R>=EunuchNewLine()\r" : "")
  endif
  if !empty(&buftype) || getline(1) !~# '^#!' || line('.') != 2 || getline(2) !~# '^#\=$'
    return ""
  endif
  let b:eunuch_chmod_shebang = 1
  let inject = ''
  let detect = 0
  let ret = empty(getline(2)) ? "" : "\<BS>"
  if getline(1) ==# '#!'
    let inject = s:FileTypeInterpreter()
    let detect = !empty(inject) && empty(&filetype)
  else
    filetype detect
    if getline(1) =~# '^#![^ /].\{-\}[ \''"#]'
      let inject = '/usr/bin/env -S '
    elseif getline(1) =~# '^#![^ /]'
      let inject = '/usr/bin/env '
    endif
  endif
  if len(inject)
    let ret .= "\<Up>\<Right>\<Right>" . inject . "\<Home>\<Down>"
  endif
  if detect
    let ret .= "\<C-\>\<C-O>:filetype detect\r"
  endif
  return ret
endfunction

function! s:MapCR() abort
  imap <silent><script> <SID>EunuchNewLine <C-R>=EunuchNewLine()<CR>
  let map = maparg('<CR>', 'i', 0, 1)
  let rhs = substitute(get(map, 'rhs', ''), '\c<sid>', '<SNR>' . get(map, 'sid') . '_', 'g')
  if get(g:, 'eunuch_no_maps') || rhs =~# 'Eunuch' || get(map, 'buffer')
    return
  endif
  if get(map, 'expr')
    exe 'imap <script><silent><expr> <CR> EunuchNewLine(' . rhs . ')'
  elseif rhs =~? '^<cr>' && rhs !~? '<plug>'
    exe 'imap <silent><script> <CR>' rhs . '<SID>EunuchNewLine'
  elseif rhs =~? '^<cr>'
    exe 'imap <silent> <CR>' rhs . '<SID>EunuchNewLine'
  elseif empty(rhs)
    imap <script><silent> <CR> <CR><SID>EunuchNewLine
  endif
endfunction
call s:MapCR()

augroup eunuch
  autocmd!
  autocmd BufNewFile  * let b:eunuch_chmod_shebang = 1
  autocmd BufReadPost * if getline(1) !~# '^#!\s*\S' | let b:eunuch_chmod_shebang = 1 | endif
  autocmd BufWritePost,FileWritePost * nested
        \ if exists('b:eunuch_chmod_shebang') && getline(1) =~# '^#!\s*\S' |
        \   call s:Chmod(0, '+x', '<afile>') |
        \   edit |
        \ endif |
        \ unlet! b:eunuch_chmod_shebang
  autocmd InsertLeave * nested if line('.') == 1 && getline(1) ==# @. && @. =~# '^#!\s*\S' |
        \ filetype detect | endif
  autocmd User FileChmodPost,FileUnlinkPost "
  autocmd VimEnter * call s:MapCR()
augroup END

" vim:set sw=2 sts=2:
