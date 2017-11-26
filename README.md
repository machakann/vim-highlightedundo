# vim-highlightedundo
Make the undo region apparent!

## Dependency

Vim 7.4.1685+ (or, neovim 0.2.0+)

`diff` command (https://www.gnu.org/software/diffutils/) is required to use this plugin.

```vim
" should be 1
:echo executable('diff')
```

## Usage

```vim
nmap u     <Plug>(highlightedundo-undo)
nmap <C-r> <Plug>(highlightedundo-redo)
nmap U     <Plug>(highlightedundo-Undo)
nmap g-    <Plug>(highlightedundo-gminus)
nmap g+    <Plug>(highlightedundo-gplus)
```
