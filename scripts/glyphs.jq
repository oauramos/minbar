# Simple Icons' simple-icons.json -> "slug<TAB>glyph" lines, the glyph written
# out as UTF-8 (the bar runs on /bin/bash 3.2, whose printf has no \u).
.[] | .slug + "\t" + ([.code | ascii_downcase | explode
  | reduce .[] as $c (0; . * 16 + (if $c >= 97 then $c - 87 else $c - 48 end))]
  | implode)
