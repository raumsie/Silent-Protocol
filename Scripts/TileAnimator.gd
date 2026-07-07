extends Node

# Cycles TileMapLayer cells through pre-drawn animation frames that already
# exist as ordinary tiles in the atlas (painted side by side), instead of
# using TileSet's tile animation. The atlas already has independent
# tiles registered across those frame columns, which Godot's
# animation feature refuses to build on top of.
#
# Any cell in `layer` whose current atlas tile falls inside a group's frame-0
# footprint (rows/cols below) is picked up automatically, so placing more
# copies of an animated prop never needs extra setup here.

@export var layer: TileMapLayer
@export var source_id: int = 0

class AnimGroup:
	var rows: Array
	var cols: Array
	var frame_count: int
	var frame_stride: Vector2i
	var fps: float

	func _init(r: Array, c: Array, fc: int, stride: Vector2i, speed: float) -> void:
		rows = r
		cols = c
		frame_count = fc
		frame_stride = stride
		fps = speed

var _groups: Array = [
	AnimGroup.new([6, 7, 8], [0, 1, 2], 4, Vector2i(3, 0), 4.0),          # computer
	AnimGroup.new([19, 20, 21, 22, 23], [0, 1, 2], 4, Vector2i(3, 0), 3.0), # cross vat
	AnimGroup.new([25, 26, 27, 28, 29], [0, 1, 2], 4, Vector2i(3, 0), 3.0), # plain vat
]

var _tracked: Array = []
var _elapsed := 0.0

func _ready() -> void:
	if not layer:
		return
	for cell in layer.get_used_cells():
		if layer.get_cell_source_id(cell) != source_id:
			continue
		var coord: Vector2i = layer.get_cell_atlas_coords(cell)
		for group in _groups:
			if coord.y in group.rows and coord.x in group.cols:
				_tracked.append({"cell": cell, "base": coord, "group": group})
				break

func _process(delta: float) -> void:
	if _tracked.is_empty():
		return
	_elapsed += delta
	for entry in _tracked:
		var group = entry["group"]
		var frame: int = int(_elapsed * group.fps) % group.frame_count
		var new_coord: Vector2i = entry["base"] + group.frame_stride * frame
		layer.set_cell(entry["cell"], source_id, new_coord, 0)
