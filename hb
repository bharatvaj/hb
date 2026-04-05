#!/bin/sh

# hb - handbook for unix
HB_VERSION=0.4

hb_fatal_error() {
	echo "hb: $*"
	exit 1
}

hb_fuzz() {
	cd "$HB_PATH"
	if [ -d ".git" ] && command -v git >/dev/null; then
		command git ls-files | "$FUZZER"
	else
		command find . -type f \( -path '*/.git*' -prune -o -print \) |
			cut -d"/" -f2- | "$FUZZER"
	fi
}

hb_sync() {
	cd "$HB_PATH"
	command -v git >/dev/null ||
		hb_fatal_error "git not available, cannot sync"

	git fetch
	git add .
	if [ -n "$1" ]; then
		git commit -m "$1"
	else
		git commit -m "$(uname -n)"
	fi
	git pull
	git push
}

hb_edit() {
	cd "$HB_PATH"
	hb_edit_usage='usage: hb edit [file | directory]'
	case $# in
	0)
		[ -f "$HB_HIST" ] || hb_fatal_error "No recent history"
		ef="$(tail -n 1 "$HB_HIST")"
		;;
	1)
		ef="$1"
		;;
	*)
		hb_fatal_error "${hb_edit_usage}"
		;;
	esac

	_editor="$EDITOR"
	[ -d "$ef" ] && _editor="$FM"

	"$_editor" "$ef" || hb_fatal_error "Failed to open '$ef'"

	echo "$ef" >>"$HB_HIST"
}

hb_new() {
	hb_new_usage='usage: hb new [-c|-m dest] filename'
	ef="$1"
	if [ $# -eq 3 ]; then
		arg="$1"
		ef="$2"
		shift; shift;
		case "$arg" in
		-c) cp -rv "$@" "$HB_PATH/$ef" ;;
		-m) mv -v  "$@" "$HB_PATH/$ef" ;;
		*) hb_fatal_error "Expected -c or -m\n${hb_new_usage}" ;;
		esac
	elif [ $# -ne 1 ]; then
		hb_fatal_error "${hb_new_usage}"
	fi

	[ $# -eq 1 ] && hb_edit "$ef"
}

hb_usage() {
	[ -n "$1" ] && echo "$0: Unknown command $1"
	printf 'Usage: hb [OPTIONS]
  e, edit [file|directory]
                  Open the file in EDITOR, if it exists
                  If argument is a directory, open in FM
                  Else recently opened resource
  n, new [-c|-m dest ] filename
                  Creates filename in $HB_PATH directory with $EDITOR
                  if -c option, files are copied to $HB_PATH
                  if -m option, files are moved to $HB_PATH
  s, sync [ "message" ]
                  Attempts a pull/commit/push cycle in $HB_PATH
                  if "message" is present, commit with "message"
  h, help         Prints this help message
'
}

: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${HB_PATH:=$XDG_DATA_HOME/notes}
: ${HB_HIST:="$HB_PATH/.hbhistory"}
: ${EDITOR:=vi}
: ${FM:=cd}
: ${FUZZER:=fzf}

command -v "$EDITOR" >/dev/null || { EDITOR=cat; }

[ -d "$HB_PATH" ] ||
	hb_fatal_error "HB_PATH: '$HB_PATH' is not a directory"

hbcmd=$1 && shift
case $hbcmd in
'')
	command -v $FUZZER >/dev/null ||
		hb_fatal_error "\$FUZZER: '$FUZZER' not found"
	file="$(hb_fuzz)"
	hb_edit "$file"
	;;
e | edit) hb_edit "$@" ;;
n | new) hb_new "$@" ;;
s | sync) hb_sync "$@" ;;
h | help) hb_usage ;;
v | version) echo "hb v$HB_VERSION" ;;
*) hb_usage "$@" ;;
esac
