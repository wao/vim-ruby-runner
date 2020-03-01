let s:vimruby_home = expand('<sfile>:h:h')

function! s:append_rtp(path) abort
  if isdirectory(a:path)
    let path = substitute(a:path, '\\\+', '/', 'g')
    let path = substitute(path, '/$', '', 'g')
    let &runtimepath = escape(path, '\,') . ',' . &runtimepath
    let after = path . '/after'
    if isdirectory(after)
      let &runtimepath .= ',' . after
    endif
  endif
endfunction

function! s:start() abort
  let g:vimruby#cmdline = 1
  call s:append_rtp(s:vimruby_home)
  let args = argv()
  if 0 < len(args)
    " Remove arglist for plain environment
    execute '1,' . len(args) . 'argdelete'

    " Delete all the buffers
    for bufnr in range(1, bufnr('$'))
      execute bufnr 'bwipeout!'
    endfor
  endif

  return vimruby#command#start(args)
endfunction

function! s:dump_error(throwpoint, exception) abort
  new
  try
    if $THEMIS_DEBUG == 1 || a:exception =~# '^Vim'
      $ put =repeat('-', 78)
      $ put ='FATAL ERROR: '
      $ put =vimruby#util#callstacklines(a:throwpoint)
      let funcs = matchstr(a:throwpoint, '^function\s*\zs.\+\ze,')
      let f = get(split(funcs, '\.\.'), -1)
      if f
        let data = vimruby#util#funcdata(f)
        $ put =data.signature
        $ put =data.body
      endif
    endif
    $ put ='ERROR: ' . matchstr(a:exception, '^\%(vimruby:\s*\)\?\zs.*')
  finally
    1 delete _
    % print
  endtry
endfunction

function! s:main() abort
    redir >> /dev/stdout
    ruby require "pathname"
    ruby require "minitest"
    ruby argv = VIM::evaluate("argv()")[0]
    ruby load argv if argv
    ruby MiniTest.run if argv
    redir END
    exec "quit"
endfunction

function! s:old_main() abort
  " This :visual is needed for 2 purpose.
  " 1. To Start test in Normal mode.
  " 2. Exit code is set to 1, whenever it ends Vim from Ex mode after an error
  "    output is performed.
  visual

  let error_count = 0
  try
    let error_count = s:start()
  catch
    let error_count = 1
    call s:dump_error(v:throwpoint, v:exception)
  finally
    if mode(1) ==# 'ce'
      visual
    endif
    if error_count == 0
      qall!
    else
      cquit
    endif
  endtry
endfunction

augroup plugin-vimruby-startup
  autocmd!
  autocmd VimEnter * nested call s:main()
augroup END

call s:append_rtp(getcwd())

if v:progname !=# 'gvim'
  " If $DISPLAY is set and the host does not exist,
  " Vim waits for timeout long time.
  " Unset the $DISPLAY to avoid this.
  let $DISPLAY = ''
endif
