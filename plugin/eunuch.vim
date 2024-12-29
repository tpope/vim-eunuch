" eunuch.vim - Helpers for UNIX
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.3

if exists('g:loaded_eunuch') || &cp || v:version < 704
  finish
endif
let g:loaded_eunuch = 1

let s:slash_pat = exists('+shellslash') ? '[\/]' : '/'

function! s:separator() abort
  return !exists('+shellslash') || &shellslash ? '/' : '\'
endfunction

function! s:ffn(fn, path) abort
  return get(get(g:, 'io_' . matchstr(a:path, '^\a\a\+\ze:'), {}), a:fn, a:fn)
endfunction

function! s:fcall(fn, path, ...) abort
  return call(s:ffn(a:fn, a:path), [a:path] + a:000)
endfunction

function! s:AbortOnError(cmd) abort
  try
    exe a:cmd
  catch '^Vim(\w\+):E\d'
    return 'return ' . string('echoerr ' . string(matchstr(v:exception, ':\zsE\d.*')))
  endtry
  return ''
endfunction

function! s:MinusOne(...) abort
  return -1
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

function! s:MkdirCallable(name) abort
  let ns = matchstr(a:name, '^\a\a\+\ze:')
  if !s:fcall('isdirectory', a:name) && s:fcall('filewritable', a:name) !=# 2
    if exists('g:io_' . ns . '.mkdir')
      return [g:io_{ns}.mkdir, [a:name, 'p']]
    elseif empty(ns)
      return ['mkdir', [a:name, 'p']]
    endif
  endif
  return ['s:MinusOne', []]
endfunction

function! s:Delete(path) abort
  if has('patch-7.4.1107') && isdirectory(a:path)
    return delete(a:path, 'd')
  else
    return s:fcall('delete', a:path)
  endif
endfunction

command! -bar -bang -nargs=? -complete=dir Mkdir
      \ let s:dst = empty(<q-args>) ? expand('%:h') : <q-args> |
      \ if call('call', s:MkdirCallable(s:dst)) == -1 |
      \   echohl WarningMsg |
      \   echo "Directory already exists: " . s:dst |
      \   echohl NONE |
      \ elseif empty(<q-args>) |
      \    silent keepalt execute 'file' fnameescape(@%) |
      \ endif |
      \ unlet s:dst

function! s:DeleteError(file) abort
  if empty(s:fcall('getftype', a:file))
    return 'Could not find "' . a:file . '" on disk'
  else
    return 'Failed to delete "' . a:file . '"'
  endif
endfunction

command! -bar -bang Unlink
      \ if <bang>1 && &undoreload >= 0 && line('$') >= &undoreload |
      \   echoerr "Buffer too big for 'undoreload' (add ! to override)" |
      \ elseif s:Delete(@%) |
      \   echoerr s:DeleteError(@%) |
      \ else |
      \   edit! |
      \   silent exe 'doautocmd <nomodeline> User FileUnlinkPost' |
      \ endif

command! -bar -bang Remove Unlink<bang>

