#!/bin/bash

checks=(
	'#{HOME}'
	'#{?#{l:1},yes,no}'
	'#{?#{l:0},yes,no}'
	'#{?#{l:on},yes,no}'
	'#{?#{l:off},yes,no}'
	'#{?#{l:boogerbob},yes,no}'
	'#{?#{l:000},yes,no}'
	'#{?#{l:y},yes,no}'
	'#{?#{l:n},yes,no}'
	'#{?#{l:yes},yes,no}'
	'#{?#{l:no},yes,no}'
	'#{?#{l:},yes,no}'
	'#{?1,yes,no}'
	'#{?0,yes,no}'
	'#{=5:#{l:0123456789}}'
	'#{=/5/...:#{l:0123456789}}'
	'"#{p15:#{l:0123456789}}"'
	'"#{p/15/15:#{l:0123456789}}"'
	'"#{p/15/15:0123456789}"'
	'#{<:a,b}'
	'#{<:HOME,b}'
	'#{m:HOME,*#{USER}}'
	'#{m:#{HOME},*#{USER}}'
	'#{m:*#{USER},#{HOME}}'
	'#{a:#{l:97}}'
	'#{HOME}'
	'#{b:HOME}'
	'#{d:HOME}'
	'#{d:#{d:HOME}}'
	'#{q:HOME}'
	'#{q:#{l:whatever goodbye}}'
	'#{q:whatever goodbye}'
	'#{MYVAR}'
	'#{d:MYVAR}'
	'#{b:MYVAR}'
	'#{q:#{d:MYVAR}}'
	'#{q:#{b:MYVAR}}'
)

tmux setenv MYVAR '/a/path with spaces'
for exp in "${checks[@]}"
do
	printf '%s: ' "${exp}"
	tmux display -p "${exp}"
done
