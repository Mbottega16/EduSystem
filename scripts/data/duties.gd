class_name Duties
extends RefCounted

## The staff rota: the school's other jobs, each played as a short arcade shift
## (the owner's ask, 2026-11-06; design in the vault's roles-design.md). One row
## per job. A row that cannot be done right now is HIDDEN, not greyed -- the
## shop's and the corridor's rule. Numbers live in balance.json's "duties".

const TABLE := [
	{"id": "janitor", "name": "Janitor", "job": "Sweep the corridor",
		"blurb": "Spills and litter all down the hall. Clean every one before the clock runs out."},
]


static func all() -> Array:
	return TABLE


static func by_id(id: String) -> Dictionary:
	for d: Dictionary in TABLE:
		if String(d.get("id", "")) == id:
			return d
	return {}


## The rows the rota offers right now: none before the admin gate opens, and
## none already done today.
static func offered() -> Array:
	var out: Array = []
	if not Game.admin_unlocked():
		return out
	for d: Dictionary in TABLE:
		if not Game.duty_done_today(String(d.get("id", ""))):
			out.append(d)
	return out
