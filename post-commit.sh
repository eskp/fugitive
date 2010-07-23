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

sanit_mail() {
  sed "s/@/[at]/;s/\./(dot)/"
}

commit_Hash=`git log -1 --format="%H"`
commit_hash=`git log -1 --format="%h"`
commit_author=`git log -1 --format="%an"`
commit_author_email=`git log -1 --format="%ae" | sanit_mail`
commit_datetime=`git log -1 --format="%ai"`
commit_date=`git log -1 --format="%ad" --date="short"`
commit_time=`git log -1 --format="%ai" | cut -d' ' -f2`
commit_timestamp=`git log -1 --format="%at"`
commit_subject=`git log -1 --format="%s"`
commit_slug=`git log -1 --format="%f"`
commit_body() {
  tmp=`tempfile -p "fugitive"`
  git log -1 --format="%b" > "$tmp"
  echo "$tmp"
}

article_info() {
  git log --format="$1" -- "$2"
}
article_title() {
  head -1 "$1"
}
article_content() {
  tmp=`tempfile -p "fugitive"`
  tail -n+2 "$1" > "$tmp"
  echo "$tmp"
}

replace_var_by_string() {
  sed "s/<?fugitive\s\+$1\s*?>/$2/"
}
# REMEMBER: 2nd arg should be a tempfile!
replace_var_by_file() {
  sed "/<?fugitive\s\+$1\s*?>/ {
    r $2
    d }"
  rm "$2"
}
replace_commit_info() {
  replace_var_by_string "commit_Hash" "$commit_Hash" | \
    replace_var_by_string "commit_hash" "$commit_hash" | \
    replace_var_by_string "commit_author" "$commit_author" | \
    replace_var_by_string "commit_author_email" "$commit_author_email" | \
    replace_var_by_string "commit_datetime" "$commit_datetime" | \
    replace_var_by_string "commit_date" "$commit_date" | \
    replace_var_by_string "commit_time" "$commit_time" | \
    replace_var_by_string "commit_timestamp" "$commit_timestamp" | \
    replace_var_by_string "commit_subject" "$commit_subject" | \
    replace_var_by_string "commit_slug" "$commit_slug" | \
    replace_var_by_file "commit_body" "`commit_body`"
}
replace_article_info() {
  cdt=`article_info "%ai" "$1" | tail -1`
  mdt=`article_info "%ai" "$1" | head -1`
  replace_var_by_file "article_content" "`article_content \"$1\"`" | \
    replace_var_by_string "article_title" "`article_title \"$1\"`" | \
    replace_var_by_string "article_cdatetime" "$cdt" | \
    replace_var_by_string "article_cdate" "`echo $cdt | cut -d' ' -f1`" | \
    replace_var_by_string "article_ctime" "`echo $cdt | cut -d' ' -f2`" | \
    replace_var_by_string "article_ctimestamp" \
      "`article_info \"%at\" \"$1\" | tail -1`" | \
    replace_var_by_string "article_mdatetime" "$mdt" | \
    replace_var_by_string "article_mdate" "`echo $mdt | cut -d' ' -f1`" | \
    replace_var_by_string "article_mtime" "`echo $mdt | cut -d' ' -f2`" | \
    replace_var_by_string "article_mtimestamp" \
      "`article_info \"%at\" \"$1\" | head -1`" | \
    replace_var_by_string "article_cauthor" \
      "`article_info \"%an\" \"$1\" | tail -1`" | \
    replace_var_by_string "article_cauthor_email" \
      "`article_info \"%ae\" \"$1\" | tail -1 | sanit_mail`" | \
    replace_var_by_string "article_mauthor" \
      "`article_info \"%an\" \"$1\" | head -1`" | \
    replace_var_by_string "article_mauthor_email" \
      "`article_info \"%ae\" \"$1\" | head -1 | sanit_mail`" | \
    replace_var_by_string "article_url" "$public_dir/${1#$articles_dir/}.html"
}

for f in $deleted_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    echo -n "Deleting $public_dir/${f#$articles_dir/}.html... "
    rm $public_dir/${f#$articles_dir/}.html
    echo "done."
  fi
done

for f in $added_files $modified_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    echo -n "Generating $public_dir/${f#$articles_dir/}.html from $f... "
    cat $templates_dir/article.html | \
      replace_commit_info | \
      replace_article_info "$f" | \
      cat > $public_dir/${f#$articles_dir/}.html
    echo "done."
  fi
done
