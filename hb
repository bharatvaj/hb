#!/bin/sh

# hb - simple notebook manager

hb_fatal_error() {
	echo "hb: "
	while [ $# -gt 0 ]; do echo "$1"; shift; done
	exit 1
}

hb_browse() {
    cd "${HB_PATH}"
    if [ -d "${1}" ] && command -v "${FM}"; then
        "${FM}" "${1}"
    elif [ -e "${1}" ]; then
        "${EDITOR}" "${1}"
    fi
}


hb_fuzz() {
	cd "${HB_PATH}"
    # TODO Add git ls-files -o --exclude-standard output to FUZZER as well
    {
        if [ -d ".git" ] && command -v git; then
            command git ls-files;
        else
            find . -type f \( -path '*/.git*' -prune -o -print \) | cut -d"/" -f2-;
        fi
    } | ${FUZZER} | tee -a ${HB_HIST};
}

hb_sync() {
	type git >/dev/null 2>/dev/null ||
        hb_fatal_error "git not available, cannot sync"
	cd "${HB_PATH}" ||
        hb_fatal_error "Cannot change directory to '${HB_PATH}'"
	git fetch
	git add .
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

hb_edit() {
    hb_edit_usage='usage: hb edit [file]'
	[ "$#" -gt 1  ] && hb_fatal_error "${hb_edit_usage}"

    edit_file="$1"
    if [ "$#" -eq 0 ]; then
        [ -f "${HB_HIST}" ] || hb_fatal_error "No recent history"
        edit_file="$(cat "${HB_HIST}" | tail -n 1)"
    fi
    "${EDITOR}" "${HB_PATH}/${edit_file}" ||
        hb_fatal_error "Failed to open '${edit_file}'"
    echo "${edit_file}" >> "${HB_HIST}"
}

hb_new() {
    hb_new_usage='usage: hb new [-c|-m dest] filename'
	[ $# -gt 3 ] && hb_fatal_error "${hb_new_usage}"

    if [ $# -eq 1 ]; then
        src_file="$1"
        dest_dir="$HB_PATH"
        basedir="${src_file%/*}"
        if [ ! "${src_file}" = "${basedir}" ]; then
            mkdir -p "${basedir}"
        fi
    elif [ $# -eq 3 ]; then
        src_file="$3"
        dest_dir="$HB_PATH/$2"
    else
        hb_fatal_error "${hb_new_usage}"
    fi

	if [ $# -eq 3 ]; then case "$1" in
		-c) shift; cp -v "${src_file}" "${dest_dir}" ;;
		-m) shift; mv -v "${src_file}" "${dest_dir}" ;;
		*) [ -n "$1" ] &&
            hb_fatal_error "unknown command -- $@" "${hb_new_usage}" ;;
	esac; fi
	[ $? -ne 0 ] && exit 1;
	if ${EDITOR} "${dest_dir}/$1"; then
		echo "${file}" >> "${HB_HIST}"
	fi
}

hb_usage() {
	[ -n "$1" ] && echo "$0: Unknown command $1"
	printf 'Usage: hb [OPTIONS]
  e, edit [file]
                  Open the file in EDITOR, if it exists
  n, new  [-c|-m files... | filename]
                  Creates filetocreate in $HB_PATH directory with $EDITOR
                  if -c option, files are copied to $HB_PATH
                  if -m option, files are moved to $HB_PATH
                  If no file is specified, opens the last entry
  s, sync [ "message" ]
                  Attempts a pull/commit/push cycle in $HB_PATH
                  if "message" is present, commit with "message"
  h, help         Prints this help message
'
}

[ -z "${EDITOR}" ] && { export EDITOR=vi; }
# TODO detect windows, type on windows invokes a different command
which "${EDITOR}" >/dev/null 2>/dev/null || { export EDITOR=cat; }
XDG_DATA_HOME="${XDG_DATA_HOME:=$HOME}"
HB_PATH="${HB_PATH:=$XDG_DATA_HOME/notes}"

: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${HB_PATH:=$XDG_DATA_HOME/notes}
: ${HB_HIST:="$HB_PATH/.hbhistory"}

[ -d "${HB_PATH}" ] || {
    hb_fatal_error "HB_PATH: '${HB_PATH}' is not a directory"; exit 1;
}

hb_option=${1}
[ $# -ge 1 ] && shift
case $hb_option in
    '') file=$(hb_fuzz); hb_browse "${file}" ;;
	b) hb_browse "." ;;
	e|edit) hb_edit "$@" ;;
	n|new) hb_new "$@" ;;
	s|sync) hb_sync "$@" ;;
	h|help) hb_usage ;;
	*) hb_usage "$@" ;;
esac
