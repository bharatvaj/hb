#!/bin/sh

# hb - simple notebook manager

hb_fatal_error() {
	echo "hb: "
	while [ $# -gt 0 ]; do echo "$1"; shift; done
	exit 1
}

hb_browse() {
	cd "${HB_PATH}"
	file="$(find . -name '.git*' -prune -o -type f | cut -d"/" -f2-  | ${FUZZER})"
	[ "${file}" != "" ] && {
		echo "${file}" >> ${HB_HIST}
		${EDITOR} "${file}";
	}
}

hb_recent() {
	cd "${HB_PATH}"
	if [ -f "${HB_HIST}" ]; then
		file="$(cat "${HB_HIST}" | tail -n 1)"
		test -f "${file}" && {
			${EDITOR} "${file}";
			exit 0;
		}
	fi
	hb_fatal_error "No recent history"
}

hb_sync() {
	which git >/dev/null 2>/dev/null || hb_fatal_error "git not available, cannot sync"
	cd "${HB_PATH}"
	git fetch
	git add "${HB_PATH}"
	if [ -n "$1" ]; then
		git commit -m "$1"
	else
		git commit -m "$(uname)"
	fi
	git pull
	#TODO check for conflicts
	# if conflict exists, checkout to a
	# different unique branch
	# And pull after fetch seems
	# redundant, replace with merge
	git push
}

hb_new() {
	[ -n "$1" ] || hb_fatal_error "usage: hb new < <-c|-m> files... | filename >"
	if [ $# -gt 1 ]; then case "$1" in
		-c) shift; cp -v "$@" "$HB_PATH/" ;;
		-m) shift; mv -v "$@" "$HB_PATH/" ;;
		*) [ -n "$1" ] && hb_fatal_error "unknown command -- $@" "usage: hb new <-c|-m> files..." ;;
	esac; fi
	[ $? -ne 0 ] && exit 1;
	if ${EDITOR} "${HB_PATH}/$1"; then
		echo "${file}" >> "${HB_HIST}"
	fi
}

hb_usage() {
	[ -n "$1" ] && echo "$0: Unknown command $1"
	printf 'Usage: hb [OPTIONS]
  n, new < <-c|-m> files... | filetocreate >
                  Creates filetocreate in $HB_PATH directory with $EDITOR
                  if -c option, files are copied to $HB_PATH
                  if -m option, files are moved to $HB_PATH
  s, sync [ "message" ]
                  Attempts a pull/commit/push cycle in $HB_PATH
                  if "message" is present, commit with "message"
  r, recent       Open the last file that was accessed
  h, help         Prints this help message
'
}

test -z "${EDITOR}" && { export EDITOR=vi; }
# TODO detect windows, type on windows invokes a different command
which "${EDITOR}" >/dev/null 2>/dev/null || { export EDITOR=cat; }
XDG_DATA_HOME="${XDG_DATA_HOME:=$HOME}"
HB_PATH="${HB_PATH:=$XDG_DATA_HOME/notes}"

: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${HB_PATH:=$XDG_DATA_HOME/notes}
: ${HB_HIST:="$HB_PATH/.hbhistory"}

test -d "${HB_PATH}" || { hb_fatal_error "HB_PATH: ${HB_PATH} is not a directory"; exit 1; }
hb_option=${1}
[ $# -ge 1 ] && shift
case $hb_option in
	'') hb_browse ;;
	n|new) hb_new "$@" ;;
	s|sync) hb_sync "$@" ;;
	r|recent) hb_recent ;;
	h|help) hb_usage ;;
	*) hb_usage "$@" ;;
esac
