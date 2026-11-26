class_name FastForward
extends RefCounted

const DEFAULT_DURATION: float = 0.25
const DIALOGUE_SCOPE := "dialogue"

static var default_duration: float = DEFAULT_DURATION
static var auto_hook_dialogue_labels: bool = true
static var dialogue_fast_forward_duration: float = DEFAULT_DURATION
static var dialogue_snap_on_repeat: bool = true

static var _runtime: FastForwardRuntime = null
static var _scopes: Dictionary = {}
static var _attached_dialogue_labels: Dictionary = {}


class WaitHandle extends RefCounted:
	signal finished

	var time_left: float = 0.0
	var fast_forwarded: bool = false
	var done: bool = false
	var host: Node = null
	var ignore_time_scale: bool = false

	func complete() -> void:
		if done:
			return
		done = true
		time_left = 0.0
		finished.emit()


class ScopeState extends RefCounted:
	var id: String = ""
	var duration: float = DEFAULT_DURATION
	var snap_on_repeat: bool = false
	var auto_fast_forward: bool = false
	var triggered_auto: bool = false
	var priority: int = 0
	var trigger_mouse_buttons: Array[int] = [MOUSE_BUTTON_LEFT]
	var trigger_actions: Array[StringName] = [&"Left_click", &"ui_accept"]
	var consume_input: bool = true
	var ignore_over_buttons: bool = true
	var allow_when_dialogue_open: bool = false
	var allow_when_paused: bool = false
	var items: Array[Dictionary] = []

	func apply_options(options: Dictionary) -> void:
		if options.has("duration"):
			duration = maxf(0.0, float(options["duration"]))
		if options.has("snap_on_repeat"):
			snap_on_repeat = bool(options["snap_on_repeat"])
		if options.has("auto_fast_forward"):
			auto_fast_forward = bool(options["auto_fast_forward"])
		if options.has("priority"):
			priority = int(options["priority"])
		if options.has("consume_input"):
			consume_input = bool(options["consume_input"])
		if options.has("ignore_over_buttons"):
			ignore_over_buttons = bool(options["ignore_over_buttons"])
		if options.has("allow_when_dialogue_open"):
			allow_when_dialogue_open = bool(options["allow_when_dialogue_open"])
		if options.has("allow_when_paused"):
			allow_when_paused = bool(options["allow_when_paused"])
		if options.has("trigger_mouse_buttons") and options["trigger_mouse_buttons"] is Array:
			trigger_mouse_buttons.clear()
			for btn in options["trigger_mouse_buttons"]:
				trigger_mouse_buttons.append(int(btn))
		if options.has("trigger_actions") and options["trigger_actions"] is Array:
			trigger_actions.clear()
			for act in options["trigger_actions"]:
				trigger_actions.append(StringName(str(act)))


static func install(host: Node) -> Node:
	if not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null("FastForwardRuntime")
	if is_instance_valid(existing):
		_runtime = existing as FastForwardRuntime
		return existing
	var runtime := FastForwardRuntime.new()
	runtime.name = "FastForwardRuntime"
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


static func _get_or_create_scope(scope_id: String, options: Dictionary = {}) -> ScopeState:
	var key := scope_id.strip_edges()
	if key == "":
		key = "default"
	var scope: ScopeState
	if _scopes.has(key):
		scope = _scopes[key] as ScopeState
	else:
		scope = ScopeState.new()
		scope.id = key
		scope.duration = default_duration
		_scopes[key] = scope
	if not options.is_empty():
		scope.apply_options(options)
	return scope


static func begin_scope(scope_id: String, options: Dictionary = {}) -> ScopeState:
	_ensure_runtime()
	var scope := _get_or_create_scope(scope_id, options)
	scope.triggered_auto = false
	return scope


static func configure_scope(scope_id: String, options: Dictionary) -> ScopeState:
	_ensure_runtime()
	return _get_or_create_scope(scope_id, options)


static func has_scope(scope_id: String) -> bool:
	return _scopes.has(scope_id.strip_edges())


static func end_scope(scope_id: String) -> void:
	var key := scope_id.strip_edges()
	if not _scopes.has(key):
		return
	var scope := _scopes[key] as ScopeState
	for item in scope.items:
		if item.get("kind", "") == "wait":
			var handle := item.get("handle") as WaitHandle
			if handle and not handle.done:
				handle.complete()
	scope.items.clear()
	_scopes.erase(key)


static func set_dialogue_fast_forward(duration: float, enabled: bool = true, snap_on_repeat: bool = true) -> void:
	dialogue_fast_forward_duration = maxf(0.0, duration)
	auto_hook_dialogue_labels = enabled
	dialogue_snap_on_repeat = snap_on_repeat
	if has_scope(DIALOGUE_SCOPE):
		configure_scope(DIALOGUE_SCOPE, {
			"duration": dialogue_fast_forward_duration,
			"snap_on_repeat": dialogue_snap_on_repeat,
		})


static func wait(seconds: float, host_node: Node = null, scope_id: String = "default", options: Dictionary = {}) -> void:
	if seconds <= 0.0:
		return
	_ensure_runtime()
	var scope := _get_or_create_scope(scope_id)
	var handle := WaitHandle.new()
	handle.time_left = seconds
	handle.host = host_node
	handle.ignore_time_scale = bool(options.get("ignore_time_scale", false))

	var item := {
		"kind": "wait",
		"handle": handle,
		"duration_override": float(options.get("duration", -1.0)),
		"done": false,
	}
	scope.items.append(item)

	if scope.auto_fast_forward and scope.triggered_auto:
		var ff_dur := _resolve_item_duration(scope, item)
		_fast_forward_item(item, ff_dur, scope.snap_on_repeat)

	if not handle.done:
		await handle.finished


static func track_tween(tween: Tween, total_duration: float, scope_id: String = "default", options: Dictionary = {}) -> Tween:
	if tween == null or not is_instance_valid(tween) or not tween.is_valid():
		return tween
	_ensure_runtime()
	var scope := _get_or_create_scope(scope_id)
	for existing in scope.items:
		if existing.get("kind", "") == "tween" and existing.get("tween") == tween:
			return tween

	var item := {
		"kind": "tween",
		"tween": tween,
		"total_duration": maxf(0.0, total_duration),
		"elapsed": 0.0,
		"speed_scale": 1.0,
		"fast_forwarded": false,
		"duration_override": float(options.get("duration", -1.0)),
		"done": false,
	}
	scope.items.append(item)
	tween.finished.connect(func() -> void:
		item["done"] = true
	, CONNECT_ONE_SHOT)

	if scope.auto_fast_forward and scope.triggered_auto:
		var ff_dur := _resolve_item_duration(scope, item)
		_fast_forward_item(item, ff_dur, scope.snap_on_repeat)

	return tween


static func await_tween(tween: Tween, total_duration: float, scope_id: String = "default", options: Dictionary = {}) -> void:
	track_tween(tween, total_duration, scope_id, options)
	if is_instance_valid(tween) and tween.is_valid() and tween.is_running():
		await tween.finished


static func track_animation(anim_player: AnimationPlayer, scope_id: String = "default", options: Dictionary = {}) -> AnimationPlayer:
	if anim_player == null or not is_instance_valid(anim_player) or not anim_player.is_playing():
		return anim_player
	_ensure_runtime()
	var scope := _get_or_create_scope(scope_id)
	var active_anim := anim_player.current_animation
	for existing in scope.items:
		if existing.get("kind", "") == "anim" and existing.get("player") == anim_player and existing.get("anim_name") == active_anim:
			return anim_player

	var orig_speed := anim_player.speed_scale
	var item := {
		"kind": "anim",
		"player": anim_player,
		"anim_name": active_anim,
		"orig_speed_scale": orig_speed,
		"fast_forwarded": false,
		"restored": false,
		"duration_override": float(options.get("duration", -1.0)),
		"done": false,
	}
	scope.items.append(item)

	anim_player.animation_finished.connect(func(finished_name: StringName) -> void:
		if finished_name == item["anim_name"] or not is_instance_valid(anim_player) or not anim_player.is_playing():
			_restore_animation_speed(item)
			item["done"] = true
	, CONNECT_ONE_SHOT)

	if scope.auto_fast_forward and scope.triggered_auto:
		var ff_dur := _resolve_item_duration(scope, item)
		_fast_forward_item(item, ff_dur, scope.snap_on_repeat)

	return anim_player


