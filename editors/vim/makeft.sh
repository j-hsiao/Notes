#!/bin/bash


if [ ! -d ~/.vim/after/ftplugin ]
then
	mkdir -p ~/.vim/after/ftplugin
fi

settings=(
	"python ts=4 sts=0 sw=0 expandtab"
	"cmake ts=4 sts=0 sw=0 noexpandtab"
	"c ts=2 sts=0 sw=0 noexpandtab"
	"cpp ts=2 sts=0 sw=0 noexpandtab"
	"sh ts=4 sts=0 sw=0 noexpandtab"
	"text ts=2 sts=4 sw=2 noexpandtab"
)

for info in "${settings[@]}"
do
	ft=${info%% *}
	settings="${info#* }"
	echo "${ft}"
	echo "setlocal" "${settings}" | tee ~/.vim/after/ftplugin/${ft}.vim
done
