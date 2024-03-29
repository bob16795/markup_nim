[back](main.md)

```
body        := [propSec | textSec]+
textSec     := [textComment |
                textList |
                codeBlock |
                equ |
                tag |
                textHeading |
                textTable |
                textLine]+ textParEnd
heading2    := `##` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                     `:` | `;` | `<` | `>` | `!` | text | num |
                     `-` | `*` | `$` ]+ `\n`
textParEnd  := `\n`+
textList    := [listLevel3 |
                listLevel2 |
                listLevel1]+
listLevel3  := `\t\t- ` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                         `:` | `;` | `<` | `>` | `!` | text | num |
                         `-` | `*` | `$` ]+ `\n`
listLevel2  := `\t- ` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                       `:` | `;` | `<` | `>` | `!` | text | num |
                       `-` | `*` | `$` ]+ `\n`
listLevel1  := `- ` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                     `:` | `;` | `<` | `>` | `!` | text | num |
                     `-` | `*` | `$` ]+ `\n`
equ         := `$$` [`_` | `*` | `{` | `}` | `!` | `-` | `+` |
                     `;` | `<` | `>` | `(` | `)` | `=` | text |
                     num]+ `$$\n`
tag         := `<` text [`:` text]? `>\n`
textHeading := [heading3 |
                heading2 |
                heading1 ]+
heading3    := `###` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                      `:` | `;` | `<` | `>` | `!` | text | num |
                      `-` | `*` | `$` ]+ `\n`
heading2    := `##` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                     `:` | `;` | `<` | `>` | `!` | text | num |
                     `-` | `*` | `$` ]+ `\n`
heading1    := `#` [`(` | `|` | `)` | `{` | `}` | `_` | `+` |
                    `:` | `;` | `<` | `>` | `!` | text | num |
                    `-` | `*` | `$` ]+ `\n`
comment     := `!` .* [`\n` | EOF]
textLine        := [bold |
                emph |
                text ]+ `\n` 
propSec     := propDiv propLine+ propDiv `\n`*
propDiv     := `---\n`
propLine    := [`!`? text `|`]? text `:` text `\n`
textTable   := tableHeader [tableRow]+
tableHeader := tableRow tableSplit
tableRow    := `|` [text `|`]+
tableSplit  := `|` [`-`+ `|`]+
emphText    := [`_` text `_`] | [`*` text `*`] 
boldText    := [`__` text `__`] | [`**` text `**`] 
codeBlock   := `\`\`\`` text? `\n` [text | `\n`] `\`\`\``
```