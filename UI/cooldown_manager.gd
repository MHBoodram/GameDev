class_name CooldownManager
extends RefCounted

static var _runtime: CooldownRuntime = null
static var _cooldowns: Dictionary = {}
static var _button_bindings: Dictionary = {}


class CooldownEntry extends RefCounted:
	var id: String = ""
	var duration: float = 0.0
	var time_left: float = 0.0
	var group: String = "shift"
	var respect_night_pause: bool = true
	var respect_tree_pause: bool = true
	var paused: bool = false
	var on_finished: Callable = Callable()


static func install(host: Node) -> Node:
	if not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null("CooldownRuntime")
	if is_instance_valid(existing):
		_runtime = existing as CooldownRuntime
		return existing
	var runtime := CooldownRuntime.new()
	runtime.name = "CooldownRuntime"
	host.add_child(runtime)
	_runtime = runtime
	return runtime


static func _ensure_runtime() -> void:
	if is_instance_valid(_runtime) and _runtime.is_inside_tree():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return
	var gs := tree.root.get_node_or_null("GameState")
	if is_instance_valid(gs):
		install(gs)
	else:
		install(tree.root)


static func get_runtime() -> Node:
	_ensure_runtime()
	return _runtime


static func _normalize_id(cooldown_id: String) -> String:
	return cooldown_id.to_lower().strip_edges()


static func start(cooldown_id: String, duration: float, options: Dictionary = {}) -> void:
	var key := _normalize_id(cooldown_id)
	if key == "":
		return
	_ensure_runtime()

	if duration <= 0.0:
		clear(key)
		return

	var entry := CooldownEntry.new()
	entry.id = key
	entry.duration = duration
	entry.time_left = duration
	entry.group = str(options.get("group", "shift")).to_lower().strip_edges()
	entry.respect_night_pause = bool(options.get("respect_night_pause", true))
	entry.respect_tree_pause = bool(options.get("respect_tree_pause", true))
	entry.paused = bool(options.get("paused", false))
	var cb: Variant = options.get("on_finished", Callable())
	if cb is Callable:
		entry.on_finished = cb as Callable

	_cooldowns[key] = entry
	if is_instance_valid(_runtime):
		_runtime.cooldown_started.emit(key, entry.duration)
		_runtime.cooldown_updated.emit(key, entry.time_left, entry.duration)
	_sync_bindings_for_id(key)


static func is_on_cooldown(cooldown_id: String) -> bool:
	return get_time_left(cooldown_id) > 0.0


static func is_ready(cooldown_id: String) -> bool:
	return not is_on_cooldown(cooldown_id)


static func get_time_left(cooldown_id: String) -> float:
	var key := _normalize_id(cooldown_id)
	var entry: CooldownEntry = _cooldowns.get(key, null) as CooldownEntry
	if entry == null:
		return 0.0
	return maxf(0.0, entry.time_left)


static func get_duration(cooldown_id: String) -> float:
	var key := _normalize_id(cooldown_id)
	var entry: CooldownEntry = _cooldowns.get(key, null) as CooldownEntry
	if entry == null:
		return 0.0
	return maxf(0.0, entry.duration)


static func get_progress(cooldown_id: String) -> float:
	var key := _normalize_id(cooldown_id)
	var entry: CooldownEntry = _cooldowns.get(key, null) as CooldownEntry
	if entry == null or entry.duration <= 0.0:
		return 1.0
	return clampf(1.0 - (entry.time_left / entry.duration), 0.0, 1.0)


static func get_remaining_ratio(cooldown_id: String) -> float:
	var key := _normalize_id(cooldown_id)
	var entry: CooldownEntry = _cooldowns.get(key, null) as CooldownEntry
	if entry == null or entry.duration <= 0.0:
		return 0.0
	return clampf(entry.time_left / entry.duration, 0.0, 1.0)


static func set_paused(cooldown_id: String, paused: bool) -> void:
	var key := _normalize_id(cooldown_id)
	var entry: CooldownEntry = _cooldowns.get(key, null) as CooldownEntry
	if entry != null:
		entry.paused = paused


