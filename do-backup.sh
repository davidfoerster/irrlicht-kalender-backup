#!/bin/sh
set -eu
exec <&-
readonly url='https://calendar.google.com/calendar/ical/irrlicht.verein%40gmail.com/public/basic.ics'
#readonly ics=basic.ics
readonly message='Regular calendar back-up'
readonly author='Irrlicht e. V. <post@irrlicht-verein.de>'

case "$0" in
	*/*) cd "${0%/*}";;
esac

set -- -q --no-allow-empty --no-edit --no-gpg-sign
[ -z "${author-}" ] ||	set -- "$@" --author="$author"
if [ -z "${ics-}" ]; then
	ics="${url%%[\?\#]*}"
	ics="${ics##*/}"
	readonly ics
fi

cleanup()
{
	rm -f -- "$ics_tmp"
}

do_exec()
{
	cleanup
	trap - EXIT
	exec "$@"
}

ics_tmp="$(tempfile -s.ics)"
trap cleanup EXIT

if curl -sS -z "$ics" -o "$ics_tmp" -- "$url" && [ -s "$ics_tmp" ]; then
	grep -ve '^DTSTAMP:' < "$ics_tmp" > "$ics"
	if git commit "$@" -qom "$message" -- "$ics"; then
		do_exec git push -q
	fi
else
	git checkout -q -- "$ics"
	exit 1
fi