command! -bar -bang Delete
      \ if <bang>1 && !(line('$') == 1 && empty(getline(1)) || s:fcall('getftype', @%) !=# 'file') |
      \   echoerr "File not empty (add ! to override)" |
      \ else |
      \   let s:file = expand('%:p') |
      \   execute 'bdelete<bang>' |
      \   if !bufloaded(s:file) && s:Delete(s:file) |
      \     echoerr s:DeleteError(s:sfile) |
      \   endif |
      \   unlet s:file |
      \ endif

function! s:FileDest(q_args) abort
  let file = a:q_args
  if file =~# s:slash_pat . '$'
    let file .=  expand('%:t')
  elseif s:fcall('isdirectory', file)
    let file .= s:separator() .  expand('%:t')
  endif
  return substitute(file, '^\.' . s:slash_pat, '', '')
endfunction

command! -bar -nargs=1 -bang -complete=file Copy
      \ let s:dst = s:FileDest(<q-args>) |
      \ call call('call', s:MkdirCallable(fnamemodify(s:dst, ':h'))) |
      \ let s:dst = s:fcall('simplify', s:dst) |
      \ exe expand('<mods>') 'saveas<bang>' fnameescape(remove(s:, 'dst')) |
      \ filetype detect

function! s:Move(bang, arg) abort
  let dst = s:FileDest(a:arg)
  exe s:AbortOnError('call call("call", s:MkdirCallable(' . string(fnamemodify(dst, ':h')) . '))')
  let dst = s:fcall('simplify', dst)
  if !a:bang && s:fcall('filereadable', dst)
    let confirm = &confirm
    try
      if confirm | set noconfirm | endif
      exe s:AbortOnError('keepalt saveas ' . fnameescape(dst))
    finally
      if confirm | set confirm | endif
    endtry
  endif
  if s:fcall('filereadable', @%) && EunuchRename(@%, dst)
    return 'echoerr ' . string('Failed to rename "'.@%.'" to "'.dst.'"')
  else
    let last_bufnr = bufnr('$')
    exe s:AbortOnError('silent keepalt file ' . fnameescape(dst))
    if bufnr('$') != last_bufnr
      exe bufnr('$') . 'bwipe'
    endif
    setlocal modified
    return 'write!|filetype detect'
  endif
endfunction

command! -bar -nargs=1 -bang -complete=file Move exe s:Move(<bang>0, <q-args>)

" ~/f, $VAR/f, %:h/f, #1:h/f, /f, C:/f, url://f
let s:absolute_pat = '^[~$#%]\|^' . s:slash_pat . '\|^\a\+:'

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

command! -bar -nargs=1 -bang -complete=customlist,s:RenameComplete Duplicate
      \ exe 'Copy<bang>' escape(s:RenameArg(<q-args>), '"|')

command! -bar -nargs=1 -bang -complete=customlist,s:RenameComplete Rename
      \ exe 'Move<bang>' escape(s:RenameArg(<q-args>), '"|')

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

function! s:FindPath() abort
  if !has('win32')
    return 'find'
  elseif !exists('s:find_path')
    let s:find_path = 'find'
    for p in split($PATH, ';')
      let prg_path = p ..'/find'
      if p !~? '\<System32\>' && executable(prg_path)
        let s:find_path = prg_path
        break
      endif
    endfor
  endif
  return s:find_path
endf

command! -bang -complete=file -nargs=+ Cfind   exe s:Grep(<q-bang>, <q-args>, s:FindPath(), '')
command! -bang -complete=file -nargs=+ Clocate exe s:Grep(<q-bang>, <q-args>, 'locate', '')
command! -bang -complete=file -nargs=+ Lfind   exe s:Grep(<q-bang>, <q-args>, s:FindPath(), 'l')
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
  if !local_nvim && (!has('gui_running') || &guioptions =~# '!')
    redraw
    echo
    return ['silent', cmd]
  elseif !empty($SUDO_ASKPASS) ||
        \ filereadable('/etc/sudo.conf') &&
        \ len(filter(readfile('/etc/sudo.conf', '', 50), 'v:val =~# "^Path askpass "'))
    return ['silent', cmd . ' -A']
  else
    return [local_nvim ? 'silent' : '', cmd]
  endif
endfunction

augroup eunuch_sudo
augroup END

function! s:SudoSetup(file, resolve_symlink) abort
  let file = a:file
  if a:resolve_symlink && getftype(file) ==# 'link'
    let file = resolve(file)
    if file !=# a:file
      silent keepalt exe 'file' fnameescape(file)
    endif
  endif
  let file = substitute(file, s:slash_pat, '/', 'g')
  if file !~# '^\a\+:\|^/'
    let file = substitute(getcwd(), s:slash_pat, '/', 'g') . '/' . file
  endif
  if !filereadable(file) && !exists('#eunuch_sudo#BufReadCmd#'.fnameescape(file))
    execute 'autocmd eunuch_sudo BufReadCmd ' fnameescape(file) 'exe s:SudoReadCmd()'
  endif
  if !filewritable(file) && !exists('#eunuch_sudo#BufWriteCmd#'.fnameescape(file))
    execute 'autocmd eunuch_sudo BufReadPost' fnameescape(file) 'set noreadonly'
    execute 'autocmd eunuch_sudo BufWriteCmd' fnameescape(file) 'exe s:SudoWriteCmd()'
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
  let [silent, cmd] = s:SilentSudoCmd(shellescape('sh -c cat>"$0"'))
  execute silent 'write !' . cmd . ' "%" 2> ' . s:error_file
  let error = s:SudoError()
  if !empty(error)
    return 'echoerr ' . string(error)
  else
    setlocal nomodified
    return 'silent doautocmd <nomodeline> BufWritePost'
  endif
endfunction

command! -bar -bang -complete=file -nargs=? SudoEdit
      \ let s:arg = resolve(<q-args>) |
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
      \ setlocal noreadonly |
      \ write!
endif

command! -bar Wall call s:Wall()
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

let s:shebang_pat = '^#!\s*[/[:alnum:]_-]'

function! EunuchNewLine(...) abort
  if a:0 && type(a:1) == type('')
    return a:1 . (a:1 =~# "\r" && empty(&buftype) ? "\<C-R>=EunuchNewLine()\r" : "")
  endif
  if !empty(&buftype) || getline(1) !~# '^#!$\|' . s:shebang_pat || line('.') != 2 || getline(2) !~# '^#\=$'
    return ""
  endif
  let b:eunuch_chmod_shebang = 1
  let inject = ''
  let detect = 0
  let ret = empty(getline(2)) ? "" : "\<C-U>"
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
  if get(g:, 'eunuch_no_maps') || rhs =~# 'Eunuch' || get(map, 'desc') =~# 'Eunuch' || get(map, 'buffer')
    return
  endif
  let imap = get(map, 'script', rhs !~? '<plug>') || get(map, 'noremap') ? 'imap <script>' : 'imap'
  if get(map, 'expr') && type(get(map, 'callback')) == type(function('tr'))
    lua local m = vim.fn.maparg('<CR>', 'i', 0, 1); vim.api.nvim_set_keymap('i', '<CR>', m.rhs or '', { expr = true, silent = true, callback = function() return vim.fn.EunuchNewLine(vim.api.nvim_replace_termcodes(m.callback(), true, true, m.replace_keycodes)) end, desc = "EunuchNewLine() wrapped around " .. (m.desc or "Lua function") })
  elseif get(map, 'expr') && !empty(rhs)
    exe imap '<silent><expr> <CR> EunuchNewLine(' . rhs . ')'
  elseif rhs =~? '^\%(<c-\]>\)\=<cr>' || rhs =~# '<[Pp]lug>\w\+CR'
    exe imap '<silent> <CR>' rhs . '<SID>EunuchNewLine'
  elseif empty(rhs)
    imap <script><silent><expr> <CR> EunuchNewLine("<Bslash>035<Bslash>r")
  endif
endfunction
call s:MapCR()

augroup eunuch
  autocmd!
  autocmd BufNewFile  * let b:eunuch_chmod_shebang = 1
  autocmd BufReadPost * if getline(1) !~# '^#!\s*\S' | let b:eunuch_chmod_shebang = 1 | endif
  autocmd BufWritePost,FileWritePost * nested
        \ if exists('b:eunuch_chmod_shebang') && getline(1) =~# s:shebang_pat |
        \   call s:Chmod(0, '+x', '<afile>') |
        \   edit |
        \ endif |
        \ unlet! b:eunuch_chmod_shebang
  autocmd InsertLeave * nested if line('.') == 1 && getline(1) ==# @. && @. =~# s:shebang_pat |
        \ filetype detect | endif
  autocmd User FileChmodPost,FileUnlinkPost "
  autocmd VimEnter * call s:MapCR() |
        \ if has('patch-8.1.1113') || has('nvim-0.4') |
        \   exe 'autocmd eunuch InsertEnter * ++once call s:MapCR()' |
        \ endif
augroup END

" vim:set sw=2 sts=2:
