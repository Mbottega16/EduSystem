extends RefCounted

## NOTE: no class_name. A brand-new global class is not in the registry
## until the project is rescanned, so a headless run fails to parse anything
## referencing it. Preloaded where it is used instead.

## What build am I actually running?
##
## This exists because "I don't see the changes" is otherwise unanswerable
## from inside the game. The stamp is on the title screen, so the question
## is settled by looking rather than by guessing at launchers, stale saves
## and exported copies.
##
## Bump BUILD whenever something lands that a player would notice.

const BUILD := "b10"
const DATED := "2026-08-14"

## The headline of what went in, short enough for one line on the title.
const HEADLINE := "traits, noise, voice, inspections"


static func stamp() -> String:
	return "build %s  %s  -  %s" % [BUILD, DATED, HEADLINE]
