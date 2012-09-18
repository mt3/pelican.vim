" pelican.vim
" Author:  mt3
" URL:     https://github.com/mt3/pelican.vim
" Version: 0.1.0
" License: Same as Vim itself (see :help license)

if exists('g:loaded_pelican') || &cp || v:version < 700
  finish
endif
let g:loaded_pelican = 1

" Config {{{
    " Directories to search for posts
    if ! exists('g:pelican_post_dirs')
      let g:pelican_post_dirs = ['pages']
    endif

    " Extension used when creating new posts
    if ! exists('g:pelican_post_extension')
      let g:pelican_post_extension = '.rst'
    endif

    " Filetype applied to new posts
    if ! exists('g:pelican_post_filetype')
      let g:pelican_post_filetype = 'liquid'
    endif

    " Template for new posts
    if ! exists('g:pelican_post_template')
      let g:pelican_post_template = [
        \ ' ',
        \ ':category: "CATEGORY"',
        \ ':title: "PELICAN_TITLE"',
        \ ':status: draft',
        \ ':date: "PELICAN_DATE"',
        \ ':author: "AUTHOR"',
        \ '']
    endif

    " Directory to place generated files in, relative to b:pelican_root_dir.
    if ! exists('g:pelican_site_dir')
      let g:pelican_site_dir = 'output'
    endif
" }}}

" Utility functions {{{
    " Print an error message
    function! s:error(string)
      echohl ErrorMsg
      echomsg "Error: ".a:string
      echohl None
      let v:errmsg = a:string
    endfunction

    " Substitute first occurrences of pattern in string with replacement
    function! s:sub(string, pattern, replacement)
      return substitute(a:string, '\v\C'.a:pattern, a:replacement, '')
    endfunction

    " Substitute all occurrences of pattern in string with replacement
    function! s:gsub(string, pattern, replacement)
      return substitute(a:string, '\v\C'.a:pattern, a:replacement, 'g')
    endfunction

    " Returns true if string stars with prefix
    function! s:startswith(string, prefix)
      return strpart(a:string, 0, strlen(a:prefix)) ==# a:prefix
    endfunction

    " Format a file path
    function! s:escape_path(path)
      let path = a:path
      let path = s:gsub(path, '/+', '/')
      let path = s:gsub(path, '[\\/]$', '')
      return path
    endfunction

    " Returns a lower-case string, all non-alpha numeric characters are replaced
    " with dashes
    function! s:dasherize(string)
      let string = tolower(a:string)
      let string = s:gsub(string, '([^a-z0-9])+', '-')
      let string = s:gsub(string, '(^-*|-*$)', '')
      return string
    endfunction
" }}}

