# vim-highlightedundo
Make the undo region apparent!

## Dependency

- Vim 8.1+
- `+reltime`
- `+float`
- `+timers`
- `+job`

If you are using a Vim earlier than 9.1.0071, this plugin needs an external diff command to work.
- `diff` command (https://www.gnu.org/software/diffutils/)

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
