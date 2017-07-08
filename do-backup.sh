#!/bin/sh
set -eu
readonly url='https://calendar.google.com/calendar/ical/irrlicht.verein%40gmail.com/public/basic.ics'
#readonly ics=basic.ics
readonly message='Regular calendar back-up'
readonly author='Irrlicht e. V. <post@irrlicht-verein.de>'


set -- -q --porcelain --no-allow-empty --no-edit --no-gpg-sign
[ -z "${author-}" ] ||	set -- "$@" --author="$author"
if [ -z "${ics-}" ]; then
	ics="${url%%[\?\#]*}"
	ics="${ics##*/}"
	readonly ics
fi


if curl -sS -z "$ics" -o "$ics" -- "$url" && [ -s "$ics" ]; then
	sed -i -e '/^DTSTAMP:/d' -- "$ics"
	if ! git diff --quiet HEAD -- "$ics"; then
		git commit "$@" -om "$message" -- "$ics"
		exec git push -q
	fi
else
	git checkout -q -- "$ics"
	exit 1
fi