" Post functions {{{
    " Returns the filename for a new post based on it's title.
    function! s:post_filename(title)
      return b:pelican_post_dir.'/'.strftime('%Y-%m-%d-').s:dasherize(a:title).g:pelican_post_extension
    endfunction

    " Strips whitespace and escapes double quotes
    function! s:post_title(title)
      let title = s:gsub(a:title, '(^[ ]*|[ ]*$)', '')
      let title = s:gsub(title, '[ ]{2,}', ' ')
      let title = s:gsub(title, '"', '\\&')
      return title
    endfunction

    " Used to autocomplete posts
    function! s:post_list(A, L, P)
      let prefix   = b:pelican_post_dir.'/'
      let data     = s:gsub(glob(prefix.'*.*')."\n", prefix, '')
      let data     = s:gsub(data, '\'.g:pelican_post_extension."\n", "\n")
      let files    = reverse(split(data, "\n"))
      let filtered = filter(copy(files), 's:startswith(v:val, a:A)')

      if ! empty(filtered)
        return filtered
      endif
    endfunction

    " Send the given filename to the editor using cmd
    function! s:load_post(cmd, filename)
      let cmd  = empty(a:cmd) ? 'E' : a:cmd
      let cmds = {'E': 'edit', 'S': 'split', 'V': 'vsplit', 'T': 'tabnew'}
      if ! has_key(cmds, cmd)
        return s:error('Invalid command: '. cmd)
      else
        execute cmds[cmd]." ".a:filename
      endif
    endfunction

    " Create a new blog post
    function! s:create_post(cmd, ...)
      let title = a:0 && ! empty(a:1) ? a:1 : input('Post title: ')

      if empty(title)
        return s:error('You must specify a title')
      elseif filereadable(b:pelican_post_dir.'/'.title.g:pelican_post_extension)
        return s:error(title.' already exists!')
      endif

      call s:load_post(a:cmd, s:post_filename(title))
      let error = append(0, g:pelican_post_template)
      if error > 0
        return s:error("Couldn't create post.")
      else
        let &ft = g:pelican_post_filetype
        let date = strftime('%a %b %d %T %z %Y')
        silent! %s/PELICAN_TITLE/\=s:post_title(title)/g
        silent! %s/PELICAN_DATE/\=date/g
      endif
    endfunction

    " Edit a post
    function! s:edit_post(cmd, post)
      let file = b:pelican_post_dir.'/'.a:post.g:pelican_post_extension
      if filereadable(file)
        return s:load_post(a:cmd, file)
      else
        return s:error('File '.file.' does not exist! Try :J'.a:cmd.'post! to create a new post.')
      endif
    endfunction

    " Create/edit a post, used by :Ppost to determine if we're editing or creating a post
    function! s:open_post(create, cmd, ...)
      if a:create
        return s:create_post(a:cmd, a:1)
      else
        return s:edit_post(a:cmd, a:1)
      endif
    endfunction

    " Return the command used to build the blog
    function! s:pelican_bin()
      let bin = 'pelican --autoreload '
      " if filereadable(b:pelican_root_dir.'/Gemfile')
      "   let bin = 'bundle exec '.bin
      " endif
      let bin .= b:pelican_root_dir.' '.b:pelican_root_dir.'/'.g:pelican_site_dir
      return bin
    endfunction

    " Return 'pelican' or 'bundle exec pelican'
    function! s:pelican_build(cmd)
      if exists('g:pelican_build_command') && ! empty(g:pelican_build_command)
        let bin = g:pelican_build_command
      else
        let bin = s:pelican_bin()
      endif
      echo 'Building, this may take a moment'
      let lines = system(bin.' '.a:cmd)
      if v:shell_error != 0
        return s:error('Build failed')
      else
        echo 'Site built!'
      endif
    endfunction

    " Register a new user command
    function! s:define_command(cmd)
      exe 'command! -buffer '.a:cmd
    endfunction
" }}}

" Initialization {{{
    " Register plugin commands
    "
    " :Ppost[!]  - edit in current buffer
    " :PSpost[!] - edit in a split
    " :PVpost[!] - edit in a vertical split
    " :PTpost[!] - edit in a new tab
    function! s:register_commands()
      for cmd in ['', 'S', 'V', 'T']
        call s:define_command('-bang -nargs=? -complete=customlist,s:post_list P'.cmd.'post :call s:open_post(<bang>0, "'.cmd.'", <q-args>)')
      endfor
      call s:define_command('-nargs=* Pbuild call s:pelican_build("<args>")')
    endfunction

    " Try to locate the _posts directory
    function! s:find_pelican(path) abort
      let cur_path = a:path
      let old_path = ""
      while old_path != cur_path
        for dir in g:pelican_post_dirs
          let dir      = s:escape_path(dir)
          if isdirectory(cur_path.'/'.dir)
            return [cur_path, cur_path.'/'.dir]
          endif
        endfor
        let old_path = cur_path
        let cur_path = fnamemodify(old_path, ':h')
      endwhile
      return ['', '']
    endfunction

    " Initialize the plugin if we can detect a Pelican blog
    function! s:init(path)
      let [root_dir, post_dir] = s:find_pelican(a:path)
      if empty(post_dir) || empty(root_dir)
        return
      endif
      let b:pelican_root_dir = root_dir
      let b:pelican_post_dir = post_dir
      silent doautocmd User Pelican
    endfunction

    augroup pelican_commands
      autocmd!
      autocmd User Pelican call s:register_commands()
    augroup END

    augroup pelican_init
      autocmd!
      autocmd BufNewFile,BufReadPost * call s:init(expand('<amatch>:p'))
      autocmd FileType           netrw call s:init(expand('<afile>:p'))
      autocmd VimEnter *
        \ if expand('<amatch>') == '' |
        \   call s:init(getcwd()) |
        \ endif
    augroup END
" }}}

" vim:ft=vim:fdm=marker:ts=4:sw=4:sts=4:et
