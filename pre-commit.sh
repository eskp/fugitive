#!/bin/sh

articles_dir=`git config --get fugitive.articles-dir`

article_exists=`mktemp`
for f in "$articles_dir"/*; do
  ts=`git log --format="%at" -- "$f" | tail -1`
  if [ "$ts" != "" ]; then
    echo "1"
    break
  fi
done > "$article_exists"
article_exists=`cat $article_exists`
non_tracked=`git status --porcelain | grep -E '^(A|R)' | grep "$articles_dir"`

if [ "$article_exists" = "" -a "$non_tracked" = "" ]; then
  echo -n "[fugitive] ERROR: need at least one article (you can use " >&2
  echo '`git commit --no-verify` to bypass), aborting.' >&2
  exit 1
fi
