#!/bin/sh

replace_var_by_string() {
  sed "s/<?fugitive-install\s\+$1\s*?>/$2/"
}

fugitive_write_template() {
  name=`git config --get user.name`
  base64 -d | gunzip | replace_var_by_string name "$name" | \
    replace_var_by_string year "`date +%Y`"
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
  echo -n "Creating new git repository... "
  git init >/dev/null
  echo "done."
  echo -n "Creating default directory tree... "
  mkdir -p fugitive/drafts fugitive/articles fugitive/templates
  echo "done."
  echo -n "Adding default directory paths to git config... "
  git config --add --path fugitive.templates-dir "fugitive/templates"
  git config --add --path fugitive.articles-dir "fugitive/articles"
  git config --add --path fugitive.public-dir "."
  echo "done."
  echo -n "Writing default template files... "
  fugitive_write_template > fugitive/templates/article.html <<EOF
#INCLUDE:article.html#
EOF
  fugitive_write_template > fugitive/templates/archives.html <<EOF
#INCLUDE:archives.html#
EOF
  echo "done."
  echo -n "Writing default css file... "
  (base64 -d | gunzip) > fugitive.css <<EOF
#INCLUDE:fugitive.css#
EOF
  echo "done."
  fugitive_install_hooks
  echo -n "Importing files into git repository... "
  git add fugitive/templates/* fugitive.css >/dev/null
  git commit -m "fugitive inital import" >/dev/null
  echo "done."
  echo -n "Preventing git to track temp files... "
  echo "*~" > .git/info/exclude
  echo "done."
  cd - >/dev/null
  echo "Installation complete, please see the README file for an howto."
}

case "$1" in
  "--help") fugitive_help >&2;;
  "--install") fugitive_install "$2";;
  "--install-hooks") fugitive_install_hooks "$2";;
  *) fugitive_usage >&2;;
esac
