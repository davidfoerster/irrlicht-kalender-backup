#!/bin/bash
set -eu
declare -A commit_options=() \
	options=([quiet]= [commit]=0 [push]=0 [keep-intermediate]=0)
declare -a commit_arguments=(--no-allow-empty --no-edit --no-gpg-sign)

progname="${0##*/}"
progname="${progname%.sh}"
case "$0" in
	*/*) exedir="${0%/*}";;
	*)   exedir=.;;
esac

getopt_short='C:u:A:m:o:cpq'
getopt_long='config:,url:,author:,message:,output:,commit,push,quiet,keep-intermediary'
args="$(getopt -s bash -n "$progname" -o "$getopt_short" -l "$getopt_long" -- "$@")"
eval "args=($args)"

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

set -- "${args[@]}"
declare -a config_files=()
while : ; do
	case "${1-}" in
		-C|--config)
			config_files+=("$2");;
		--)
			shift; break;;
		-?)
			;;
		*)
			break;;
	esac
	case "$1" in
		--?*)
			case "$getopt_long" in
				"${1:2}:"*|*",${1:2}:"*) shift 2;;
				*) shift 1;;
			esac;;
		-?)
			case "$getopt_short" in
				*"${1:1}:"*) shift 2;;
				*) shift 1;;
			esac;;
	esac
done

if [ "$#" -ne 0 ]; then
	exec >&2
	printf '%s: Unrecognised argument(s):' "$progname"
	printf ' "%s"' "$@"
	echo
	exit 64
fi

SOURCEPATH=.
case "$exedir" in
	.|*:*) ;;
	*) [ "$exedir" -ef . ] || SOURCEPATH+=":$exedir";;
esac
if [ "${#config_files[@]}" -eq 0 ]; then
	config_files=('default.cfg')
fi
for f in "${config_files[@]}"; do
	case "$f" in
		-)  source /dev/stdin;;
		?*) PATH="$SOURCEPATH" source "$f";;
	esac
done

exec <&-
set -- "${args[@]}"
while : ; do
	case "${1-}" in
		-u|--url)
			options[url]="$2";;
		-A|--author)
			commit_options[author]="$2";;
		-m|--message)
			commit_options[message]="$2";;
		-o|--output)
			options[output]="$2";;
		-q|--quiet)
			options[quiet]=--quiet;;
		-c|--commit)
			options[commit]=1;;
		-p|--push)
			options[push]=1 options[commit]=1;;
		--keep-intermediary)
			options[keep-intermediary]=1;;
		-C|--config)
			;;
		--)
			shift; break;;
		-?|--*)
			printf '%s: Unknown or invalid option: "%s"\n' "$progname" "${1%%=*}" >&2
			exit 64;;
		*)
			break;;
	esac
	case "$1" in
		--?*)
			case "$getopt_long" in
				"${1:2}:"*|*",${1:2}:"*) shift 2;;
				*) shift 1;;
			esac;;
		-?)
			case "$getopt_short" in
				*"${1:1}:"*) shift 2;;
				*) shift 1;;
			esac;;
	esac
done

if [ -z "${options[output]-}" ]; then
	options[output]="${options[url]%%[\?\#]*}"
	options[output]="${options[output]##*/}"
fi

for k in "${!commit_options[@]}"; do
	commit_arguments+=("--$k=${commit_options["$k"]}")
done

ics_tmp="$(mktemp --tmpdir --suffix=.ics kalender-backup-XXXXXXXXXX)"
trap cleanup EXIT

if
	curl ${options[quiet]:+-sS} -z "${options[output]}" -o "$ics_tmp" -- \
		"${options[url]}" &&
	[ -s "$ics_tmp" ] &&
	dos2unix < "$ics_tmp" | grep -ve '^DTSTAMP:' > "${options[output]}"
then
	if [ "${options[commit]-0}" -ne 0 ]; then
		git add ${options[quiet]} -- "${options[output]}"
		git commit --only ${options[quiet]} "${commit_arguments[@]}" -- \
			"${options[output]}"
		if [ "${options[push]-0}" -ne 0 ]; then
			do_exec git push ${options[quiet]}
		fi
	fi
else
	git checkout ${options[quiet]} -- "${options[output]}"
	exit 1
fi
