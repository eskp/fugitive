#!/bin/sh

public_dir=`git config --get fugitive.public-dir`
if [ ! -d "$public_dir" ]; then mkdir -p "$public_dir"; fi
templates_dir=`git config --get fugitive.templates-dir`
articles_dir=`git config --get fugitive.articles-dir`
preproc=`git config --get fugitive.preproc`

added_files=`git log -1 --name-status --pretty="format:" | grep -E '^A' | \
  cut -f2`
modified_files=`git log -1 --name-status --pretty="format:" | grep -E '^M' | \
  cut -f2`
deleted_files=`git log -1 --name-status --pretty="format:" | grep -E '^D' | \
  cut -f2`

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
get_commit_body() {
  tmp=`tempfile -p "fugitive"`
  git log -1 --format="%b" > "$tmp"
  echo "$tmp"
}

articles_sorted=`tempfile -p "fugitive"`
for f in $articles_dir/*; do
  ts=`git log --format="%at" -- "$f" | tail -1`
  if [ "$ts" != "" ]; then
    echo "$ts ${f#$articles_dir/}"
  fi
done | sort -nr | cut -d' ' -f2 > "$articles_sorted"

get_article_info() {
  git log --format="$1" -- "$articles_dir/$2"
}
get_article_previous_file() {
  previous=`grep -A1 "$1" "$articles_sorted" | tail -1`
  if [ "$previous" != "$1" ]; then
    echo "$previous"
  fi
}
get_article_next_file() {
  next=`grep -B1 "$1" "$articles_sorted" | head -1`
  if [ "$next" != "$1" ]; then
    echo "$next"
  fi
}
get_article_title() {
  if [ "$1" != "" ]; then
    head -1 "$articles_dir/$1"
  fi
}
get_article_content() {
  tmp=`tempfile -p "fugitive"`
  tail -n+2 "$articles_dir/$1" > "$tmp"
  echo "$tmp"
}

replace_condition() {
  if [ "$2" = "" ]; then
    sed "s/<?fugitive\s\+\(end\)\?ifset:$1\s*?>/\n\0\n/g" | \
      sed "/<?fugitive\s\+ifset:$1\s*?>/,/<?fugitive\s\+endifset:$1\s*?>/bdel
        b
        :del
        s/<?fugitive\s\+endifset:$1\s*?>.*//
        /<?fugitive\s\+endifset:$1\s*?>/b
        d"
  else
    sed "s/<?fugitive\s\+\(end\)\?ifset:$1\s*?>//"
  fi
}

replace_str() {
  replace_condition "$1" "$2" | \
    sed "s/<?fugitive\s\+$1\s*?>/$2/"
}

# REMEMBER: 2nd arg should be a tempfile!
replace_file() {
  sed "/<?fugitive\s\+$1\s*?>/ {
    r $2
    d }"
  rm "$2"
}

replace_includes() {
  cat
}

replace_commit_info() {
  commit_body=`get_commit_body`
  replace_str "commit_Hash" "$commit_Hash" | \
    replace_str "commit_hash" "$commit_hash" | \
    replace_str "commit_author" "$commit_author" | \
    replace_str "commit_author_email" "$commit_author_email" | \
    replace_str "commit_datetime" "$commit_datetime" | \
    replace_str "commit_date" "$commit_date" | \
    replace_str "commit_time" "$commit_time" | \
    replace_str "commit_timestamp" "$commit_timestamp" | \
    replace_str "commit_subject" "$commit_subject" | \
    replace_str "commit_slug" "$commit_slug" | \
    replace_file "commit_body" "$commit_body"
}

