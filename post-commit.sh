#!/bin/sh

added_files=`git log -1 --name-status --pretty="format:" | grep -E '^A' | \
  cut -f2`
modified_files=`git log -1 --name-status --pretty="format:" | grep -E '^M' | \
  cut -f2`
deleted_files=`git log -1 --name-status --pretty="format:" | grep -E '^D' | \
  cut -f2`
