#!/bin/bash
set -eu
exec <&-
declare -A options=(
	[url]='https://export.kalender.digital/ics/0/3424d079381829d65253/irrlichtev.ics?past_months=12&future_months=36'
	#[output]=basic.ics
	[commit]=0 [push]=0 [keep-intermediate]=0
)
declare -A commit_options=(
	[message]='Regular calendar back-up'
	[author]='Irrlicht e. V. <post@irrlicht-verein.de>'
)
declare -a commit_arguments=(
	--quiet --only --no-allow-empty --no-edit --no-gpg-sign
)

PROGNAME="${0##*/}"
PROGNAME="${PROGNAME%.sh}"
args="$(getopt -s bash -n "$PROGNAME" \
	-o 'u:A:m:o:cp' \
	-l 'url:,author:,message:,output:,commit,push,keep-intermediary' -- \
	"$@")"
eval set -- "$args"
unset args


cleanup()
{
	if [ "${options[keep-intermediary]-0}" -eq 0 ]; then
		rm -f -- "$ics_tmp"
	fi
}

do_exec()
{
	cleanup
	trap - EXIT
	exec "$@"
}

invalid_argument()
{
	printf '%s: Unknown or invalid option: "%s"\n' "$PROGNAME" "$1" >&2
}


while [ "$#" -ne 0 ]; do
	case "$1" in
		-u|--url)
			options[url]="$2"; shift;;
		-A|--author)
			commit_options[author]="$2"; shift;;
		-m|--message)
			commit_options[message]="$2"; shift;;
		-o|--output)
			options[output]="$2"; shift;;
		-c|--commit)
			options[commit]=1;;
		-p|--push)
			options[push]=1 options[commit]=1;;
		--keep-intermediary)
			options[keep-intermediary]=1;;
		--)
			shift; break;;
		--*)
			invalid_argument "${1%%=*}"; exit 64;;
		-?*)
			invalid_argument "${1:0:2}"; exit 64;;
		*)
			break;;
	esac
	shift
done

if [ -z "${options[output]-}" ]; then
	options[output]="${options[url]%%[\?\#]*}"
	options[output]="${options[output]##*/}"
fi

for k in "${!commit_options[@]}"; do
	commit_arguments+=("--$k=${commit_options["$k"]}")
done

case "$0" in
	*/*) cd -- "${0%/*}";;
esac

ics_tmp="$(mktemp --tmpdir --suffix=.ics kalender-backup-XXXXXXXXXX)"
trap cleanup EXIT

if
	curl -sS -z "${options[output]}" -o "$ics_tmp" -- "${options[url]}" &&
	[ -s "$ics_tmp" ] &&
	dos2unix < "$ics_tmp" | grep -ve '^DTSTAMP:' > "${options[output]}"
then
	if [ "${options[commit]-0}" -ne 0 ]; then
		git add -- "${options[output]}"
		git commit "${commit_arguments[@]}" -- "${options[output]}"
		if [ "${options[push]-0}" -ne 0 ]; then
			do_exec git push --quiet
		fi
	fi
else
	git checkout -q -- "${options[output]}"
	exit 1
fi
