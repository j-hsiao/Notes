# Headers are prefixed with a \#.
## Subheaders are prefixed with more \#\# (max of 6 \#s).
(NOTE: space after the \# is required)

# Escaping
Any markdown characters can be escaped with a `\`.
Code (wrapping text in \`) will never be formatted and so any
markdown characters in backticks don't need to be escaped.

# Text Style
**`**bold**`**

*`*italics*`*

~~`~~strikethrough~~`~~

`*` and `_` are interchangeable, so `__` is also bold and `_` is also italics

Newlines must be separated by an extra blank line.
Otherwise they will be concatenated into a single line (with space).
The only exception is a new header.

# links/images:
Syntax for a link is `[shown text](link)`

links can be urls or relative paths to the current md file:
* ./something-in-same-dir-as-this-file or
* ../something-in-parent-dir
* http://someurl.com
* #name-of-header-with-spaces-replaced-with-dash


[google](https://google.com)

![backup text description](https://google.com/favicon.ico)

[link to header](#text-style)

http://plain_text_links_are_auto_linked

# Quotes:
> prefix lines with a "> " to make it quote


# Lists:
1. use N. item for numbered items, N is a number
* use * or - for bullets

sub-items in lists must be indented to below the parent item:
2 spaces if using \* or \-, and N spaces if using digits: 1.
will require 3 spaces but 14. will require 4.

note that the space after the `N. ` or `- ` or `* ` is required.

# Code:
use single backticks for in-line code
use triple backticks for multi-line code (like python strs except backticks)
add the language after the opening triple backticks for syntax highlighting

`some code`
```
some
multiline
code
```
```python
for text in 'hello world'.split():
	print(text)
```

# Tables
use colons to specify alignment:
* :-  = left align
* -:  = right align
* :-: = centered
* -   = default \(items left-aligned, header centered)
header1|header2|header3|header4
:-|-:|:-:|-
item1|item2|item3|item4

# Extras (github specific?)
## References
use @ and a name to reference to that github user
## Checklists
- [x] checked item
- [ ] unchecked item
  - [x] sub checked item
  - [ ] sub unchecked item

reference issues/pull requests with #, then filter/autocomplete (github only)

#