static func await_animation(anim_player: AnimationPlayer, anim_name: StringName = &"", scope_id: String = "default", options: Dictionary = {}) -> void:
	if not is_instance_valid(anim_player):
		return
	if anim_name != &"":
		anim_player.play(anim_name)
	track_animation(anim_player, scope_id, options)
	if anim_player.is_playing():
		await anim_player.animation_finished


static func track_callable(callback: Callable, scope_id: String = "default", options: Dictionary = {}) -> void:
	if not callback.is_valid():
		return
	_ensure_runtime()
	var scope := _get_or_create_scope(scope_id)
	var item := {
		"kind": "callable",
		"callback": callback,
		"fast_forwarded": false,
		"duration_override": float(options.get("duration", -1.0)),
		"done": false,
	}
	scope.items.append(item)
	if scope.auto_fast_forward and scope.triggered_auto:
		var ff_dur := _resolve_item_duration(scope, item)
		_fast_forward_item(item, ff_dur, scope.snap_on_repeat)


static func attach_dialogue_label(label: RichTextLabel, options: Dictionary = {}) -> void:
	if not is_instance_valid(label) or not ("is_typing" in label):
		return
	var id := label.get_instance_id()
	if _attached_dialogue_labels.has(id):
		return
	_attached_dialogue_labels[id] = true

	var scope_opts := {
		"duration": dialogue_fast_forward_duration,
		"snap_on_repeat": dialogue_snap_on_repeat,
		"priority": 100,
		"allow_when_dialogue_open": true,
	}
	for k in options.keys():
		scope_opts[k] = options[k]

	if label.has_signal("started_typing"):
		label.started_typing.connect(func() -> void:
			if auto_hook_dialogue_labels and is_instance_valid(label):
				_register_active_dialogue_label(label, scope_opts)
		)

	label.tree_exited.connect(func() -> void:
		_attached_dialogue_labels.erase(id)
	, CONNECT_ONE_SHOT)

	if auto_hook_dialogue_labels and bool(label.get("is_typing")):
		_register_active_dialogue_label(label, scope_opts)


static func _register_active_dialogue_label(label: RichTextLabel, scope_opts: Dictionary) -> void:
	var scope := _get_or_create_scope(DIALOGUE_SCOPE, scope_opts)
	for existing in scope.items:
		if existing.get("kind", "") == "dialogue" and existing.get("label") == label and not bool(existing.get("done", false)):
			return

	var orig_step: float = float(label.get("seconds_per_step")) if "seconds_per_step" in label else 0.02
	var has_pause_step: bool = "seconds_per_pause_step" in label
	var orig_pause_step: float = float(label.get("seconds_per_pause_step")) if has_pause_step else 0.0

	var item := {
		"kind": "dialogue",
		"label": label,
		"orig_step": orig_step,
		"has_pause_step": has_pause_step,
		"orig_pause_step": orig_pause_step,
		"fast_forwarded": false,
		"restored": false,
		"duration_override": -1.0,
		"done": false,
	}
	scope.items.append(item)

	var finish_cb := func() -> void:
		_restore_dialogue_label(item)
		item["done"] = true

	if label.has_signal("finished_typing"):
		label.finished_typing.connect(finish_cb, CONNECT_ONE_SHOT)
	if label.has_signal("skipped_typing"):
		label.skipped_typing.connect(finish_cb, CONNECT_ONE_SHOT)


static func fast_forward_dialogue_label(label: RichTextLabel, duration: float = -1.0) -> bool:
	if not is_instance_valid(label) or not ("is_typing" in label) or not bool(label.get("is_typing")):
		return false
	var target_dur := dialogue_fast_forward_duration if duration < 0.0 else maxf(0.0, duration)
	if not _scopes.has(DIALOGUE_SCOPE):
		_register_active_dialogue_label(label, {
			"duration": target_dur,
			"snap_on_repeat": dialogue_snap_on_repeat,
			"priority": 100,
			"allow_when_dialogue_open": true,
		})
	var scope := _scopes[DIALOGUE_SCOPE] as ScopeState
	for item in scope.items:
		if item.get("kind", "") == "dialogue" and item.get("label") == label:
			return _fast_forward_item(item, target_dur, scope.snap_on_repeat)
	return false


