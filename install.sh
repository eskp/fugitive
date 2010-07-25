#!/bin/sh

replace_string() {
  sed "s/<?fugitive-install\s\+$1\s*?>/$2/"
}

fugitive_write_template() {
  name=`git config --get user.name`
  base64 -d | gunzip | replace_string "name" "$name" | \
    replace_string "year" "`date +%Y`"
}

fugitive_install_hooks() {
  echo -n "Installing fugitive hooks scripts... "
  (base64 -d | gunzip) > .git/hooks/post-commit <<EOF
#INCLUDE:post-commit.sh#
EOF
  chmod +x .git/hooks/post-commit
  (base64 -d | gunzip) > .git/hooks/post-receive <<EOF
#INCLUDE:post-receive.sh#
EOF
  chmod +x .git/hooks/post-receive
  echo "done."
}

fugitive_install() {
  DIR="."
  if [ "$1" != "" ]; then DIR="$1"; fi
  if [ ! -d "$DIR" ]; then mkdir -p "$DIR"; fi
  cd "$DIR"
  if [ -d ".git" ]; then
    echo "There's already a git repository here, aborting install."
    exit 1
  fi
  echo -n "Creating new git repository... "
  git init >/dev/null
  echo "done."
  echo -n "Creating default directory tree... "
  mkdir -p _drafts _articles _templates
  echo "done."
  echo -n "Adding default directory paths and settings to git config... "
  git config --add --path fugitive.templates-dir "_templates"
  git config --add --path fugitive.articles-dir "_articles"
  git config --add --path fugitive.public-dir "."
  git config --add --path fugitive.preproc ""
  echo "done."
  echo -n "Writing default template files... "
  fugitive_write_template > _templates/article.html <<EOF
#INCLUDE:default-files/article.html#
EOF
  fugitive_write_template > _templates/archives.html <<EOF
#INCLUDE:default-files/archives.html#
EOF
  fugitive_write_template > _templates/nav-header.html <<EOF
#INCLUDE:default-files/nav-header.html#
EOF
  fugitive_write_template > _templates/footer.html <<EOF
#INCLUDE:default-files/footer.html#
EOF
  echo "done."
  echo -n "Writing dummy article (README)... "
  (base64 -d | gunzip) > _articles/README <<EOF
#INCLUDE:README#
EOF
  echo "done."
  echo -n "Writing default css files... "
  (base64 -d | gunzip) > fugitive.css <<EOF
#INCLUDE:default-files/fugitive.css#
EOF
  (base64 -d | gunzip) > print.css <<EOF
#INCLUDE:default-files/print.css#
EOF
  echo "done."
  fugitive_install_hooks
  echo -n "Preventing git to track temporary and generated files... "
  echo "*~\nindex.html\narchives.html" > .git/info/exclude
  echo "done."
  echo "Importing files into git repository... "
  git add _templates/* fugitive.css print.css >/dev/null
  git commit -m "fugitive inital import" >/dev/null
  echo "First import finished."
  cd - >/dev/null
  echo 'Installation complete!'
}

case "$1" in
  "--help") fugitive_help >&2;;
  "--install") fugitive_install "$2";;
  "--install-hooks") fugitive_install_hooks "$2";;
  *) fugitive_usage >&2;;
esac
