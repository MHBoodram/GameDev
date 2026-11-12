extends Control

const LOGOS_SHEET := preload("res://Assets/NPC/UI/Logos-Sheet.png")
const RACE_FRAME_MAP := {
	"HUMAN": 10,
	"SLIME": 7,
	"VAMPIRE": 9,
	"FISH": 8,
	"TINY": 11,
}

@onready var seat_label: Label = $VBoxContainer/Header/SeatLabel
@onready var customer_icon: TextureRect = $VBoxContainer/Header/CustomerIconFrame/CustomerIcon
@onready var placeholder_label: Label = $VBoxContainer/Header/CustomerIconFrame/PlaceholderLabel
@onready var order_label: Label = $VBoxContainer/Label

func _ready() -> void:
	if customer_icon and customer_icon.texture == null:
		_set_placeholder_frame(RACE_FRAME_MAP["HUMAN"])

func _label_change(change: String) -> void:
	if order_label:
		order_label.text = change

func _set_seat_number(seat_num: int) -> void:
	if seat_label:
		seat_label.text = "#" + str(seat_num)

func _set_customer_race(race: String) -> void:
	var frame_idx: int = RACE_FRAME_MAP.get(race.to_upper(), RACE_FRAME_MAP["HUMAN"])
	_set_placeholder_frame(frame_idx)

func _set_customer_icon(icon_texture: Texture2D) -> void:
	if not customer_icon:
		return
	customer_icon.texture = icon_texture
	if placeholder_label:
		placeholder_label.visible = (icon_texture == null)

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