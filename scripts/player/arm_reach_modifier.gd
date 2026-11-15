class_name ArmReachModifier
extends Node
## Процедурні пози героя поверх ходьби (вузол-посередник до HumanoidAnim): права рука тягнеться
## (меч зі спини, ягоди, кіт), сидіння (піч, сідло). API збережено від попередньої версії:
## reach (0..1), sit (0..1), set_pose(upper_dir, fore_dir), setup(rig).
## Напрямки (upper/fore) задані у «старому» просторі скелета, де персонаж дивиться на +Z; тут вони
## переводяться у кути плеча й ліктя ріґа.

const BACK_UPPER := Vector3(-0.35, 0.82, -0.3)
const BACK_FORE := Vector3(0.55, 0.45, -0.7)

var rig: Node3D = null
var reach: float = 0.0:
	set(v):
		reach = v
		if rig:
			rig.set("reach", v)
var sit: float = 0.0:
	set(v):
		sit = v
		if rig:
			rig.set("sit", v)
var saddle: bool = false:
	set(v):
		saddle = v
		if rig:
			rig.set("saddle", v)
var upper_dir: Vector3 = BACK_UPPER
var fore_dir: Vector3 = BACK_FORE


func setup(hero_rig: Node3D) -> void:
	rig = hero_rig
	set_pose(BACK_UPPER, BACK_FORE)


func set_pose(upper: Vector3, fore: Vector3) -> void:
	upper_dir = upper
	fore_dir = fore
	if rig == null:
		return
	# Рука висить уздовж -Y; обертання навколо X на кут a дає напрямок (0, -cos a, -sin a) у ріґі (перед -Z).
	var a1 := atan2(upper.z, -upper.y)
	var a2 := atan2(fore.z, -fore.y)
	# Обираємо еквівалент, ближчий до діапазону руху плеча (-3.4..3.4).
	rig.set("reach_a", a1)
	rig.set("reach_e", clampf(a2 - a1, -0.3, 2.6))
