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
@export var label_font_size: int = 26
@export var button_font_size: int = 24
@export var button_min_size: Vector2 = Vector2(104.0, 32.0)
@export var icon_button_size: Vector2 = Vector2(32.0, 32.0)
@export var action_icon_size: Vector2 = Vector2(20.0, 20.0)
@export var row_separation: int = 6
@export var show_action_icons: bool = true

var _rows_built: bool = false
var _control_buttons: Dictionary = {}
var _reset_buttons: Dictionary = {}
var _delete_buttons: Dictionary = {}

@onready var keybinds_list: VBoxContainer = get_node_or_null("Margin/KeybindsList") as VBoxContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	InkTheme.apply_scrollbar_theme(self)
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

	var normal_sb := InkTheme.make_box_style("paper", true, Vector4(8.0, 3.0, 8.0, 3.0))
	var hover_sb := InkTheme.make_box_style("gold_hover", true, Vector4(8.0, 3.0, 8.0, 3.0))
	var pressed_sb := InkTheme.make_box_style("pressed", true, Vector4(8.0, 4.0, 8.0, 2.0))
	var icon_normal_sb := InkTheme.make_box_style("paper", true, Vector4(4.0, 3.0, 4.0, 3.0))
	var icon_hover_sb := InkTheme.make_box_style("gold_hover", true, Vector4(4.0, 3.0, 4.0, 3.0))
	var icon_pressed_sb := InkTheme.make_box_style("pressed", true, Vector4(4.0, 4.0, 4.0, 2.0))
	var del_hover_sb := InkTheme.make_box_style("primary_hover", true, Vector4(4.0, 3.0, 4.0, 3.0))
	var del_pressed_sb := InkTheme.make_box_style("primary_pressed", true, Vector4(4.0, 4.0, 4.0, 2.0))
	var focus_sb := StyleBoxEmpty.new()

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
		lbl.add_theme_color_override("font_color", InkTheme.INK_DARK)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.add_theme_font_override("font", eff_font)
		lbl.add_theme_font_size_override("font_size", label_font_size)
		row.add_child(lbl)

		var bind_btn := Button.new()
		bind_btn.name = action_name
		bind_btn.custom_minimum_size = button_min_size
		bind_btn.focus_mode = Control.FOCUS_NONE
		bind_btn.text = SettingState._key_to_string(action_name)
		_apply_button_theme(bind_btn, eff_font, button_font_size, normal_sb, hover_sb, pressed_sb, focus_sb)
		row.add_child(bind_btn)

		var reset_btn := Button.new()
		reset_btn.name = action_name + "_Reset"
		reset_btn.custom_minimum_size = icon_button_size
		reset_btn.tooltip_text = "Reset keybind"
		reset_btn.focus_mode = Control.FOCUS_NONE
		reset_btn.icon = reset_icon
		reset_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reset_btn.expand_icon = true
		reset_btn.add_theme_constant_override("icon_max_width", 18)
		_apply_button_theme(reset_btn, eff_font, button_font_size, icon_normal_sb, icon_hover_sb, icon_pressed_sb, focus_sb)
		row.add_child(reset_btn)

		var delete_btn := Button.new()
		delete_btn.name = action_name + "_Delete"
		delete_btn.custom_minimum_size = icon_button_size
		delete_btn.tooltip_text = "Delete keybind"
		delete_btn.focus_mode = Control.FOCUS_NONE
		delete_btn.icon = delete_icon
		delete_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		delete_btn.expand_icon = true
		delete_btn.add_theme_constant_override("icon_max_width", 18)
		_apply_button_theme(delete_btn, eff_font, button_font_size, icon_normal_sb, del_hover_sb, del_pressed_sb, focus_sb)
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

func _apply_button_theme(btn: Button, eff_font: Font, f_size: int, normal_sb: StyleBox, hover_sb: StyleBox, pressed_sb: StyleBox, focus_sb: StyleBox) -> void:
	btn.set_meta("_ink_paper_styled", true)
	btn.add_theme_font_override("font", eff_font)
	btn.add_theme_font_size_override("font_size", f_size)
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_color_override("font_color", InkTheme.INK_DARK)
	btn.add_theme_color_override("font_hover_color", InkTheme.INK_DARK)
	btn.add_theme_color_override("font_pressed_color", InkTheme.INK_DARK)
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", focus_sb)