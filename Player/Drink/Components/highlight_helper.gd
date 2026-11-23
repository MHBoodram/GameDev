class_name HighlightHelper
extends RefCounted

# mouse-hover highlights

var _original_modulates: Dictionary = {}
var _highlight_visuals: Array[Node] = []
var _explicit_highlight: Node3D = null

func cache_visual_nodes(owner_node: Node3D) -> void:
	_explicit_highlight = owner_node.get_node_or_null("Inside/highlight")
	if not _explicit_highlight:
		_explicit_highlight = owner_node.get_node_or_null("highlight")
	if _explicit_highlight:
		return

	_highlight_visuals.clear()
	for child_name in ["Inside", "Sprite3D", "PaperMesh", "Base_viewport"]:
		var node := owner_node.get_node_or_null(child_name)
		if node:
			_highlight_visuals.append(node)
	if _highlight_visuals.is_empty():
		for child in owner_node.get_children():
			if child is Sprite3D or child is MeshInstance3D:
				_highlight_visuals.append(child)

func setup_render_priority(owner_node: Node3D) -> void:
	for node in owner_node.find_children("*", "VisualInstance3D", true, false):
		if node is Sprite3D:
			node.render_priority = 1
		elif node is GeometryInstance3D:
			node.sorting_offset = 1.0
	var outside := owner_node.get_node_or_null("Inside/Outside")
	if outside and outside is Sprite3D:
		outside.render_priority = 2
	if _explicit_highlight and _explicit_highlight is Sprite3D:
		_explicit_highlight.render_priority = 3

func set_highlight(enabled: bool) -> void:
	if _explicit_highlight:
		_explicit_highlight.visible = enabled
		return

	for visual in _highlight_visuals:
		if not is_instance_valid(visual):
			continue
		var node_id := visual.get_instance_id()
		if enabled:
			if visual is Sprite3D:
				if not _original_modulates.has(node_id):
					_original_modulates[node_id] = visual.modulate
				visual.modulate = _original_modulates[node_id] * Color(1.5, 1.5, 0.4, 1.0)
			elif visual is MeshInstance3D:
				if not _original_modulates.has(node_id):
					_original_modulates[node_id] = visual.scale
				visual.scale = _original_modulates[node_id] * Vector3(1.15, 1.15, 1.15)
		else:
			if _original_modulates.has(node_id):
				if visual is Sprite3D:
					visual.modulate = _original_modulates[node_id]
				elif visual is MeshInstance3D:
					visual.scale = _original_modulates[node_id]
				_original_modulates.erase(node_id)