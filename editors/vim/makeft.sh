#!/bin/bash


if [ ! -d ~/.vim/after/ftplugin ]
then
	mkdir -p ~/.vim/after/ftplugin
fi

settings=(
	"python ts=4 sts=4 sw=4 expandtab"
	"cmake ts=4 sts=0 sw=4 noexpandtab noautoindent"
	"c ts=2 sts=0 sw=2 noexpandtab noautoindent"
	"cpp ts=2 sts=0 sw=2 noexpandtab noautoindent"
	"sh ts=4 sts=0 sw=4 noexpandtab noautoindent"
	"text ts=8 sts=0 sw=2 noexpandtab noautoindent"
)

for info in "${settings[@]}"
do
	ft=${info%% *}
	settings="${info#* }"
	echo "${ft}"
	echo "setlocal" "${settings}" | tee ~/.vim/after/ftplugin/${ft}.vim
done
