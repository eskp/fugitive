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
generated_files=`tempfile -p "fugitive"`

sanit_mail() {
  sed "s/@/[at]/;s/\./(dot)/"
}

articles_sorted=`tempfile -p "fugitive"`
for f in $articles_dir/*; do
  ts=`git log --format="%at" -- "$f" | tail -1`
  if [ "$ts" != "" ]; then
    echo "$ts ${f#$articles_dir/}"
  fi
done | sort -nr | cut -d' ' -f2 > "$articles_sorted"

articles_sorted_with_delete=`tempfile -p "fugitive"`
for f in $articles_dir/* $deleted_files; do
  ts=`git log --format="%at" -- "$f" | tail -1`
  if [ "$ts" != "" ]; then
    echo "$ts ${f#$articles_dir/}"
  fi
done | sort -nr | cut -d' ' -f2 > "$articles_sorted_with_delete"

commits=`tempfile -p "fugitive"`
git log --oneline | cut -d' ' -f1 > "$commits"

get_article_info() {
  git log --format="$1" -- "$articles_dir/$2"
}
get_article_next_file() {
  next=`grep -B1 "$1" "$articles_sorted" | head -1`
  if [ "$next" != "$1" ]; then
    echo "$next"
  fi
}
get_article_previous_file() {
  previous=`grep -A1 "$1" "$articles_sorted" | tail -1`
  if [ "$previous" != "$1" ]; then
    echo "$previous"
  fi
}
get_deleted_next_file() {
  next=`grep -B1 "$1" "$articles_sorted_with_delete" | head -1`
  if [ "`echo $deleted_files | grep -c \"$next\"`" = "0" ]; then
    echo "$next"
  fi
}
get_deleted_previous_file() {
  previous=`grep -A1 "$1" "$articles_sorted_with_delete" | tail -1`
  if [ "`echo $deleted_files | grep -c \"$previous\"`" = "0" ]; then
    echo "$previous"
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

get_commit_info() {
  git show --quiet --format="$1" "$2"
}
get_commit_body() {
  tmp=`tempfile -p "fugitive"`
  git show --quiet --format="%b" "$1" > "$tmp"
  if [ "`cat \"$tmp\" | sed \"/^$/d\" | wc -l`" != "0" ]; then
    echo "$tmp"
  fi
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
  esc=`echo $2 | sed 's/\//\\\\\//g'`
  replace_condition "$1" "$2" | \
    sed "s/<?fugitive\s\+$1\s*?>/$esc/g"
}

# REMEMBER: 2nd arg should be a tempfile!
replace_file() {
  if [ -f "$2" ]; then
    sed "s/<?fugitive\s\+$1\s*?>/\n\0\n/g" | \
      sed "/<?fugitive\s\+$1\s*?>/ {
        r $2
        d }"
    rm "$2"
  else
    cat
  fi
}

replace_includes() {
  buf=`tempfile -p "fugitive"`
  buf2=`tempfile -p "fugitive"`
  cat > "$buf"
  includes=`cat "$buf" | \
    sed "s/<?fugitive\s\+include:.\+\s*?>/\n\0\n/g" | \
    grep -E "<\?fugitive\s+include:.+\s*\?>" | \
    sed "s/^<?fugitive\s\+include://;s/\s*?>$//"`
  for i in $includes; do
    esc=`echo -n $i | sed 's/\//\\\\\//g'`
    inc="$templates_dir/$i"
    cat "$buf" | \
      sed "/<?fugitive\s\+include:$esc\s*?>/ {
        r $inc
        d }" > "$buf2"
    tmpbuf="$buf"
    buf="$buf2"
    buf2="$tmpbuf"
  done
  cat "$buf"
  rm "$buf" "$buf2"
}

replace_commit_info() {
  commit_Hash=`get_commit_info "%H" "$1"`
  commit_hash=`get_commit_info "%h" "$1"`
  commit_author=`get_commit_info "%an" "$1"`
  commit_author_email=`get_commit_info "%ae" "$1" | sanit_mail`
  commit_datetime=`get_commit_info "%ai" "$1"`
  commit_date=`echo $commit_datetime | cut -d' ' -f1`
  commit_time=`echo $commit_datetime | cut -d' ' -f2`
  commit_timestamp=`get_commit_info "%at" "$1"`
  commit_subject=`get_commit_info "%s" "$1"`
  commit_slug=`get_commit_info "%f" "$1"`
  commit_body=`get_commit_body "$1"`
  
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

replace_empty_article_info() {
  replace_str "article_file" "" | \
    replace_str "article_title" "" | \
    replace_str "article_cdatetime" "" | \
    replace_str "article_cdate" "" | \
    replace_str "article_ctime" "" | \
    replace_str "article_ctimestamp" "" | \
    replace_str "article_mdatetime" "" | \
    replace_str "article_mdate" "" | \
    replace_str "article_mtime" "" | \
    replace_str "article_mtimestamp" "" | \
    replace_str "article_cauthor" "" | \
    replace_str "article_cauthor_email" "" | \
    replace_str "article_mauthor" "" | \
    replace_str "article_mauthor_email" "" | \
    replace_str "article_previous_file" "" | \
    replace_str "article_previous_title" "" | \
    replace_str "article_next_file" "" | \
    replace_str "article_next_title" ""
}

replace_foreach () {
  foreach_body=`tempfile -p "fugitive"`
  tmpfile=`tempfile -p "fugitive"`
  temp=`tempfile -p "fugitive"`
  fe="foreach:$1"
  cat > "$temp"
  cat "$temp" | \
    sed -n "/<?fugitive\s\+$fe\s*?>/,/<?fugitive\s\+end$fe\s*?>/p" | \
    tail -n +2 | head -n -1 > "$foreach_body"
  if [ ! -s "$foreach_body" ]; then
    cat "$temp"
    rm "$foreach_body" "$tmpfile" "$temp"
    return
  fi
  cat "$temp" | \
  sed "s/<?fugitive\s\+$fe\s*?>/<?fugitive foreach_body ?>\n\0/" | \
    sed "/<?fugitive\s\+$fe\s*?>/,/<?fugitive\s\+end$fe\s*?>/d" | \
    cat > "$tmpfile"
  for i in `cat "$2"`; do
    cat "$foreach_body" | replace_$1_info "$i"
  done > "$temp"
  cat "$tmpfile" | replace_file "foreach_body" "$temp"
  rm "$foreach_body" "$tmpfile"
}

generate_static() {
  if [ "$preproc" != "" ]; then
    preproc_bak=`tempfile -p "fugitive" -d "$articles_dir"`
    mv "$1" "$preproc_bak"
    ($preproc) < "$preproc_bak" > "$1"
  fi
  art="${1#$articles_dir/}"
  cat "$templates_dir/article.html" | \
    replace_file "article_content" "`get_article_content \"$art\"`" | \
    replace_includes | \
    replace_commit_info "-1" | \
    replace_article_info "$art" | \
    sed "/^\s*$/d" > "$public_dir/$art.html"
  if [ "$preproc" != "" ]; then mv "$preproc_bak" "$1"; fi
}

regenerate_previous_and_next_file_maybe() {
  if [ "$1" != "" -a \
       "`grep -c \"$1\" \"$generated_files\"`" = "0" ]; then
    echo -n "[fugitive] Regenerating $public_dir/$1.html"
    echo -n " (as previous article) from $articles_dir/$1... "
    generate_static "$articles_dir/$1"
    echo "done."
    echo "$1" >> "$generated_files"
  fi
  if [ "$2" != "" -a \
       "`grep -c \"$2\" \"$generated_files\"`" = "0" ]; then
    echo -n "[fugitive] Regenerating $public_dir/$2.html"
    echo -n " (as next article) from $articles_dir/$2... "
    generate_static "$articles_dir/$2"
    echo "done."
    echo "$2" >> "$generated_files"
  fi
}

modification=0

for f in $added_files $modified_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    modification=$((modification + 1))
    echo -n "[fugitive] Generating $public_dir/${f#$articles_dir/}.html from"
    echo -n " $f... "
    generate_static "$f"
    echo "done."
    echo "${f#$articles_dir/}" >> "$generated_files"
  fi
done

for f in $added_files; do
  if [ "$f" != "${f#$articles_dir}" ]; then
    art="${f#$articles_dir/}"
    echo -n "[fugitive] Adding $art.html to git ignore list... "
    echo "$art.html" >> .git/info/exclude
    echo "done."
    previous=`get_article_previous_file "$art"`
    next=`get_article_next_file "$art"`
    regenerate_previous_and_next_file_maybe "$previous" "$next"
  fi
done

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
    previous=`get_deleted_previous_file "$art"`
    next=`get_deleted_next_file "$art"`
    regenerate_previous_and_next_file_maybe "$previous" "$next"
  fi
done

if [ $modification -gt 0 ]; then
  echo -n "[fugitive] Generating $public_dir/archives.html... "
  cat "$templates_dir/archives.html" | \
    replace_includes | \
    replace_foreach "article" "$articles_sorted" | \
    replace_foreach "commit" "$commits" | \
    replace_empty_article_info | \
    replace_commit_info "-1" | \
    sed "/^\s*$/d" > "$public_dir/archives.html"
  echo "done."

  echo -n "[fugitive] Using last published article as index page... "
  cp "$public_dir/`head -1 $articles_sorted`.html" "$public_dir/index.html"
  echo "done".
  echo "[fugitive] Blog update complete."
fi
rm "$articles_sorted"
rm "$articles_sorted_with_delete"
rm "$commits"
rm "$generated_files"
