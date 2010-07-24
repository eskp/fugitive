#!/bin/bash

include_file() {
  tmp=`tempfile -p "figitive"`
  cat "$2" | gzip | base64 > "$tmp"
  cat "$1" | sed "/#INCLUDE:$2#/ {
    r $tmp
    d }"
  rm "$tmp"
}

cp install.sh tmp1
i=1
for f in archives.html article.html \
  fugitive.css print.css README \
  post-commit.sh post-receive.sh; do
  j=$((1 - i))
  include_file tmp$i $f > tmp$j
  i=$j
done
cp tmp$j fugitive
chmod +x fugitive
rm tmp0 tmp1
