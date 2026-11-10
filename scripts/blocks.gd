class_name Blocks
## 블록 메시와 재질을 공유한다. 색은 인스턴스 셰이더 파라미터로 넣어서 배칭이 유지된다.

const SHADER_CODE := "
shader_type spatial;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float glow = 0.0;
void fragment() {
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.65;
	EMISSION = tint.rgb * glow;
}
"

static var _mat: ShaderMaterial
static var _meshes := {}
static var _shapes := {}

static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER_CODE
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat

static func mesh(size: float) -> BoxMesh:
	if not _meshes.has(size):
		var m := BoxMesh.new()
		m.size = Vector3.ONE * size
		m.material = material()
		_meshes[size] = m
	return _meshes[size]

static func box_shape(size: float) -> BoxShape3D:
	if not _shapes.has(size):
		var s := BoxShape3D.new()
		s.size = Vector3.ONE * size
		_shapes[size] = s
	return _shapes[size]

static func cell_mesh(size: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(size)
	mi.set_instance_shader_parameter("tint", color)
	return mi

## 세워 놓은 모양(XY 평면)의 블록 모형. 바닥 중앙이 원점이다.
static func piece_visual(kind: int, size: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var cs: Array = Shapes.CELLS[kind]
	var s := Shapes.size(cs)
	for c in cs:
		var mi := cell_mesh(size, color)
		mi.position = Vector3(c.x - (s.x - 1) / 2.0, c.y + 0.5, 0) * size
		root.add_child(mi)
	return root

## 바닥에 눕힌 모양(XZ 평면)의 칸 위치. 중심이 원점이다.
static func flat_offsets(kind: int) -> Array:
	var cs: Array = Shapes.CELLS[kind]
	var s := Shapes.size(cs)
	var out := []
	for c in cs:
		out.append(Vector3(c.x - (s.x - 1) / 2.0, 0, c.y - (s.y - 1) / 2.0))
	return out