static func trigger(scope_id: String = "", duration_override: float = -1.0) -> bool:
	if scope_id != "":
		var key := scope_id.strip_edges()
		if not _scopes.has(key):
			return false
		return _trigger_scope(_scopes[key] as ScopeState, duration_override)

	var best_scope: ScopeState = null
	for scope_key in _scopes.keys():
		var scope := _scopes[scope_key] as ScopeState
		_prune_scope(scope)
		if scope.items.is_empty():
			continue
		if best_scope == null or scope.priority > best_scope.priority:
			best_scope = scope

	if best_scope == null:
		return false
	return _trigger_scope(best_scope, duration_override)


static func _trigger_scope(scope: ScopeState, duration_override: float = -1.0) -> bool:
	_prune_scope(scope)
	if scope.items.is_empty():
		return false

	scope.triggered_auto = true
	var did_any := false
	var snapshot := scope.items.duplicate()
	for item in snapshot:
		var ff_dur := duration_override if duration_override >= 0.0 else _resolve_item_duration(scope, item)
		if _fast_forward_item(item, ff_dur, scope.snap_on_repeat):
			did_any = true
	_prune_scope(scope)
	return did_any


static func _resolve_item_duration(scope: ScopeState, item: Dictionary) -> float:
	var override_dur := float(item.get("duration_override", -1.0))
	if override_dur >= 0.0:
		return override_dur
	return scope.duration


static func _fast_forward_item(item: Dictionary, ff_duration: float, snap_on_repeat: bool) -> bool:
	if bool(item.get("done", false)):
		return false

	var already_ff := bool(item.get("fast_forwarded", false))
	if already_ff and not snap_on_repeat:
		return false

	var effective_dur := 0.0 if (already_ff and snap_on_repeat) else maxf(0.0, ff_duration)
	item["fast_forwarded"] = true

	match str(item.get("kind", "")):
		"tween":
			var tween := item.get("tween") as Tween
			if not is_instance_valid(tween) or not tween.is_valid():
				item["done"] = true
				return false
			var remaining := maxf(0.0, float(item["total_duration"]) - float(item["elapsed"]))
			if effective_dur <= 0.0:
				tween.custom_step(remaining + 1.0)
				if tween.is_valid() and tween.is_running():
					tween.custom_step(1000.0)
				item["done"] = true
			elif remaining > effective_dur:
				var new_scale := remaining / effective_dur
				tween.set_speed_scale(new_scale)
				item["speed_scale"] = new_scale
			return true

		"anim":
			var anim_player := item.get("player") as AnimationPlayer
			if not is_instance_valid(anim_player) or not anim_player.is_playing():
				_restore_animation_speed(item)
				item["done"] = true
				return false
			var anim_name: StringName = item["anim_name"]
			var anim := anim_player.get_animation(anim_name)
			if anim == null:
				_restore_animation_speed(item)
				item["done"] = true
				return false
			var playing_spd := anim_player.get_playing_speed()
			var abs_playing := absf(playing_spd)
			if abs_playing <= 0.0001:
				return false
			var anim_rem := maxf(0.0, anim.length - anim_player.current_animation_position) if playing_spd >= 0.0 else maxf(0.0, anim_player.current_animation_position)
			var real_rem := anim_rem / abs_playing
			if effective_dur <= 0.0:
				var end_pos := anim.length if playing_spd >= 0.0 else 0.0
				anim_player.seek(end_pos, true)
				anim_player.advance(0.001)
				_restore_animation_speed(item)
				item["done"] = true
			elif real_rem > effective_dur:
				var factor := real_rem / effective_dur
				anim_player.speed_scale *= factor
			return true

		"wait":
			var handle := item.get("handle") as WaitHandle
			if handle == null or handle.done:
				item["done"] = true
				return false
			handle.fast_forwarded = true
			if effective_dur <= 0.0:
				handle.complete()
				item["done"] = true
			else:
				handle.time_left = minf(handle.time_left, effective_dur)
			return true

		"dialogue":
			var label := item.get("label") as RichTextLabel
			if not is_instance_valid(label) or not bool(label.get("is_typing")):
				_restore_dialogue_label(item)
				item["done"] = true
				return false
			if effective_dur <= 0.0:
				if label.has_method("skip_typing"):
					label.call("skip_typing")
				_restore_dialogue_label(item)
				item["done"] = true
			else:
				var total_chars: int = label.get_total_character_count()
				var vis_chars: int = maxi(0, label.visible_characters)
				var rem_chars: int = maxi(1, total_chars - vis_chars)
				var orig_step: float = maxf(0.001, float(item.get("orig_step", 0.02)))
				var new_step := clampf(effective_dur / float(rem_chars), 0.001, orig_step)
				label.set("seconds_per_step", new_step)
				if bool(item.get("has_pause_step", false)):
					label.set("seconds_per_pause_step", 0.0)
				if "_waiting_seconds" in label:
					var wait_sec := float(label.get("_waiting_seconds"))
					if wait_sec > effective_dur:
						label.set("_waiting_seconds", effective_dur)
			return true

		"callable":
			var cb: Callable = item.get("callback", Callable())
			if cb.is_valid():
				cb.call(effective_dur)
			item["done"] = true
			return true

	return false


