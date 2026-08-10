# Drawing sprites without writing code

Any `.txt` file in this folder becomes a PNG in `art/` when you run
`python tools/make_art.py`. A file called `poster.txt` produces
`art/poster.png`.

You draw with characters. One character = one pixel.

```
# name: poster
# palette: . = none, o = #282434, w = #F6F4EC, r = #CE6058, b = #68A0CE
ooooooooooo
owwwwwwwwwo
owwrrrwwwwo
owwrrrwwwwo
owwwwwbbbwo
owwwwwbbbwo
owwwwwwwwwo
ooooooooooo
```

- Lines starting with `#` are settings. Everything after them is the picture.
- `palette:` maps a character to a **hex colour** like `#CE6058`. `none`
  means transparent. (Hex, not `r,g,b`, because entries are separated by
  commas and RGB triples would be chopped in half.)
- `.` is transparent by default, so you rarely need to declare it.
- Every picture row should be the same width. Short rows are padded with
  transparent pixels; a warning is printed so you know.

## Optional settings

```
# outline: #241A12      put a 1px border round the shape (like the other art)
# shadow: yes           add a soft contact shadow at the feet
```

## Why this exists

The rest of the art is plotted by coordinate in Python —
`rect(im, 4, 12, 11, 18, shirt)` — which means drawing anything requires
running the script and looking at the result to find out what you made.
A grid you can see while you type is far quicker, and it means **you can add
art to this game without touching any code.**
