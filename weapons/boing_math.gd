extends RefCounted
# bounce math for all the ricochet weapons. moves a lil projectile n bounces it
# off walls (layer 1), same way the disk bounces
#
# how to use:  var r = Boing.step(space, pos, vel, delta)
#              pos = r[0]   vel = r[1]   how many bounces this frame = r[2]


static func step(space: PhysicsDirectSpaceState2D, pos: Vector2, vel: Vector2, delta: float) -> Array:
	var remaining: float = vel.length() * delta
	var bounces: int = 0
	# a fast shot can hit two walls in one frame (into a corner), so allow a few bounces
	for i in 3:
		if remaining <= 0.0:
			break
		var dir := vel.normalized()
		var query := PhysicsRayQueryParameters2D.create(pos, pos + dir * remaining, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			pos += dir * remaining
			break
		var hit_pos: Vector2 = hit["position"]
		var normal: Vector2 = hit["normal"]
		remaining -= pos.distance_to(hit_pos)
		pos = hit_pos + normal * 0.5      # step off the wall so we dont hit it again
		vel = vel.bounce(normal)
		bounces += 1
	return [pos, vel, bounces]


static func nearest_enemy(tree: SceneTree, from: Vector2, max_dist: float):
	var best = null
	var best_dist: float = max_dist
	for enemy in tree.get_nodes_in_group("enemies"):
		var d: float = enemy.global_position.distance_to(from)
		if d < best_dist:
			best = enemy
			best_dist = d
	return best
