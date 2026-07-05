extends Node

# Level's TileMap, found via the navigation_tilemap group
var tile_map: TileMap

var astar_grid: AStarGrid2D

const CELL_SIZE: int = 32  # assumes 32px tiles

func _ready():
	# Wait a frame for the TileMap to be ready
	await get_tree().process_frame
	refresh()

# Autoloads survive get_tree().reload_current_scene(), but the old TileMap
# does not, so this must be called again (from the new Level's _ready)
# whenever the scene reloads, or tile_map/astar_grid go stale.
func refresh():
	tile_map = get_tree().get_first_node_in_group("navigation_tilemap")
	setup_astar_grid()

func setup_astar_grid():
	if not tile_map:
		print("PathfindingManager: TileMap not found!")
		return

	var used_rect = tile_map.get_used_rect()
	if used_rect == Rect2i():
		print("PathfindingManager: TileMap has no cells defined!")
		return

	astar_grid = AStarGrid2D.new()
	astar_grid.region = used_rect
	astar_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar_grid.offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)  # Center paths on tiles
	astar_grid.update()

	# Tiles carry no walkability data (ground art only). Mark solid cells from
	# wall collision shapes instead, same approach as Level.gd's navmesh carving.
	var solid_count := 0
	for wall in get_tree().get_nodes_in_group("walls"):
		for child in wall.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var rect_shape := child.shape as RectangleShape2D
				var shape_center: Vector2 = child.global_position
				var world_scale: Vector2 = wall.global_transform.get_scale()
				var half_ext: Vector2 = (rect_shape.size / 2.0) * world_scale

				var top_left: Vector2 = shape_center - half_ext
				var bottom_right: Vector2 = shape_center + half_ext
				var grid_top_left: Vector2i = tile_map.local_to_map(tile_map.to_local(top_left))
				var grid_bottom_right: Vector2i = tile_map.local_to_map(tile_map.to_local(bottom_right))

				for x in range(grid_top_left.x, grid_bottom_right.x + 1):
					for y in range(grid_top_left.y, grid_bottom_right.y + 1):
						var cell := Vector2i(x, y)
						if astar_grid.is_in_boundsv(cell) and not astar_grid.is_point_solid(cell):
							astar_grid.set_point_solid(cell, true)
							solid_count += 1

	print("AStarGrid2D initialized. Region: ", astar_grid.region, " | Solid points: ", solid_count)

func get_world_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not astar_grid:
		return PackedVector2Array()

	var from_grid = tile_map.local_to_map(tile_map.to_local(from))
	var to_grid = tile_map.local_to_map(tile_map.to_local(to))

	var path = astar_grid.get_point_path(from_grid, to_grid)
	if path.is_empty():
		print("PathfindingManager: No path found from ", from, " to ", to)

	return path
