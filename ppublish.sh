#!/bin/bash

echo "$OSTYPE"
if [[ "$OSTYPE" == 'msys' ]]; then
  echo 'OS is Windows. Setting npm script-shell to bash'
  if test -f 'C:/Program Files/git/bin/bash.exe'; then
    npm config set script-shell 'C:/Program Files/git/bin/bash.exe'
    echo 'script-shell set to C:/Program Files/git/bin/bash.exe'
  elif test -f 'C:/Program Files (x86)/git/bin/bash.exe'; then
    npm config set script-shell 'C:/Program Files (x86)/git/bin/bash.exe'
    echo 'script-shell set to C:/Program Files (x86)/git/bin/bash.exe'
  elif test -f 'C:/Windows/System32/bash.exe'; then
    npm config set script-shell 'C:/Windows/System32/bash.exe'
    echo 'script-shell set to C:/Windows/System32/bash.exe'
  else
    error_exit 'git is not installed!'
  fi
fi

if test -f '.gitignore'; then
  git mv .gitignore .gitignore.back
  npm run build
  git add -- ./dist
  git commit -m 'chore: add built files' -- ./dist
  git mv .gitignore.back .gitignore
  cd ./dist
  git ls-files -z | xargs -0 git update-index --assume-unchanged
else
  error_exit '.gitignore does not exist!'
fi