replace_article_info() {
  article_title=`get_article_title "$1"`
  article_cdatetime=`get_article_info "%ai" "$1" | tail -1`
  article_cdate=`echo "$article_cdatetime" | cut -d' ' -f1`
  article_ctime=`echo "$article_cdatetime" | cut -d' ' -f2`
  article_ctimestamp=`get_article_info "%at" "$1" | tail -1`
  u=`get_article_info "%ai" "$1" | wc -l`
  article_mdatetime=`if test "$u" -gt 1; then get_article_info "%ai" "$1" | \
    head -1; fi`
  article_mdate=`echo "$article_mdatetime" | cut -d' ' -f1`
  article_mtime=`echo "$article_mdatetime" | cut -d' ' -f2`
  article_mtimestamp=`if test "$u" -gt 1; then get_article_info "%at" \
    "$1" | head -1; fi`
  article_cauthor=`get_article_info "%an" "$1" | tail -1`
  article_cauthor_email=`get_article_info "%ae" "$1" | tail -1 | sanit_mail`
  article_mauthor=`get_article_info "%an" "$1" | head -1`
  article_mauthor_email=`get_article_info "%ae" "$1" | head -1 | sanit_mail`
  article_previous_file=`get_article_previous_file "$1"`
  article_previous_title=`get_article_title "$article_previous_file"`
  article_next_file=`get_article_next_file "$1"`
  article_next_title=`get_article_title "$article_next_file"`
  
  replace_str "article_file" "$1" | \
    replace_str "article_title" "$article_title" | \
    replace_str "article_cdatetime" "$article_cdatetime" | \
    replace_str "article_cdate" "$article_cdate" | \
    replace_str "article_ctime" "$article_ctime" | \
    replace_str "article_ctimestamp" "$article_ctimestamp" | \
    replace_str "article_mdatetime" "$article_mdatetime" | \
    replace_str "article_mdate" "$article_mdate" | \
    replace_str "article_mtime" "$article_mtime" | \
    replace_str "article_mtimestamp" "$article_mtimestamp" | \
    replace_str "article_cauthor" "$article_cauthor" | \
    replace_str "article_cauthor_email" "$article_cauthor_email" | \
    replace_str "article_mauthor" "$article_mauthor" | \
    replace_str "article_mauthor_email" "$article_mauthor_email" | \
    replace_str "article_previous_file" "$article_previous_file" | \
    replace_str "article_previous_title" "$article_previous_title" | \
    replace_str "article_next_file" "$article_next_file" | \
    replace_str "article_next_title" "$article_next_title"
}

replace_foreach_article() {
  foreach_body=`tempfile -p "feb"`
  tmpfile=`tempfile -p "tfil"`
  temp=`tempfile -p "tmp"`
  fa="foreach:article"
  cat > "$temp"
  cat "$temp" | \
  sed "s/<?fugitive\s\+$fa\s*?>/<?fugitive foreach_body ?>\n\0/" | \
    sed "/<?fugitive\s\+$fa\s*?>/,/<?fugitive\s\+end$fa\s*?>/d" | \
    cat > "$tmpfile"
  cat "$temp" | \
    sed -n "/<?fugitive\s\+$fa\s*?>/,/<?fugitive\s\+end$fa\s*?>/p" | \
    tail -n +2 | head -n -1 > "$foreach_body"
  for a in `cat $articles_sorted`; do
    cat "$foreach_body" | replace_article_info "$a"
  done > "$temp"
  cat "$tmpfile" | replace_file "foreach_body" "$temp"
  rm "$foreach_body" "$tmpfile"
}

modification=0

for f in $deleted_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    modification=$((modification + 1))
    art="${f#$articles_dir/}"
    echo -n "[fugitive] Deleting $public_dir/$art.html... "
    rm "$public_dir/$art.html"
    echo "done."
    echo -n "[fugitive] Removing $art.html from git ignore list... "
    sed -i "/^$art.html$/d" .git/info/exclude
    echo "done."
  fi
done

new=$RANDOM.$$
for f in $added_files $new $modified_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    modification=$((modification + 1))
    if [ "$preproc" != "" ]; then
      preproc_bak=`tempfile -p "fugitive" -d "$articles_dir"`
      mv "$f" "$preproc_bak"
      ($preproc) < "$preproc_bak" > "$f"
    fi
    art="${f#$articles_dir/}"
    echo -n "[fugitive] Generating $public_dir/$art.html from $f... "
    cat "$templates_dir/article.html" | \
      replace_file "article_content" "`get_article_content \"$art\"`" | \
      replace_includes | \
      replace_commit_info | \
      replace_article_info "$art" | \
      sed "/^\s*$/d" > "$public_dir/$art.html"
    echo "done."
    if [ "$new" != "" ]; then
      echo -n "[fugitive] Adding $art.html to git ignore list... "
      echo "$art.html" >> .git/info/exclude
      echo "done."
    fi
    if [ "$preproc" != "" ]; then mv "$preproc_bak" "$f"; fi
  fi
  if [ "$f" = "$new" ]; then new=""; fi
done

if [ $modification -gt 0 ]; then
  echo -n "[fugitive] Generating $public_dir/archives.html... "
  cat "$templates_dir/archives.html" | \
    replace_includes | \
    replace_foreach_article | \
    replace_commit_info | \
    sed "/^\s*$/d" > "$public_dir/archives.html"
  echo "done."
  
  echo -n "[fugitive] Using last published article as index page... "
  cp "$public_dir/`head -1 $articles_sorted`.html" "$public_dir/index.html"
  echo "done".
  echo "[fugitive] Blog update complete."
fi
rm "$articles_sorted"
