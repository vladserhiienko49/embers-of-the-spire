class_name QuestData
extends Resource
## Опис квесту (res://quests/*.tres). Стан зберігає QuestManager окремо.
## Стани: locked (не виконано передумов) → available (неактивний) → active →
## ready (усі цілі виконано, треба здати) → completed.

@export var id: String = ""
@export var title: String = ""
@export var category: String = "Побічне доручення"
@export var giver_id: String = ""
@export var giver_name: String = ""
@export_multiline var description: String = ""
## ID квестів, які треба завершити, щоб цей став доступним.
@export var prerequisites: Array[String] = []
## Якщо false — квест завершується одразу після останньої цілі, без здачі.
@export var turn_in: bool = true
@export var objectives: Array[QuestObjective] = []
@export var rewards: Array[QuestReward] = []

@export_group("Діалоги замовника")
@export_multiline var dialogue_offer: String = ""
@export var accept_label: String = "ПРИЙНЯТИ ДОРУЧЕННЯ"
@export_multiline var dialogue_active: String = ""
@export_multiline var dialogue_ready: String = ""
@export var turn_in_label: String = "ЗДАТИ ДОРУЧЕННЯ"
@export_multiline var dialogue_done: String = ""


func total_coins() -> int:
	var total := 0
	for reward in rewards:
		total += reward.coins
	return total
