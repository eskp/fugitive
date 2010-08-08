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
  (base64 -d | gunzip) > .git/hooks/post-receive <<EOF
#INCLUDE:post-receive.sh#
EOF
  (base64 -d | gunzip | \
    tee -a .git/hooks/post-commit) >> .git/hooks/post-receive <<EOF
#INCLUDE:html-gen.sh#
EOF
  chmod +x .git/hooks/post-commit
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
  echo -n "Adding default settings to git config... "
  if [ "$2" = "remote" ]; then
    git config --add receive.denyCurrentBranch "ignore"
  fi
  git config --add fugitive.blog-url ""
  git config --add fugitive.templates-dir "_templates"
  git config --add fugitive.articles-dir "_articles"
  git config --add fugitive.public-dir "_public"
  git config --add fugitive.preproc ""
  echo "done."
  fugitive_install_hooks
  echo -n "Preventing git to track temporary and generated files... "
    cat >> .git/info/exclude <<EOF
*~
_public/index.html
_public/archives.html
_public/feed.xml
EOF
  echo "done."
  if [ "$2" = "local" ]; then
    echo -n "Creating default directory tree... "
    mkdir -p _drafts _articles _templates _public
    echo "done."
    echo -n "Writing default template files... "
    fugitive_write_template > _templates/article.html <<EOF
#INCLUDE:default-files/article.html#
EOF
    fugitive_write_template > _templates/archives.html <<EOF
#INCLUDE:default-files/archives.html#
EOF
    fugitive_write_template > _templates/top.html <<EOF
#INCLUDE:default-files/top.html#
EOF
    fugitive_write_template > _templates/bottom.html <<EOF
#INCLUDE:default-files/bottom.html#
EOF
    fugitive_write_template > _templates/feed.xml <<EOF
#INCLUDE:default-files/feed.xml#
EOF
    echo "done."
    echo -n "Writing default css files... "
    (base64 -d | gunzip) > _public/fugitive.css <<EOF
#INCLUDE:default-files/fugitive.css#
EOF
    (base64 -d | gunzip) > _public/print.css <<EOF
#INCLUDE:default-files/print.css#
EOF
    echo "done."
    echo -n "Importing files into git repository... "
    git add _templates/* _public/*.css >/dev/null
    git commit -m "fugitive inital import" >/dev/null 2>&1
    echo "done."
    echo "Writing dummy article (README) and adding it to the repos... "
    (base64 -d | gunzip) > _articles/README <<EOF
#INCLUDE:README#
EOF
    git add _articles/README
    git commit -m "fugitive: README" >/dev/null
    echo "done."
  fi
  echo "Installation complete, please set your blog url using"
  echo '`git config fugitive.blog-url "<url>"`.'
  cd - >/dev/null
}

case "$1" in
  "--help"|"-h") fugitive_help >&2;; # TODO
  "--install"|"--install-local") fugitive_install "$2" "local";;
  "--install-remote") fugitive_install "$2" "remote";;
  "--install-hooks") fugitive_install_hooks "$2";;
  *) fugitive_usage >&2;; # TODO
esac