static func clear(cooldown_id: String) -> void:
	var key := _normalize_id(cooldown_id)
	if key == "":
		return
	var had_entry := _cooldowns.has(key)
	_cooldowns.erase(key)
	_sync_bindings_for_id(key)
	if had_entry and is_instance_valid(_runtime):
		_runtime.cooldown_finished.emit(key)


static func clear_group(group_name: String) -> void:
	var target_group := group_name.to_lower().strip_edges()
	var to_clear: Array[String] = []
	for key in _cooldowns.keys():
		var entry: CooldownEntry = _cooldowns[key] as CooldownEntry
		if entry != null and entry.group == target_group:
			to_clear.append(str(key))
	for key in to_clear:
		clear(key)


static func clear_all() -> void:
	var keys: Array = _cooldowns.keys()
	_cooldowns.clear()
	for key in keys:
		var k_str := str(key)
		_sync_bindings_for_id(k_str)
		if is_instance_valid(_runtime):
			_runtime.cooldown_finished.emit(k_str)
	_prune_button_bindings()
	for btn_id in _button_bindings.keys():
		var binding: Dictionary = _button_bindings[btn_id] as Dictionary
		_sync_button_binding(binding)


static func bind_button(button: BaseButton, cooldown_id: String, options: Dictionary = {}) -> void:
	if not is_instance_valid(button):
		return
	_ensure_runtime()

	var key := _normalize_id(cooldown_id)
	if key == "":
		unbind_button(button)
		return

	var btn_id := button.get_instance_id()
	var prev: Variant = _button_bindings.get(btn_id, null)
	if prev is Dictionary:
		var prev_dict: Dictionary = prev as Dictionary
		var old_overlay: Control = prev_dict.get("overlay", null) as Control
		if is_instance_valid(old_overlay):
			old_overlay.queue_free()

	var overlay_parts: Dictionary = _create_button_overlay(button, options)
	var binding: Dictionary = {
		"button": button,
		"cooldown_id": key,
		"disable_while_cooling": bool(options.get("disable_while_cooling", true)),
		"show_progress_bar": bool(options.get("show_progress_bar", true)),
		"show_countdown": bool(options.get("show_countdown", true)),
		"fill_mode": str(options.get("fill_mode", "drain")).to_lower().strip_edges(),
		"countdown_format": str(options.get("countdown_format", "%ds")),
		"overlay": overlay_parts["overlay"],
		"progress_bar": overlay_parts["progress_bar"],
		"countdown_label": overlay_parts["countdown_label"],
	}
	_button_bindings[btn_id] = binding

	if not button.tree_exiting.is_connected(_on_bound_button_exiting):
		button.tree_exiting.connect(_on_bound_button_exiting.bind(btn_id), CONNECT_ONE_SHOT)

	_sync_button_binding(binding)


static func unbind_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var btn_id := button.get_instance_id()
	if not _button_bindings.has(btn_id):
		return
	var binding: Dictionary = _button_bindings[btn_id] as Dictionary
	_button_bindings.erase(btn_id)
	var overlay: Control = binding.get("overlay", null) as Control
	if is_instance_valid(overlay):
		overlay.queue_free()
	if bool(binding.get("disable_while_cooling", true)):
		button.disabled = false
		TextIcons.sync_control_visuals(button)


static func _on_bound_button_exiting(btn_id: int) -> void:
	_button_bindings.erase(btn_id)


static func _create_button_overlay(button: BaseButton, options: Dictionary) -> Dictionary:
	var existing := button.get_node_or_null("__CooldownOverlay") as Control
	if is_instance_valid(existing):
		button.remove_child(existing)
		existing.queue_free()

	var overlay := Control.new()
	overlay.name = "__CooldownOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = true
	overlay.visible = false
	button.add_child(overlay)
	button.move_child(overlay, 0)

	var bar := ProgressBar.new()
	bar.name = "CooldownBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0

	var bg_col: Color = options.get("bg_color", Color(0.15, 0.15, 0.18, 0.32))
	var fill_col: Color = options.get("bar_color", Color(0.08, 0.08, 0.10, 0.62))

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_col
	bg_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_col
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	overlay.add_child(bar)

	var lbl := Label.new()
	lbl.name = "CooldownLabel"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 6.0
	lbl.offset_right = -8.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(options.get("countdown_font_size", 14)))
	lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.90, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	overlay.add_child(lbl)

	return {
		"overlay": overlay,
		"progress_bar": bar,
		"countdown_label": lbl,
	}


