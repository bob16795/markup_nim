[back](main.md)

```
body          := `!muplug:` text `\n` [tagDef | `\n`]+
tagDef        := [`{` text `}` | text] `:` tagargs? `\n` [line]+
line          := `\t` cond? command comment? `\n`
comment       := `!` text `\n`
tagargs       := `(` text [`,` text]* `)`
command       := operation [`:` text? [`\n\t\t` text? comment? ] | text?]
operation     := [`SET` |
                  `TAG` |
                  `CODE` ]
cond          := `!`? condoperation text `|`
condoperation := [`EXISTSD` |
                  `EXISTSF` |
                  `EXISTS` |
                  `PROP`]
```
