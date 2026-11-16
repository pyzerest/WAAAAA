extends RefCounted
# the whole maze but as big flat arrays (index = y * width + x) bc the map is HUGE now
# like 100k cells. enemies use this to find u, also spawning, boost pads, the race n the lil map

# map = wobbly rings around the middle, corridors get wider the further out u go
# these numbers gotta match the map so dont mess w them unless the map changes
const MAP_CENTER = Vector2i(21, -3)
const ZONE_RADII = [24, 44, 66, 92, 124, 158]
const ZONE_NAMES = ["THE CORE", "THE NARROWS", "THE ALLEYS", "THE STREETS", "THE AVENUES", "THE OPEN"]
const ZONE_FLOOR = [Color(0.16, 0.16, 0.19), Color(0.12, 0.15, 0.24), Color(0.17, 0.17, 0.19),
	Color(0.12, 0.19, 0.13), Color(0.22, 0.16, 0.10), Color(0.17, 0.11, 0.17)]
const ZONE_WALL = [Color(0.6, 0.6, 0.65), Color(0.35, 0.5, 0.9), Color(0.55, 0.55, 0.6),
	Color(0.3, 0.65, 0.3), Color(0.85, 0.5, 0.2), Color(0.5, 0.3, 0.5)]

var tilemap: TileMapLayer
var rect: Rect2i
var w: int = 0
var h: int = 0
var solid := PackedByteArray()   # 1 = wall tile
var walk := PackedByteArray()    # 1 = floor u can reach from the start
var zone := PackedByteArray()    # which ring each cell is in
var zone_cells = []              # zone -> array of walkable cell indexes
var flow := PackedInt32Array()   # steps from u (-1 = not reached this pass)
var reached := PackedInt32Array()   # cells the last flow pass reached, in BFS order
var reached_count: int = 0


func setup(map: TileMapLayer, start: Vector2i) -> void:
	tilemap = map
	rect = map.get_used_rect()
	w = rect.size.x
	h = rect.size.y
	var n := w * h
	solid.resize(n)
	solid.fill(0)
	for c in map.get_used_cells():
		solid[index(c)] = 1
	zone.resize(n)
	for i in n:
		zone[i] = zone_of_cell(cell_at(i))
	walk.resize(n)
	walk.fill(0)
	flow.resize(n)
	flow.fill(-1)
	reached.resize(n)
	zone_cells = []
	for k in ZONE_RADII.size():
		zone_cells.append([])

	# flood fill from the start thru floor cells
	var s := index(start)
	if s < 0 or solid[s] == 1:
		push_warning("player doesn't start on an open floor cell")
		return
	var queue := PackedInt32Array()
	queue.resize(n)
	walk[s] = 1
	queue[0] = s
	var head := 0
	var tail := 1
	while head < tail:
		var i: int = queue[head]
		head += 1
		zone_cells[zone_of_index(i)].append(i)
		var x: int = i % w
		for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
			if j >= 0 and j < n and solid[j] == 0 and walk[j] == 0:
				walk[j] = 1
				queue[tail] = j
				tail += 1


# ---------- cells <-> positions ----------

func index(cell: Vector2i) -> int:
	var x := cell.x - rect.position.x
	var y := cell.y - rect.position.y
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


func cell_at(i: int) -> Vector2i:
	return Vector2i(i % w + rect.position.x, i / w + rect.position.y)


func cell_of(world_pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(world_pos))


func center_of(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))


func index_of(world_pos: Vector2) -> int:
	return index(cell_of(world_pos))


func is_walk(i: int) -> bool:
	return i >= 0 and walk[i] == 1


func zone_of_cell(cell: Vector2i) -> int:
	if cell.x >= -1 and cell.x <= 42 and cell.y >= -21 and cell.y <= 16:
		return 0   # my og maze in the middle
	# a wobbly "radius": half square, half circle, plus a couple of sine wobbles
	var dx := float(cell.x - MAP_CENTER.x)
	var dy := float(cell.y - MAP_CENTER.y)
	var ang := atan2(dy, dx)
	var r: float = 0.55 * max(abs(dx), abs(dy)) + 0.45 * sqrt(dx * dx + dy * dy) 		+ 3.0 * sin(3.0 * ang + 0.8) + 2.0 * sin(7.0 * ang + 2.1)
	for k in ZONE_RADII.size():
		if r <= ZONE_RADII[k]:
			return k
	return ZONE_RADII.size() - 1


