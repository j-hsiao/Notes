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
The syntax for a link is `[shown text](link)`

Add a `!` in front of the `[]` for the link to display it as an image.
The `shown text` becomes the alt text, shown if image display failed.

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
NOTE codeblock backticks can be indented up to 3 spaces.  Afterwhich something
weird happens and it seems like it is still interpreted as a codeblock
BUT, the backticks also become part of the codeblock (displayed together with the code.)

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

 ```
 1-space
 indentation
 ```

  ```
  2-space
  indentation
  ```

   ```
   3-space
   indentation
   ```

    ```
    4-space
    indentation
    ```

	```
	1-tab
	indentation
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

## Multiline and Nesting
The default github markdown table style does not allow multiple lines
in a single cell of a table nor nested tables.  However, github markdown
does not take effect unless surrounded by empty lines.

NOTE: Inside an HTML table, normal git syntax seems to be uninterpreted.
As a result, codeblocks, etc are not parsed.
```
<br>: linebreak
<table>: table
<tr>: row
<th>: header
<td>: data
```
|header1|table|
|-------|-----|
|table1 | <table><tr><th>nesthead1</th><th>nesthead2</th><th>nesthead3</th></tr> <tr><td>value1 </td><td> value2 </td><td> value3</td></tr> </table> |

<table>
<tr><th>nesthead1</th><th>nesthead2</th><th>nesthead3</th></tr>
<tr><td>value1 </td><td> value2 </td><td>

```
code block must be surrounded
by at least 1 empty line on
either side to be parsed
```


</td></tr> </table>

NOTE: HTML labels can be indented up to 3 spaces.  Using more or using a
tab results in the html tags being un-parsed.


# Extras (github specific?)
## References
use @ and a name to reference to that github user
## Checklists
- [x] checked item
- [ ] unchecked item
  - [x] sub checked item
  - [ ] sub unchecked item

reference issues/pull requests with #, then filter/autocomplete (github only)

