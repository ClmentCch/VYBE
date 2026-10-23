extends Control

# VYBE Studio : éditeur de script Lua, vue 3D, sauvegarde et publication.

var title_field: LineEdit
var code_editor: CodeEdit
var viewport_3d: SubViewport
var scene_root: Node3D
var game_id: int = 0
var status: Label
var camera: Camera3D
var play_button: Button
var is_playing := false
var orbit_angle := 0.0

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)

	title_field = LineEdit.new()
	title_field.placeholder_text = "Nom du jeu"
	title_field.custom_minimum_size = Vector2(240, 0)
	toolbar.add_child(title_field)

	toolbar.add_child(_button("Ajouter un cube", _add_cube))
	toolbar.add_child(_button("Sauvegarder", _save))
	toolbar.add_child(_button("Publier", _publish))
	play_button = _button("Playtest", _toggle_playtest)
	toolbar.add_child(play_button)
	toolbar.add_child(_button("Retour", func(): get_tree().change_scene_to_file("res://scenes/launcher.tscn")))

	status = Label.new()
	toolbar.add_child(status)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	code_editor = CodeEdit.new()
	code_editor.text = "-- Script Lua du jeu\nprint(\"Bonjour depuis VYBE\")\n"
	code_editor.gutters_draw_line_numbers = true
	code_editor.custom_minimum_size = Vector2(420, 0)
	split.add_child(code_editor)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(container)

	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(800, 600)
	viewport_3d.own_world_3d = true
	container.add_child(viewport_3d)

	scene_root = Node3D.new()
	viewport_3d.add_child(scene_root)
	_setup_camera_and_light()

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b

func _setup_camera_and_light() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 4, 8)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	scene_root.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	scene_root.add_child(light)

func _process(delta: float) -> void:
	if not is_playing:
		return
	orbit_angle += delta * 0.5
	camera.position = Vector3(sin(orbit_angle) * 8.0, 4.0, cos(orbit_angle) * 8.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _toggle_playtest() -> void:
	is_playing = not is_playing
	code_editor.visible = not is_playing
	play_button.text = "Arrêter" if is_playing else "Playtest"
	status.text = "Playtest : la scène tourne. Le Lua n'est pas encore exécuté." if is_playing else ""

func _add_cube() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2))
	scene_root.add_child(mesh)
	status.text = "Cube ajouté"

func _scene_to_dict() -> Dictionary:
	var parts: Array = []
	for child in scene_root.get_children():
		if child is MeshInstance3D:
			var p: Vector3 = child.position
			parts.append({"type": "box", "pos": [p.x, p.y, p.z]})
	return {"script": code_editor.text, "parts": parts}

func _save() -> void:
	var payload := {"id": game_id, "title": title_field.text.strip_edges(), "content": JSON.stringify(_scene_to_dict())}
	var r: Dictionary = await VybeApi.call_api(self, "save", HTTPClient.METHOD_POST, payload)
	if r.code == 200:
		game_id = int(r.data.get("id", 0))
		status.text = "Sauvegardé"
	else:
		status.text = str(r.data.get("error", "Erreur de sauvegarde"))

func _publish() -> void:
	if game_id == 0:
		await _save()
	if game_id == 0:
		return
	var r: Dictionary = await VybeApi.call_api(self, "publish", HTTPClient.METHOD_POST, {"id": game_id, "published": true})
	status.text = "Publié dans VYBE" if r.code == 200 else "Erreur de publication"