static func _restore_animation_speed(item: Dictionary) -> void:
	if bool(item.get("restored", false)):
		return
	item["restored"] = true
	var anim_player := item.get("player") as AnimationPlayer
	if is_instance_valid(anim_player):
		anim_player.speed_scale = float(item.get("orig_speed_scale", 1.0))


static func _restore_dialogue_label(item: Dictionary) -> void:
	if bool(item.get("restored", false)):
		return
	item["restored"] = true
	var label := item.get("label") as RichTextLabel
	if is_instance_valid(label):
		if "seconds_per_step" in label:
			label.set("seconds_per_step", float(item.get("orig_step", 0.02)))
		if bool(item.get("has_pause_step", false)) and "seconds_per_pause_step" in label:
			label.set("seconds_per_pause_step", float(item.get("orig_pause_step", 0.2)))


static func _prune_scope(scope: ScopeState) -> void:
	var i := scope.items.size() - 1
	while i >= 0:
		var item := scope.items[i]
		var remove := bool(item.get("done", false))
		if not remove:
			match str(item.get("kind", "")):
				"tween":
					var tween := item.get("tween") as Tween
					if not is_instance_valid(tween) or not tween.is_valid():
						remove = true
				"anim":
					var anim_player := item.get("player") as AnimationPlayer
					if not is_instance_valid(anim_player) or not anim_player.is_playing() or anim_player.current_animation != item["anim_name"]:
						_restore_animation_speed(item)
						remove = true
				"wait":
					var handle := item.get("handle") as WaitHandle
					if handle == null or handle.done:
						remove = true
					elif handle.host != null and (not is_instance_valid(handle.host) or not handle.host.is_inside_tree()):
						handle.complete()
						remove = true
				"dialogue":
					var label := item.get("label") as RichTextLabel
					if not is_instance_valid(label) or not label.is_inside_tree() or not bool(label.get("is_typing")):
						_restore_dialogue_label(item)
						remove = true
		if remove:
			scope.items.remove_at(i)
		i -= 1


