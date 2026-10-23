extends Control

# Lanceur VYBE : connexion, catalogue des jeux publiés, accès à VYBE Studio.

var status: Label
var user_field: LineEdit
var pass_field: LineEdit
var catalog: ItemList

func _ready() -> void:
	# Fond dégradé « liquide »
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.2, 0.5, 1.0, 0.25)
	glow.size = Vector2(900, 900)
	glow.position = Vector2(-200, -300)
	add_child(glow)

	# Panneau verre
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.position = Vector2(-210, -260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "VYBE"
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	user_field = LineEdit.new()
	user_field.placeholder_text = "Pseudo"
	box.add_child(user_field)

	pass_field = LineEdit.new()
	pass_field.placeholder_text = "Mot de passe (8 caractères min.)"
	pass_field.secret = true
	box.add_child(pass_field)

	var row := HBoxContainer.new()
	box.add_child(row)
	var login := Button.new()
	login.text = "Se connecter"
	login.pressed.connect(_on_login)
	row.add_child(login)
	var register := Button.new()
	register.text = "Créer un compte"
	register.pressed.connect(_on_register)
	row.add_child(register)

	status = Label.new()
	box.add_child(status)

	catalog = ItemList.new()
	catalog.custom_minimum_size = Vector2(0, 200)
	box.add_child(catalog)

	var refresh := Button.new()
	refresh.text = "Actualiser les jeux"
	refresh.pressed.connect(_load_catalog)
	box.add_child(refresh)

	var studio := Button.new()
	studio.text = "Ouvrir VYBE Studio"
	studio.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/studio.tscn"))
	box.add_child(studio)

func _credentials() -> Dictionary:
	return {"username": user_field.text.strip_edges(), "password": pass_field.text}

func _on_register() -> void:
	var r: Dictionary = await VybeApi.call_api(self, "register", HTTPClient.METHOD_POST, _credentials())
	status.text = "Compte créé, connectez-vous." if r.code == 201 else str(r.data.get("error", "Erreur"))

func _on_login() -> void:
	var r: Dictionary = await VybeApi.call_api(self, "login", HTTPClient.METHOD_POST, _credentials())
	if r.code == 200:
		VybeApi.token = r.data.get("token", "")
		status.text = "Connecté."
		_load_catalog()
	else:
		status.text = str(r.data.get("error", "Erreur de connexion"))

func _load_catalog() -> void:
	var r: Dictionary = await VybeApi.call_api(self, "catalog")
	catalog.clear()
	if r.code == 200:
		for g in r.data.get("games", []):
			catalog.add_item("%s — par %s" % [g.title, g.author])
	else:
		status.text = "Impossible de charger le catalogue."
