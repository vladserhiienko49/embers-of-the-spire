class_name QuestObjective
extends Resource
## Одна ціль квесту. Цілі виконуються послідовно.

enum Type { TALK, COLLECT, REACH, KILL, INTERACT }

@export var type: Type = Type.INTERACT
## ID NPC / предмета / локації / типу ворога / об'єкта взаємодії.
@export var target_id: String = ""
@export var count: int = 1
@export_multiline var text: String = ""


func type_key() -> String:
	match type:
		Type.TALK: return "talk"
		Type.COLLECT: return "collect"
		Type.REACH: return "reach"
		Type.KILL: return "kill"
		_: return "interact"
