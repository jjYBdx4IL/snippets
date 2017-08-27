# vim:set syntax=bash et sw=4:

_vim_summary() {
    cat <<EOF
## .vimrc
    set modelines=20
    set modeline
    syntax on
    set backspace=2
    set shiftwidth=4 tabstop=4 expandtab ai smartindent fileformat=unix fileencoding=utf-8
    " Uncomment the following to have Vim jump to the last position when
    " reopening a file
    if has("autocmd")
          au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
              \| exe "normal! g'\"" | endif
              endif
              nnoremap <F2> :set invpaste paste?<CR>
              set pastetoggle=<F2>
              set showmode
              set number
              " colo slate
              colo elflord

## format header lines:
# vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=perl:
// vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=php:
# vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=sh:

## search and replace:
:%s/host_name.*$/host_name some.host.de/g

## color schemes:
set color scheme with: :colo <name> where name is one of the following files:'
ls /usr/share/vim/vim73/colors/
EOF
}

