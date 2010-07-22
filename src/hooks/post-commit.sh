#!/bin/sh

public_dir=`git config --get fugitive.public-dir`
if [ ! -d "$public_dir" ]; then mkdir -p "$public_dir"; fi
templates_dir=`git config --get fugitive.templates-dir`
articles_dir=`git config --get fugitive.articles-dir`

added_files=`git log -1 --name-status --pretty="format:" | grep -E '^A' | \
  cut -f2`
modified_files=`git log -1 --name-status --pretty="format:" | grep -E '^M' | \
  cut -f2`
deleted_files=`git log -1 --name-status --pretty="format:" | grep -E '^D' | \
  cut -f2`

last_published_article=`git log --name-status --pretty="format:" | \
  grep -E '^A' | cut -f2 | grep -E '^$articles_dir' | head -1`

commit_Hash=`git log -1 --format="%H"`
commit_hash=`git log -1 --format="%h"`
commit_author=`git log -1 --format="%an"`
commit_author_email=`git log -1 --format="%ae" | sed "s/@/[at]/;s/\./(dot)/"`
commit_datetime=`git log -1 --format="%ai" | cut -d' ' -f1,2`
commit_date=`git log -1 --format="%ad" --date="short"`
commit_time=`git log -1 --format="%ai" | cut -d' ' -f2`
commit_timestamp=`git log -1 --format="%at"`
commit_subject=`git log -1 --format="%s"`
commit_slug=`git log -1 --format="%f"`
commit_body=`git log -1 --format="%b"`

article_get_title() {
  head -1 "$1"
}
article_get_content() {
  tail -n+2 "$1" > "/tmp/$$"
  (sleep 5 && rm -f "/tmp/$$") &
  echo "/tmp/$$"
}

replace_var_by_string() {
  sed "s/<\!--$1-->/$2/"
}
replace_var_by_file() {
  sed "/<\!--$1-->/ { r $2; d }"
}
replace_commit_info() {
  replace_var_by_string "commit_Hash" "$commit_Hash" | \
    replace_var_by_string "commit_hash" "$commit_hash" | \
    replace_var_by_string "commit_author" "$commit_author" | \
    replace_var_by_string "commit_author_email" "$commit_author_email" | \
    replace_var_by_string "commit_date" "$commit_date" | \
    replace_var_by_string "commit_subject" "$commit_subject" | \
    replace_var_by_string "commit_slug" "$commit_slug" | \
    replace_var_by_string "commit_body" "$commit_body"
}

for f in $deleted_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    rm $public_dir/${f#$articles_dir/}.html
  fi
done

for f in $added_files $modified_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    cat $templates_dir/article.html | \
      replace_commit_info | \
      replace_var_by_string "article_title" "`article_get_title \"$f\"`" | \
      replace_var_by_file "article_content" "`article_get_content \"$f\"`" | \
      cat > $public_dir/${f#$articles_dir/}.html
  fi
done

