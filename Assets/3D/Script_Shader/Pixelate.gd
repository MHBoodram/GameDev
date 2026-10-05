@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	var mat := load("res://drink_material.tres") as Material
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = mat
	return scene