class FastForwardRuntime extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -90
		var tree := get_tree()
		if not tree:
			return
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		if tree.root:
			_scan_for_dialogue_labels(tree.root)

	func _scan_for_dialogue_labels(root: Node) -> void:
		_on_node_added(root)
		for child in root.get_children():
			_scan_for_dialogue_labels(child)

	func _on_node_added(node: Node) -> void:
		if not is_instance_valid(node):
			return
		if node is RichTextLabel and node.has_signal("started_typing") and "is_typing" in node:
			FastForward.attach_dialogue_label(node as RichTextLabel)

	func _process(delta: float) -> void:
		var tree := get_tree()
		var paused := tree != null and tree.paused
		var unscaled_delta := delta / maxf(Engine.time_scale, 0.0001)

		var keys := FastForward._scopes.keys()
		for scope_key in keys:
			if not FastForward._scopes.has(scope_key):
				continue
			var scope := FastForward._scopes[scope_key] as ScopeState
			if paused and not scope.allow_when_paused:
				continue

			for item in scope.items:
				if bool(item.get("done", false)):
					continue
				match str(item.get("kind", "")):
					"tween":
						var tween := item.get("tween") as Tween
						if is_instance_valid(tween) and tween.is_valid() and tween.is_running():
							item["elapsed"] = float(item["elapsed"]) + delta * float(item["speed_scale"])
					"wait":
						var handle := item.get("handle") as WaitHandle
						if handle and not handle.done:
							var step_dt := unscaled_delta if handle.ignore_time_scale else delta
							handle.time_left -= step_dt
							if handle.time_left <= 0.0:
								handle.complete()
								item["done"] = true

			FastForward._prune_scope(scope)

	func _input(event: InputEvent) -> void:
		if FastForward._scopes.is_empty():
			return
		if not _is_valid_input_event(event):
			return
		if _is_blocked_globally(event):
			return

		var tree := get_tree()
		var root := tree.root if tree else null
		var gs := root.get_node_or_null("GameState") if root else null
		var dialogue_open: bool = bool(gs.get("is_dialogue_open")) if (gs and "is_dialogue_open" in gs) else false
		var paused: bool = tree != null and tree.paused

		var candidates: Array[ScopeState] = []
		for scope_key in FastForward._scopes.keys():
			var scope := FastForward._scopes[scope_key] as ScopeState
			FastForward._prune_scope(scope)
			if scope.items.is_empty():
				continue
			if paused and not scope.allow_when_paused:
				continue
			if dialogue_open and not scope.allow_when_dialogue_open:
				continue
			if scope.ignore_over_buttons and _is_pointer_over_interactive_control(event):
				continue
			if _event_matches_scope(event, scope):
				candidates.append(scope)

		if candidates.is_empty():
			return

		candidates.sort_custom(func(a: ScopeState, b: ScopeState) -> bool:
			return a.priority > b.priority
		)

		for scope in candidates:
			if FastForward._trigger_scope(scope):
				if scope.consume_input:
					get_viewport().set_input_as_handled()
				return

	func _is_valid_input_event(event: InputEvent) -> bool:
		if event is InputEventMouseButton:
			return event.is_pressed() and not event.is_echo()
		if event is InputEventKey:
			return event.is_pressed() and not event.is_echo()
		return false

	func _event_matches_scope(event: InputEvent, scope: ScopeState) -> bool:
		if event is InputEventMouseButton:
			if scope.trigger_mouse_buttons.has((event as InputEventMouseButton).button_index):
				return true
		for act in scope.trigger_actions:
			if InputMap.has_action(act) and event.is_action_pressed(act):
				return true
		return false

	func _is_blocked_globally(event: InputEvent) -> bool:
		var tree := get_tree()
		if not tree or not tree.root:
			return false

		var ss := tree.root.get_node_or_null("SettingState")
		if ss and "waiting_keybind" in ss and bool(ss.get("waiting_keybind")):
			return true

		var gs := tree.root.get_node_or_null("GameState")
		if gs:
			var pause_menu := gs.get("pause_menu") as CanvasLayer
			if is_instance_valid(pause_menu) and pause_menu.visible:
				return true
			var debug_menu := gs.get("debug_menu") as CanvasLayer
			if is_instance_valid(debug_menu) and debug_menu.visible and event is InputEventMouseButton:
				var box := debug_menu.get_node_or_null("TextureRect") as Control
				if is_instance_valid(box) and box.get_global_rect().has_point(get_viewport().get_mouse_position()):
					return true
		return false

	func _is_pointer_over_interactive_control(event: InputEvent) -> bool:
		if not (event is InputEventMouseButton):
			return false
		var cur: Node = get_viewport().gui_get_hovered_control()
		while cur is Control:
			if (
				cur is BaseButton
				or cur is Range
				or cur is LineEdit
				or cur is TextEdit
				or cur is ItemList
				or cur is Tree
				or cur is TabBar
			):
				return true
			if (cur as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				break
			cur = cur.get_parent()
		return false