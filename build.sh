#!/bin/bash

include_file() {
  f=`echo -n $2 | sed 's/\//\\\\\//g'`
  tmp=`tempfile -p "figitive"`
  cat "$2" | gzip | base64 > "$tmp"
  cat "$1" | sed "/#INCLUDE:$f#/ {
    r $tmp
    d }"
  rm "$tmp"
}

cp install.sh tmp1
i=1
for f in README post-commit.sh post-receive.sh default-files/*; do
  j=$((1 - i))
  include_file tmp$i "$f" > tmp$j
  i=$j
done
cp tmp$j fugitive
chmod +x fugitive
rm tmp0 tmp1
