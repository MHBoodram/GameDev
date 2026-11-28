class_name KeybindsScroll
extends ScrollContainer

const DEFAULT_FONT: Font = preload("res://Assets/Font/Merchant Copy.ttf")

const ACTION_ICONS: Dictionary = {
	"Up": "res://Assets/NPC/UI/upArrow.png",
	"Down": "res://Assets/NPC/UI/downArrow.png",
	"PourUp": "res://Assets/NPC/UI/upArrow.png",
	"PourDown": "res://Assets/NPC/UI/downArrow.png",
	"Hand": "res://Assets/UI/Hand.png",
	"Knife": "res://Assets/Items/Ingreidents/Knife.png",
	"Mag": "res://Assets/Items/Ingreidents/Mag.png",
	"Fishing_Rod": "res://Assets/Items/Ingreidents/Fishing_Rod.png",
	"InteractCustomer": "res://Assets/NPC/UI/human.png",
}

@export var font_file: Font = DEFAULT_FONT
@export var label_font_size: int = 32
@export var button_font_size: int = 28
@export var button_min_size: Vector2 = Vector2(108.0, 34.0)
@export var icon_button_size: Vector2 = Vector2(34.0, 34.0)
@export var action_icon_size: Vector2 = Vector2(22.0, 22.0)
@export var row_separation: int = 6
@export var show_action_icons: bool = true

var _rows_built: bool = false
var _control_buttons: Dictionary = {}
var _reset_buttons: Dictionary = {}
var _delete_buttons: Dictionary = {}

@onready var keybinds_list: VBoxContainer = get_node_or_null("Margin/KeybindsList") as VBoxContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ensure_rows_built()

func ensure_rows_built() -> void:
	if _rows_built:
		return
	if not is_instance_valid(keybinds_list):
		keybinds_list = find_child("KeybindsList", true, false) as VBoxContainer
	if not is_instance_valid(keybinds_list):
		return

	_rows_built = true
	_control_buttons.clear()
	_reset_buttons.clear()
	_delete_buttons.clear()

	for child in keybinds_list.get_children():
		keybinds_list.remove_child(child)
		child.queue_free()

	keybinds_list.add_theme_constant_override("separation", row_separation)

	var normal_style := _make_button_style(Color(0.96, 0.94, 0.90, 1.0))
	var hover_style := _make_button_style(Color(0.84, 0.88, 0.92, 1.0))
	var pressed_style := _make_button_style(Color(0.72, 0.76, 0.80, 1.0))
	var focus_style := StyleBoxEmpty.new()
	var reset_icon := SettingState.get_reset_arrow_icon()
	var delete_icon := SettingState.get_delete_x_icon()
	var eff_font := font_file if font_file else DEFAULT_FONT

	for def in SettingState.CONTROL_KEYBIND_DEFS:
		var action_name := str(def["action"])
		var label_text := str(def["label"])

		var row := HBoxContainer.new()
		row.name = action_name + "Row"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)

		if show_action_icons:
			var icon_rect := TextureRect.new()
			icon_rect.name = "Icon"
			icon_rect.custom_minimum_size = action_icon_size
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon_path := str(ACTION_ICONS.get(action_name, ""))
			if icon_path != "" and ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path) as Texture2D
			row.add_child(icon_rect)

		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_font_override("font", eff_font)
		lbl.add_theme_font_size_override("font_size", label_font_size)
		row.add_child(lbl)

		var bind_btn := Button.new()
		bind_btn.name = action_name
		bind_btn.custom_minimum_size = button_min_size
		bind_btn.focus_mode = Control.FOCUS_NONE
		bind_btn.text = SettingState._key_to_string(action_name)
		_apply_button_theme(bind_btn, eff_font, button_font_size, normal_style, hover_style, pressed_style, focus_style)
		row.add_child(bind_btn)

		var reset_btn := Button.new()
		reset_btn.name = action_name + "_Reset"
		reset_btn.custom_minimum_size = icon_button_size
		reset_btn.tooltip_text = "Reset keybind"
		reset_btn.focus_mode = Control.FOCUS_NONE
		reset_btn.icon = reset_icon
		reset_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reset_btn.expand_icon = true
		reset_btn.add_theme_constant_override("icon_max_width", 20)
		_apply_button_theme(reset_btn, eff_font, button_font_size, normal_style, hover_style, pressed_style, focus_style)
		row.add_child(reset_btn)

		var delete_btn := Button.new()
		delete_btn.name = action_name + "_Delete"
		delete_btn.custom_minimum_size = icon_button_size
		delete_btn.tooltip_text = "Delete keybind"
		delete_btn.focus_mode = Control.FOCUS_NONE
		delete_btn.icon = delete_icon
		delete_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		delete_btn.expand_icon = true
		delete_btn.add_theme_constant_override("icon_max_width", 20)
		_apply_button_theme(delete_btn, eff_font, button_font_size, normal_style, hover_style, pressed_style, focus_style)
		row.add_child(delete_btn)

		keybinds_list.add_child(row)
		_control_buttons[action_name] = bind_btn
		_reset_buttons[action_name] = reset_btn
		_delete_buttons[action_name] = delete_btn

func get_keybind_bindings() -> Dictionary:
	ensure_rows_built()
	return {
		"control_buttons": _control_buttons.duplicate(),
		"reset_buttons": _reset_buttons.duplicate(),
		"delete_buttons": _delete_buttons.duplicate(),
	}

func _make_button_style(bg_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = Color(0.0, 0.0, 0.0, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb

func _apply_button_theme(btn: Button, eff_font: Font, f_size: int, normal_sb: StyleBoxFlat, hover_sb: StyleBoxFlat, pressed_sb: StyleBoxFlat, focus_sb: StyleBoxEmpty) -> void:
	btn.add_theme_font_override("font", eff_font)
	btn.add_theme_font_size_override("font_size", f_size)
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.35, 0.45, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1, 1.0))
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", focus_sb)