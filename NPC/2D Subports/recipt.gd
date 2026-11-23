extends Control

const LOGOS_SHEET := preload("res://Assets/NPC/UI/Logos-Sheet.png")

@onready var seat_label: Label = $VBoxContainer/Header/SeatLabel
@onready var customer_icon: TextureRect = $VBoxContainer/Header/CustomerIconFrame/CustomerIcon
@onready var placeholder_label: Label = $VBoxContainer/Header/CustomerIconFrame/PlaceholderLabel
@onready var order_label: Label = $VBoxContainer/Label

func _ready() -> void:
	if customer_icon and customer_icon.texture == null:
		var default_sp := SpeciesRegistry.get_species_or_default("HUMAN")
		_set_placeholder_frame(default_sp.logo_frame if default_sp else 10)

func _label_change(change: String) -> void:
	if order_label:
		order_label.text = change

func _set_seat_number(seat_num: int) -> void:
	if seat_label:
		seat_label.text = "#" + str(seat_num)

func _set_customer_race(race: String) -> void:
	var sp := SpeciesRegistry.get_species_or_default(race)
	var frame_idx: int = sp.logo_frame if sp else 10
	_set_placeholder_frame(frame_idx)

func _set_customer_icon(icon_texture: Texture2D) -> void:
	if not customer_icon:
		return
	customer_icon.texture = icon_texture
	if placeholder_label:
		placeholder_label.visible = (icon_texture == null)

func _set_customer_icon_modulate(color: Color) -> void:
	if customer_icon:
		customer_icon.modulate = color

func _set_placeholder_frame(frame_idx: int) -> void:
	if not customer_icon:
		return
	if LOGOS_SHEET == null:
		customer_icon.texture = null
		if placeholder_label:
			placeholder_label.visible = true
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = LOGOS_SHEET
	var hframes: int = 12
	var frame_w: float = float(LOGOS_SHEET.get_width()) / float(hframes)
	var frame_h: float = float(LOGOS_SHEET.get_height())
	atlas.region = Rect2(float(frame_idx) * frame_w, 0.0, frame_w, frame_h)
	customer_icon.texture = atlas
	if placeholder_label:
		placeholder_label.visible = false
		
