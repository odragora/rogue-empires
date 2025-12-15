class_name DualMesh
extends RefCounted

# -- Constants --
const _halfedges_start_size := 128

# -- Data Arrays --
# r = region (point), s = side (edge), t = triangle
var num_sides: int = 0
var num_regions: int = 0
var num_triangles: int = 0
var num_solid_sides: int = 0

# Primary data structures (TypedArrays for performance in Godot 4)
var _r_vertex: PackedVector2Array # Position of region r
var _triangles: PackedInt32Array  # s -> r (which region this side begins at)
var _halfedges: PackedInt32Array  # s -> s (opposite side)
var _t_vertex: PackedVector2Array # Position of triangle t (circumcenters)

# Index to find a starting side for a region
var _s_start_r: PackedInt32Array

# -- Initialization --
func create(points: PackedVector2Array) -> void:
	_r_vertex = points
	num_regions = points.size()
	
	# 1. Triangulate using Godot's built-in geometry engine
	# Returns indices [p0, p1, p2, p0, p1, p2...]
	var raw_triangles = Geometry2D.triangulate_delaunay(points)
	
	# 2. Convert raw triangles to Half-Edge structure
	# In Half-Edge, every triangle has 3 sides. 
	# s maps to triangle index t = floor(s/3)
	num_sides = raw_triangles.size()
	num_triangles = int(num_sides / 3)
	
	_triangles = raw_triangles
	_halfedges = PackedInt32Array()
	_halfedges.resize(num_sides)
	_halfedges.fill(-1)
	
	_calculate_halfedges()
	_calculate_triangle_centers()
	_calculate_region_start_sides()
	
	num_solid_sides = num_sides # We aren't adding ghost structures in this port for simplicity, boundary is handled by checks

# -- internal Builders --

func _calculate_halfedges() -> void:
	# Use a dictionary to map unique edge keys to side indices
	# Key: "min_max", Value: side_index
	var edge_map = {}
	
	for s in range(num_sides):
		var start = _triangles[s]
		var end = _triangles[s_next_s(s)]
		
		# Create a unique key for the edge regardless of direction
		var key = Vector2i(min(start, end), max(start, end))
		
		if edge_map.has(key):
			var opposite_s = edge_map[key]
			_halfedges[s] = opposite_s
			_halfedges[opposite_s] = s
		else:
			edge_map[key] = s

func _calculate_triangle_centers() -> void:
	_t_vertex.resize(num_triangles)
	for t in range(num_triangles):
		var s = 3 * t
		var a = _r_vertex[_triangles[s]]
		var b = _r_vertex[_triangles[s + 1]]
		var c = _r_vertex[_triangles[s + 2]]
		# Centroid is good enough for map generation visual centers
		_t_vertex[t] = (a + b + c) / 3.0

func _calculate_region_start_sides() -> void:
	_s_start_r.resize(num_regions)
	_s_start_r.fill(-1)
	for s in range(num_sides):
		var r = _triangles[s]
		if _s_start_r[r] == -1:
			_s_start_r[r] = s

# -- Navigation Helpers (The "Algebra" of the Dual Mesh) --

# Triangle of side s
func t_from_s(s: int) -> int:
	return int(s / 3)

# Previous side in triangle
func s_prev_s(s: int) -> int:
	return s + 2 if (s % 3 == 0) else s - 1

# Next side in triangle
func s_next_s(s: int) -> int:
	return s - 2 if (s % 3 == 2) else s + 1

# Region at beginning of side s
func r_begin_s(s: int) -> int:
	return _triangles[s]

# Region at end of side s
func r_end_s(s: int) -> int:
	return _triangles[s_next_s(s)]

# Triangle inner (adjacent to side s inside its triangle)
func t_inner_s(s: int) -> int:
	return t_from_s(s)

# Triangle outer (adjacent to side s across the edge)
func t_outer_s(s: int) -> int:
	var opp = _halfedges[s]
	if opp == -1: return -1
	return t_from_s(opp)

# Get all regions neighboring region r
func r_circulate_r(out_regions: Array, r: int) -> void:
	var s0 = _s_start_r[r]
	if s0 == -1: return
	
	var incoming = s0
	while true:
		out_regions.append(r_begin_s(incoming))
		var outgoing = s_next_s(incoming)
		var opp = _halfedges[outgoing]
		if opp == -1: break # Boundary reached
		incoming = opp
		if incoming == s0: break

# Get all triangles neighboring region r (the corners of the voronoi cell)
func t_circulate_r(out_triangles: Array, r: int) -> void:
	var s0 = _s_start_r[r]
	if s0 == -1: return
	
	var incoming = s0
	while true:
		out_triangles.append(t_from_s(incoming))
		var outgoing = s_next_s(incoming)
		var opp = _halfedges[outgoing]
		if opp == -1: break
		incoming = opp
		if incoming == s0: break

# -- Data Accessors --

func r_pos(r: int) -> Vector2:
	return _r_vertex[r]

func t_pos(t: int) -> Vector2:
	return _t_vertex[t]