extends Control

const LOGOS_SHEET := preload("res://Assets/NPC/UI/Logos-Sheet.png")

@onready var seat_label: Label = $VBoxContainer/Header/SeatLabel
@onready var customer_icon: TextureRect = get_node_or_null("VBoxContainer/Header/CustomerIconFrame/CustomerIcon")
@onready var placeholder_label: Label = get_node_or_null("VBoxContainer/Header/CustomerIconFrame/PlaceholderLabel")
@onready var drink_name_label: Label = $VBoxContainer/DrinkNameLabel
@onready var drink_preview: Control = get_node_or_null("VBoxContainer/DrinkPreview")
@onready var order_label: Label = $VBoxContainer/Label

var _has_order_render: bool = false

func _ready() -> void:
	if customer_icon and customer_icon.texture == null:
		var default_sp := SpeciesRegistry.get_species_or_default("HUMAN")
		_set_placeholder_frame(default_sp.logo_frame if default_sp else 10)
	if order_label:
		order_label.visible = false

func _label_change(change: String) -> void:
	if _has_order_render:
		return
	if drink_name_label:
		drink_name_label.visible = false
	if drink_preview:
		drink_preview.visible = false
	if order_label:
		order_label.visible = true
		order_label.text = change

func _set_drink_order(
	order: DrinkOrder,
	drink_name: String = "",
	species_def: SpeciesBase = null,
	modifier: ModifierBase = null,
	aspect_comp: float = 1.4715
) -> void:
	_has_order_render = true

	var resolved_name := drink_name.strip_edges()
	if resolved_name == "":
		resolved_name = ReceiptDrinkRenderer.get_order_display_name(order)

	if drink_name_label:
		drink_name_label.visible = resolved_name != ""
		TextIcons.set_text(drink_name_label, resolved_name)

	if order_label:
		order_label.visible = false

	var tex := ReceiptDrinkRenderer.get_or_render_order_texture(order, species_def, modifier, aspect_comp)
	_apply_preview_texture(tex)

func _apply_preview_texture(tex: Texture2D) -> void:
	if not is_instance_valid(drink_preview):
		push_warning("Recipt2D: DrinkPreview node missing!")
		return
	drink_preview.visible = true
	if drink_preview is TextureRect:
		(drink_preview as TextureRect).texture = tex
	else:
		for child in drink_preview.get_children():
			drink_preview.remove_child(child)
			child.queue_free()
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drink_preview.add_child(rect)

func clear_drink_order() -> void:
	_has_order_render = false
	if drink_name_label:
		drink_name_label.visible = true
		TextIcons.set_text(drink_name_label, "")
	_apply_preview_texture(null)
	if order_label:
		order_label.visible = false
		order_label.text = ""

func _set_seat_number(seat_num: int) -> void:
	if seat_label:
		seat_label.text = "#" + str(seat_num)

func _set_customer_race(race: String) -> void:
	if not customer_icon:
		return
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