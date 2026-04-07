#!/bin/bash


OUTDIR="${1:-${HOME}/.vim/after/ftplugin}"
if [ ! -d ${OUTDIR} ]
then
	mkdir -p ${OUTDIR}
fi

settings=(
	'python ts=4 sts=0 sw=0 expandtab'
	'toml ts=4 sts=0 sw=0 expandtab'

	'cmake ts=4 sts=0 sw=0 noexpandtab'

	'c    ts=2 sts=0 sw=0 noexpandtab cms=//\ %s comments+=:#'
	'cpp  ts=2 sts=0 sw=0 noexpandtab cms=//\ %s comments+=:#'
	'cuda ts=2 sts=0 sw=0 noexpandtab cms=//\ %s comments+=:#'

	'sh   ts=4 sts=0 sw=0 noexpandtab comments=b:#'
	'bash ts=4 sts=0 sw=0 noexpandtab comments=b:#'

	'text ts=2 sts=4 sw=2 noexpandtab'

	'vim ts=4 sts=0 sw=0 noexpandtab'
)

maxlen=0
for info in "${settings[@]}"
do
	info="${info%% *}"
	((maxlen = "${#info}" > maxlen ? "${#info}" : maxlen))
done
fmt="%${maxlen}s : %s\\n"

for info in "${settings[@]}"
do
	ft=${info%% *}
	settings="${info#* }"
	settings="${settings#${settings%%[^[:blank:]]*}}"

	if [[ -f "${OUTDIR}/${ft}.vim" ]]
	then
		read -r -d '' result < "${OUTDIR}/${ft}.vim"
		if [[ "${result}" = "setlocal ${settings}"?($'\n') ]]
		then
			printf "${fmt}" "${ft}" 'up to date'
			continue
		else
			printf "${fmt}" '-' "${result}"
		fi
	fi
	printf "${fmt}" "${ft}" "setlocal ${settings}"
	continue
	echo "setlocal ${settings}" > "${OUTDIR}/${ft}.vim"
done
