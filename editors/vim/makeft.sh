#!/bin/bash


if [ ! -d ~/.vim/after/ftplugin ]
then
	mkdir -p ~/.vim/after/ftplugin
fi

settings=(
	"python sts=4 sw=4 expandtab"
	"cmake ts=4 sts=0 sw=4 noexpandtab"
	"c sts=0 sw=2 ts=2 noexpandtab"
	"cpp sts=0 sw=2 ts=2 noexpandtab"
	"sh ts=4 sw=4 sts=0 noexpandtab"
	"text sw=2 ts=8 sts=0 noexpandtab"
)

for info in "${settings[@]}"
do
	ft=${info%% *}
	settings="${info#${ft} }"
	echo "${ft}"
	echo "setlocal" "${settings}" | tee ~/.vim/after/ftplugin/${ft}.vim
done
