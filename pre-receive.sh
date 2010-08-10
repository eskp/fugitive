#!/bin/sh

blog_url=`git config --get fugitive.blog-url`
if [ "$blog_url" = "" ]; then
  echo -n "[fugitive] ERROR: git config fugitive.blog-url is empty and" >&2
  echo -n " should not be, please set it with " >&2
  echo -n '`git config fugitive.blog-url "<url>"` ' >&2
  echo "on the remote repository, aborting." >&2
  exit 1
fi
