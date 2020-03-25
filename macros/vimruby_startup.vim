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

function s:fix_vim_ruby()
ruby << __RUBY__
class << $stdout 
  alias :old_puts :puts
  public def puts(arg="")
  # VIM::evaluate("printf(\"%s\",\"#{arg}\\n\")") 
    old_puts(arg)
  end

  alias :old_print :print
  public def print(arg="")
  #  VIM::evaluate("printf(\"%s\",\"#{arg}\")") 
    old_print(arg)
  end

  public def sync=(*args)

  end

  public def sync(*args)

  end
__RUBY__
end

endfunction

function s:run_minitest()
  ruby << __RUBY__
  require "pathname"
  require "minitest"
  argv = VIM::evaluate("argv()")[0]
  if argv
    load argv
    MiniTest.run
  end
__RUBY__
endfunction

function! s:main() abort
    redir >> /dev/stdout
    call s:run_minitest()
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
