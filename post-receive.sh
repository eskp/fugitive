#!/bin/sh

cd ..
export GIT_DIR=.git
git reset --hard

refs=`cat - | head -1 | cut -d' ' -f1,2`
ref_begin=`echo $refs | cut -d' ' -f1`
ref_end=`echo $refs | cut -d' ' -f2`

if [ "$ref_begin" = "0000000000000000000000000000000000000000" ]; then
  range="" # first push, empty repos.
else
  range="$ref_begin..$ref_end"
fi

articles_dir=`git config --get fugitive.articles-dir`

added_files=`git log $range --name-status --pretty="format:" | \
  grep -E '^A' | cut -f2 | sort | uniq`
modified_files=`git log $range --name-status --pretty="format:" | \
  grep -E '^M' | cut -f2 | sort | uniq`
deleted_files=`git log $range --name-status --pretty="format:" | \
  grep -E '^D' | cut -f2 | sort | uniq`

tmpart=`mktemp fugitiveXXXXXX`
tmpadd=`mktemp fugitiveXXXXXX`
tmpmod=`mktemp fugitiveXXXXXX`
tmpdel=`mktemp fugitiveXXXXXX`
ls "$articles_dir"/* > "$tmpart"
echo "$added_files" | tr " " "\n" > "$tmpadd"
echo "$modified_files" | tr " " "\n" > "$tmpmod"
echo "$deleted_files" | tr " " "\n" > "$tmpdel"
deleted_files=`comm -23 --nocheck-order "$tmpdel" "$tmpart"`
echo "$deleted_files" | tr " " "\n" > "$tmpdel"
deleted_files=`comm -23 --nocheck-order "$tmpdel" "$tmpadd"`
added_files=`comm -12 --nocheck-order "$tmpadd" "$tmpart"`
echo "$added_files" | tr " " "\n" > "$tmpadd"
modified_files=`comm -23 --nocheck-order "$tmpmod" "$tmpadd"`
rm "$tmpart" "$tmpadd" "$tmpmod" "$tmpdel"
