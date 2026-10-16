class_name Deck3D
extends Node3D
# Pilha de cartas deitada na mesa. Altura proporcional à contagem.

signal tapped(deck: Deck3D)

const PER_CARD := 0.0016
const MAX_H := 0.09  # teto: decks grandes (loot ~100+) não viram torre

# Laterais = bordas de cartas empilhadas: listras finas em vez de bloco liso.
const EDGE_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float freq = 300.0;  // listras por metro (~1 a cada 2 cartas)
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float top = step(0.5, abs(NORMAL.y));
	float s = fract(lp.y * freq);
	float edge = smoothstep(0.0, 0.18, s) * smoothstep(1.0, 0.72, s);
	vec3 paper = vec3(0.86, 0.80, 0.70);
	vec3 gap = vec3(0.30, 0.24, 0.20);
	ALBEDO = mix(mix(gap, paper, edge), paper * 0.9, top);
	ROUGHNESS = 0.95;
}
"""

var count := 0
var _body: MeshInstance3D
var _top: MeshInstance3D
var _top_mat: ShaderMaterial
var _bump_tw: Tween
var _label: Label3D

func setup(back_id: String, caption: String, font: Font) -> void:
	_body = MeshInstance3D.new()
	_body.mesh = BoxMesh.new()
	var sm := Shader.new()
	sm.code = EDGE_SHADER
	var em := ShaderMaterial.new()
	em.shader = sm
	_body.material_override = em
	add_child(_body)
	_top = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(Card3D.W, Card3D.H)
	_top.mesh = q
	_top_mat = Card3D.face_material(Card3D.tex(back_id))
	_top.material_override = _top_mat
	_top.rotation.x = -PI / 2
	add_child(_top)
	_label = Label3D.new()
	_label.text = caption
	_label.font = font
	_label.font_size = 28
	_label.pixel_size = 0.0035
	_label.outline_size = 0
	_label.modulate = Color(0.95, 0.85, 0.65, 0.75)
	_label.rotation.x = -PI / 2
	_label.position = Vector3(0, 0.002, Card3D.H / 2 + 0.07)
	add_child(_label)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(Card3D.W, 0.12, Card3D.H)
	cs.shape = sh
	area.add_child(cs)
	area.input_event.connect(func(_c, e, _p, _n, _i):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit(self))
	add_child(area)
	set_count(0)

func set_face(front_id: String) -> void:
	_top_mat.set_shader_parameter("tex", Card3D.tex(front_id))

# Pequeno solavanco quando uma carta sai ou entra.
func bump() -> void:
	if _bump_tw:
		_bump_tw.kill()
	scale = Vector3(1.04, 0.85, 1.04)
	_bump_tw = create_tween()
	_bump_tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_count(n: int) -> void:
	count = n
	var h := _height()
	(_body.mesh as BoxMesh).size = Vector3(Card3D.W, h, Card3D.H)
	_body.position.y = h / 2
	_top.position.y = h + 0.0006
	_body.visible = n > 0
	_top.visible = n > 0

# Transform (espaço do pai) da carta do topo, deitada com o verso para cima.
func top_xf() -> Transform3D:
	var b := Basis(Vector3.RIGHT, PI / 2)  # verso para cima
	return Transform3D(b, position + Vector3(0, _height() + 0.01, 0))

func _height() -> float:
	return min(max(count, 1) * PER_CARD, MAX_H)
