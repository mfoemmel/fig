syntax keyword figTodo TODO XXX FIXME NOTE

syntax keyword figKeyword
  \ grammar
  \ archive
  \ resource
  \ retrieve
  \ config
  \ end
  \ override
  \ include
  \ include-file
  \ command
  \ add
  \ append
  \ path
  \ set

syntax match figComment "#.*" contains=figTodo

highlight default link figTodo      Todo
highlight default link figKeyword   Keyword
highlight default link figComment   Comment
