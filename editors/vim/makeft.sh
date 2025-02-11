#!/bin/bash


OUTDIR="${1:-${HOME}/.vim/after/ftplugin}"
if [ ! -d ${OUTDIR} ]
then
	mkdir -p ${OUTDIR}
fi

settings=(
	'python ts=4 sts=0 sw=0 expandtab'

	'cmake ts=4 sts=0 sw=0 noexpandtab'

	'c    ts=2 sts=0 sw=0 noexpandtab cms=//\ %s comments+=:#'
	'cpp  ts=2 sts=0 sw=0 noexpandtab cms=//\ %s comments+=:#'
	'cuda ts=2 sts=0 sw=0 noexpandtab cms=//\ %s comments+=:#'

	'sh   ts=4 sts=0 sw=0 noexpandtab comments=b:#'
	'bash ts=4 sts=0 sw=0 noexpandtab comments=b:#'

	'text ts=2 sts=4 sw=2 noexpandtab'

	'vim ts=4 sts=0 sw=0 noexpandtab'
)

for info in "${settings[@]}"
do
	ft=${info%% *}
	settings="${info#* }"
	echo "${ft}"
	echo "setlocal" "${settings}" | tee ${OUTDIR}/${ft}.vim
done
