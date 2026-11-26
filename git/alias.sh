#!/bin/bash

# diff with child commit on path to target
git config "${@}" alias.diff1 '!diff1() { if [ $# = 1 ]; then a=@; b="${1}"; else a="${1:-@}"; b="${2:-dev}"; fi; git diff "${a}" $(git rev-list --ancestry-path "${a}..${b}" |tail -n 1); }; diff1'
# merge with child commit on path to target
git config "${@}" alias.merge1 '!merge1() { if [ $# = 1 ]; then a=@; b="${1}"; else a="${1:-@}"; b="${2:-dev}"; fi; git merge "${a}" $(git rev-list --ancestry-path "${a}..${b}" |tail -n 1); }; merge1'