static func _sync_bindings_for_id(cooldown_id: String) -> void:
	_prune_button_bindings()
	for btn_id in _button_bindings.keys():
		var binding: Dictionary = _button_bindings[btn_id] as Dictionary
		if str(binding.get("cooldown_id", "")) == cooldown_id:
			_sync_button_binding(binding)


static func _prune_button_bindings() -> void:
	var dead_ids: Array[int] = []
	for btn_id in _button_bindings.keys():
		var binding: Dictionary = _button_bindings[btn_id] as Dictionary
		var btn: BaseButton = binding.get("button", null) as BaseButton
		if not is_instance_valid(btn) or btn.is_queued_for_deletion():
			dead_ids.append(int(btn_id))
	for btn_id in dead_ids:
		_button_bindings.erase(btn_id)


static func _sync_button_binding(binding: Dictionary) -> void:
	var button: BaseButton = binding.get("button", null) as BaseButton
	if not is_instance_valid(button) or button.is_queued_for_deletion():
		return

	var cooldown_id := str(binding.get("cooldown_id", ""))
	var time_left := get_time_left(cooldown_id)
	var duration := get_duration(cooldown_id)
	var active := time_left > 0.0 and duration > 0.0

	var overlay: Control = binding.get("overlay", null) as Control
	var bar: ProgressBar = binding.get("progress_bar", null) as ProgressBar
	var lbl: Label = binding.get("countdown_label", null) as Label

	if is_instance_valid(overlay):
		overlay.visible = active
		if active and button.get_child(0) != overlay:
			button.move_child(overlay, 0)

	if active:
		if is_instance_valid(bar):
			bar.visible = bool(binding.get("show_progress_bar", true))
			var fill_mode := str(binding.get("fill_mode", "drain"))
			bar.value = get_progress(cooldown_id) if fill_mode == "fill" else get_remaining_ratio(cooldown_id)
		if is_instance_valid(lbl):
			var show_cd := bool(binding.get("show_countdown", true))
			lbl.visible = show_cd
			if show_cd:
				var fmt := str(binding.get("countdown_format", "%ds"))
				lbl.text = fmt % ceili(time_left)

	if bool(binding.get("disable_while_cooling", true)):
		if button.disabled != active:
			button.disabled = active
			TextIcons.sync_control_visuals(button)


class CooldownRuntime extends Node:
	signal cooldown_started(cooldown_id: String, duration: float)
	signal cooldown_updated(cooldown_id: String, time_left: float, duration: float)
	signal cooldown_finished(cooldown_id: String)

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -85

	func _process(delta: float) -> void:
		if CooldownManager._cooldowns.is_empty():
			return

		var tree := get_tree()
		var tree_paused := tree != null and tree.paused
		var night_paused := false
		if tree and tree.root:
			var gs := tree.root.get_node_or_null("GameState")
			if gs and "night_paused" in gs:
				night_paused = bool(gs.get("night_paused"))

		var finished_entries: Array[CooldownEntry] = []
		var keys: Array = CooldownManager._cooldowns.keys()
		for key in keys:
			if not CooldownManager._cooldowns.has(key):
				continue
			var entry: CooldownEntry = CooldownManager._cooldowns[key] as CooldownEntry
			if entry == null:
				CooldownManager._cooldowns.erase(key)
				continue
			if entry.paused:
				continue
			if entry.respect_tree_pause and tree_paused:
				continue
			if entry.respect_night_pause and night_paused:
				continue

			entry.time_left = maxf(0.0, entry.time_left - delta)
			if entry.time_left <= 0.0:
				finished_entries.append(entry)
			else:
				cooldown_updated.emit(entry.id, entry.time_left, entry.duration)
				CooldownManager._sync_bindings_for_id(entry.id)

		for entry in finished_entries:
			CooldownManager._cooldowns.erase(entry.id)
			CooldownManager._sync_bindings_for_id(entry.id)
			cooldown_finished.emit(entry.id)
			if entry.on_finished.is_valid():
				entry.on_finished.call()
