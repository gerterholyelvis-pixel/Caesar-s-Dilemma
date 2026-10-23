class_name HornScript
extends RefCounted
# The Horn's lines. Static data. Each line <= 90 characters.
# 0 intro | 1 look upon the walls | 2 the door listens to order | 3 hint | 4 rebuke after failure

const GROUPS: Array = [
	[ # 0 - intro
		"Another one falls, and the old stone shivers at the weight.",
		"From Limbo you came, past five statues that dared not stop you.",
		"The little one in the red hat, the Courier, has carried you this far.",
		"I am the Horn. I speak what the walls have forgotten.",
		"This is the First Act. You stand in the Antechamber.",
		"The door will not open for the unprepared. Listen. Look. Answer.",
	],
	[ # 1 - look upon the walls
		"Look upon the walls. Five glyphs wait there, patient as the dead.",
		"They were carved before the door was hung. They remember the order.",
	],
	[ # 2 - the door listens
		"The door listens to the order of things.",
		"Not the loud order. The true one.",
		"What was first must be first. What was last, last.",
	],
	[ # 3 - hint
		"You hurry, small thing. Stand still. Let your eyes do the walking.",
		"Each glyph is a word. Each word is a step. Steps keep their sequence.",
		"Touch them as the tale was told, and the door will lean to hear you.",
	],
	[ # 4 - rebuke after failure
		"No. The stone is unmoved, and so am I.",
		"Hasty hands wake only echoes. Even the Courier winces.",
		"Begin again.",
	],
]

const LINE_HOLD := 0.8
const GROUP_END_HOLD := 2.6

static func lines_for(group: int) -> Array:
	if group < 0 or group >= GROUPS.size():
		return []
	var src: Array = GROUPS[group]
	var out: Array = []
	for i in src.size():
		out.append({
			"text": src[i],
			"hold": GROUP_END_HOLD if i == src.size() - 1 else LINE_HOLD,
			"id": "g%d_l%d" % [group, i],
		})
	return out
