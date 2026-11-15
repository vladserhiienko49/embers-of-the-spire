class_name HeroRig
extends RefCounted
## Власний процедурний герой (темний лицар) на HumanoidKit — без сторонніх моделей і анімацій.
## Модель дивиться в +Z на нульовому повороті knight_model (як колишня Mixamo-модель), тому ріґ усередині
## повернутий на 180°. Анімації — HumanoidAnim (ходьба, біг, стрибок, щит, сидіння, удар).

const SPEC: Dictionary = {
	"build": "tunic", "helm": "none", "weapon": "none", "cloth": "#221a16", "accent": "#8a6a34", "armor": "#3a3d45",
	"face": "npc", "scale": 1.0,
}


static func build(model: Node3D) -> Dictionary:
	## Повертає {"rig", "parts", "back_anchor", "attachments"}.
	var holder := Node3D.new()
	holder.name = "HeroBody"
	holder.rotation.y = PI
	model.add_child(holder)
	var rig := HumanoidKit.build(holder, SPEC.duplicate(), "knight")
	var parts: Dictionary = rig.get("parts")
	var armor := KnightArmor.dress_rig(parts)
	# Стійка правої руки: з мечем (піднятий уперед) або вільно.
	apply_stance(rig, true)
	return {"rig": rig, "parts": parts, "back_anchor": armor["back_anchor"], "attachments": armor["attachments"]}


static func apply_stance(rig: Node3D, drawn: bool) -> void:
	var parts: Dictionary = rig.get("parts")
	var r: Dictionary = HumanoidKit._weapon_rest("sword") if drawn else {"sh": 0.05, "el": 0.2, "target": 0.0}
	rig.set("rest", r)
	var grip := parts.get("grip_r") as Node3D
	if grip:
		grip.rotation.x = float(r["target"]) - (float(r["sh"]) + float(r["el"]))