func zone_of_index(i: int) -> int:
	return zone[i]


func has_room(i: int, r: int) -> bool:
	# every cell within r steps (a square) is floor - room for smth big
	var c := cell_at(i)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if not is_walk(index(c + Vector2i(dx, dy))):
				return false
	return true


# ---------- enemy pathfinding ----------

func build_flow(from: Vector2i, radius: int) -> void:
	# breadth-first search out from u, but only inside a box around them
	# (enemies further out just head straight for u until they get close)
	for t in reached_count:
		flow[reached[t]] = -1
	reached_count = 0
	var s := index(from)
	if not is_walk(s):
		return
	var fx := s % w
	var fy := s / w
	var x0: int = max(0, fx - radius)
	var x1: int = min(w - 1, fx + radius)
	var y0: int = max(0, fy - radius)
	var y1: int = min(h - 1, fy + radius)
	flow[s] = 0
	reached[0] = s
	reached_count = 1
	var head := 0
	while head < reached_count:
		var i: int = reached[head]
		head += 1
		var d: int = flow[i] + 1
		var x: int = i % w
		var y: int = i / w
		if x > x0 and walk[i - 1] == 1 and flow[i - 1] < 0:
			flow[i - 1] = d
			reached[reached_count] = i - 1
			reached_count += 1
		if x < x1 and walk[i + 1] == 1 and flow[i + 1] < 0:
			flow[i + 1] = d
			reached[reached_count] = i + 1
			reached_count += 1
		if y > y0 and walk[i - w] == 1 and flow[i - w] < 0:
			flow[i - w] = d
			reached[reached_count] = i - w
			reached_count += 1
		if y < y1 and walk[i + w] == 1 and flow[i + w] < 0:
			flow[i + w] = d
			reached[reached_count] = i + w
			reached_count += 1


func next_step(i: int) -> int:
	# the neighbouring cell thats one step closer to u, or -1
	if i < 0 or flow[i] <= 1:
		return -1
	var best := -1
	var best_d: int = flow[i]
	for j in [i - 1, i + 1, i - w, i + w]:
		if j >= 0 and j < flow.size() and flow[j] >= 0 and flow[j] < best_d:
			best = j
			best_d = flow[j]
	return best


func path_distances(from: Vector2i) -> PackedInt32Array:
	# steps from one cell to every reachable cell (used once to pick the speedrun finish)
	var n := w * h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var s := index(from)
	if not is_walk(s):
		return dist
	var queue := PackedInt32Array()
	queue.resize(n)
	dist[s] = 0
	queue[0] = s
	var head := 0
	var tail := 1
	while head < tail:
		var i: int = queue[head]
		head += 1
		var x: int = i % w
		for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
			if j >= 0 and j < n and walk[j] == 1 and dist[j] < 0:
				dist[j] = dist[i] + 1
				queue[tail] = j
				tail += 1
	return dist


# ---------- pictures of the map ----------

func make_image(for_minimap: bool) -> Image:
	# one pixel per cell, floor (for the world background) or a coloured map (minimap)
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for i in w * h:
		var c: Color
		var z := zone_of_index(i)
		if for_minimap:
			if solid[i] == 1:
				c = ZONE_WALL[z]
			elif walk[i] == 1:
				c = ZONE_FLOOR[z].darkened(0.3)
			else:
				c = Color(0, 0, 0, 0)
		else:
			if walk[i] == 1:
				var x: int = i % w
				var y: int = i / w
				# blotchy, uneven floor (like paint/pencil shading, not a perfect grid)
				var blotch: float = 0.035 * sin(x * 0.21 + sin(y * 0.13) * 2.0) + 0.025 * sin(y * 0.27 + x * 0.05)
				var grain: float = fmod(abs(sin(x * 12.9898 + y * 78.233) * 43758.5453), 1.0) * 0.025
				c = ZONE_FLOOR[z].lightened(clamp(0.03 + blotch + grain, 0.0, 0.2))
			else:
				c = Color(0.05, 0.05, 0.06)
		data[i * 4] = int(c.r * 255.0)
		data[i * 4 + 1] = int(c.g * 255.0)
		data[i * 4 + 2] = int(c.b * 255.0)
		data[i * 4 + 3] = int(c.a * 255.0)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
