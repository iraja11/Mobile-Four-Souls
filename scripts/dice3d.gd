class_name Dice3D
extends Node3D
# Dado físico (animado): 6 faces com pips gerados em código.

const S := 0.3
const NORMALS := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.BACK, 5: Vector3.FORWARD, 3: Vector3.RIGHT, 4: Vector3.LEFT}
const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.25, 0.25), Vector2(0.75, 0.75)],
	3: [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
	4: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
	5: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
	6: [Vector2(0.27, 0.22), Vector2(0.73, 0.22), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.78), Vector2(0.73, 0.78)],
}

static var _face_tex := {}

func _ready() -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * S
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.9, 0.82)
	m.roughness = 0.3
	m.metallic_specular = 0.6
	body.material_override = m
	add_child(body)
	for v in NORMALS:
		var n: Vector3 = NORMALS[v]
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * S * 0.92
		q.mesh = qm
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = _pips(v)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.roughness = 0.4
		q.material_override = fm
		var up := Vector3.BACK if abs(n.y) > 0.5 else Vector3.UP
		q.transform = Transform3D(Basis.looking_at(-n, up), n * (S / 2 + 0.001))
		add_child(q)

static func _pips(v: int) -> Texture2D:
	if _face_tex.has(v):
		return _face_tex[v]
	var sz := 96
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.55, 0.05, 0.06) if v == 1 else Color(0.12, 0.08, 0.08)
	var r := 13.0 if v == 1 else 9.5
	for p in PIPS[v]:
		var c: Vector2 = p * sz
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
				if Vector2(x, y).distance_to(c) <= r:
					img.set_pixel(x, y, col)
	var t := ImageTexture.create_from_image(img)
	_face_tex[v] = t
	return t

static func basis_for(v: int, yaw: float) -> Basis:
	var b: Basis
	if v == 6:
		b = Basis(Vector3.RIGHT, PI)
	elif v == 1:
		b = Basis.IDENTITY
	else:
		b = Basis(Quaternion(NORMALS[v], Vector3.UP))
	return Basis(Vector3.UP, yaw) * b

# Joga o dado de `from` até `to` (espaço do pai) e para mostrando `v`.
func throw(v: int, from: Vector3, to: Vector3) -> void:
	visible = true
	var final := basis_for(v, randf_range(-0.6, 0.6)).get_euler()
	var spin := Vector3(TAU * randi_range(2, 3), TAU * randi_range(1, 2), TAU * randi_range(1, 3))
	position = from
	var step := func(t: float) -> void:
		var p := from.lerp(to, 1.0 - pow(1.0 - t, 2.0))
		p.y = to.y + (from.y - to.y) * (1.0 - t) * absf(cos(t * PI * 2.5))
		position = p
	# Quiques em t = 0.2, 0.6 e 1.0 (zeros do |cos| em `step`), cada um mais fraco.
	Sfx.later("dice_clack", 0.85 * 0.2)
	for k in 3:
		Sfx.later("dice", 0.85 * (0.2 + 0.4 * k), 1.0 + 0.05 * k, -5.0 * k)
	var tw := create_tween().set_parallel()
	tw.tween_method(step, 0.0, 1.0, 0.85)
	tw.tween_property(self, "rotation", final, 0.85).from(final + spin).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
