extends Control
## Flyntic Studio — Godot Drone Assembly & Simulation
## Ported from web demo (Three.js) with full physics preview

# ──────────────────────────── NODE REFS ────────────────────────────
# These paths EXACTLY match Main.tscn node tree

# Left sidebar
@onready var comp_list: ItemList = $Root/Content/Left/CompPanel/V/CompList
@onready var hier_tree: Tree   = $Root/Content/Left/HierarchyPanel/V/Tree
@onready var hier_del_btn: Button = $Root/Content/Left/HierarchyPanel/V/H/DelBtn

# 3D scene nodes
@onready var scene_root: Node3D     = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene
@onready var pivot: Node3D           = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Pivot
@onready var camera: Camera3D        = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Pivot/Camera
@onready var components_group: Node3D = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Components
@onready var snap_hints: Node3D      = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/SnapHints
@onready var wires_group: Node3D     = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Components/Wires
@onready var viewport: SubViewport   = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP

# Console & monitors
@onready var log_box: RichTextLabel = $Root/Content/CenterRight/Center/Console/V/Log
@onready var weight_val: Label = $Root/Content/CenterRight/Right/Scroll/V/Perf/Weight/Val
@onready var thrust_val: Label = $Root/Content/CenterRight/Right/Scroll/V/Perf/Thrust/Val
@onready var twr_val: Label    = $Root/Content/CenterRight/Right/Scroll/V/Perf/TWR/Val
@onready var cap_val: Label    = $Root/Content/CenterRight/Right/Scroll/V/Perf/Capability/Val
@onready var bat_val: Label    = $Root/Content/CenterRight/Right/Scroll/V/Power/Battery/Val
@onready var ft_val: Label     = $Root/Content/CenterRight/Right/Scroll/V/Power/FlightTime/Val
@onready var diag_text: RichTextLabel = $Root/Content/CenterRight/Right/Scroll/V/Diag/DiagText
@onready var comp_count: Label = $Root/StatusBar/H/Comp
@onready var tabs: TabContainer = $Root/Content/CenterRight/Center/Tabs
@onready var console_panel: Panel = $Root/Content/CenterRight/Center/Console
@onready var vpc: SubViewportContainer = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC

# Blocks UI
@onready var workspace: Panel = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Workspace
@onready var toolbox: Panel = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Toolbox
@onready var toolbox_v: VBoxContainer = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Toolbox/V
@onready var block_script = preload("res://Block.gd")

# Simulation buttons
@onready var play_btn: Button  = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/PlayBtn
@onready var pause_btn: Button = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/PauseBtn
@onready var stop_btn: Button  = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/StopBtn
@onready var sim_label: Label  = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/StatusLbl
@onready var topbar_status: Label = $Root/TopBar/H/Status

# Scale factors for components
const OBJ_SCALE := 0.01 # convert mm to Godot units

# Physics bridge
var bridge: Node = null
var bridge_connected := false
var use_bridge_physics := true  # Set false to force kinematic fallback

var CATEGORIES := {
	"FRAME": ["PVC Pipe Frame", "Carbon Fiber Body"],
	"MOTOR": ["Motor 2205 2300KV", "Motor 2207 2400KV", "Motor 2212 920KV"],
	"PROPELLER": ["Propeller 5045", "Propeller 6045"],
	"BATTERY": ["Lipo 4S 1500mAh"],
	"ELECTRONICS": ["F4 Flight Controller", "4-in-1 ESC"],
}

var COMPONENTS := {
	"PVC Pipe Frame": {
		"type": "Frame", "weight": 250, "thrust": 0, "capacity": 0,
		"color": Color(0.9, 0.9, 0.85),
		"use_obj": true, "obj_path": "res://Components/quad_pvc_frame.obj",
		"ports": [
			{"name": "fl", "pos": Vector3(2.28, 2.01, 2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "fr", "pos": Vector3(2.28, 2.01, -2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "bl", "pos": Vector3(-2.28, 2.01, 2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "br", "pos": Vector3(-2.28, 2.01, -2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "center_top", "pos": Vector3(0, 1.8, 0), "slot": true, "allowed": ["FC", "ESC"]},
			{"name": "center_bot", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Battery"]},
		]
	},
	"Carbon Fiber Body": {
		"type": "Frame", "weight": 180, "thrust": 0, "capacity": 0,
		"color": Color(0.4, 0.4, 0.42),
		"use_obj": false,
		"ports": [
			{"name": "fl", "pos": Vector3(2, 1.5, 2), "slot": true, "allowed": ["Motor"]},
			{"name": "fr", "pos": Vector3(2, 1.5, -2), "slot": true, "allowed": ["Motor"]},
			{"name": "bl", "pos": Vector3(-2, 1.5, 2), "slot": true, "allowed": ["Motor"]},
			{"name": "br", "pos": Vector3(-2, 1.5, -2), "slot": true, "allowed": ["Motor"]},
			{"name": "center", "pos": Vector3(0, 1.0, 0), "slot": true, "allowed": ["FC", "Battery", "ESC"]},
		]
	},
	"Motor 2205 2300KV": {
		"type": "Motor", "weight": 35, "thrust": 850, "capacity": 0,
		"color": Color(0.6, 0.25, 0.25),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Motor 2207 2400KV": {
		"type": "Motor", "weight": 42, "thrust": 1100, "capacity": 0,
		"color": Color(0.25, 0.45, 0.8),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Motor 2212 920KV": {
		"type": "Motor", "weight": 56, "thrust": 980, "capacity": 0,
		"color": Color(0.8, 0.55, 0.1),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Propeller 5045": {
		"type": "Propeller", "weight": 8, "thrust": 0, "capacity": 0,
		"color": Color(0.8, 0.1, 0.1), "ports": []
	},
	"Propeller 6045": {
		"type": "Propeller", "weight": 12, "thrust": 0, "capacity": 0,
		"color": Color(0.1, 0.1, 0.8), "ports": []
	},
	"Lipo 4S 1500mAh": {
		"type": "Battery", "weight": 185, "thrust": 0, "capacity": 1500,
		"color": Color(0.85, 0.7, 0.15), "ports": []
	},
	"F4 Flight Controller": {
		"type": "FC", "weight": 7, "thrust": 0, "capacity": 0,
		"color": Color(0.0, 0.35, 0.0), "ports": []
	},
	"4-in-1 ESC": {
		"type": "ESC", "weight": 15, "thrust": 0, "capacity": 0,
		"color": Color(0.0, 0.0, 0.5), "ports": []
	},
}

# Runtime state
var placed: Array[Dictionary] = []
var wires_data: Array[Dictionary] = []
var ghost: Node3D = null
var cur_id := ""
var ghost_rot := 0.0
var orbiting := false
var panning := false
var zoom := 12.0
var camera_rot := Vector2(-0.5, 0.0) # Vertical (X) and Horizontal (Y) rotation
var sim_state := "stopped" # stopped | playing | paused
var sim_time := 0.0
var sim_sequence: Array[Dictionary] = []
var sim_step_idx := 0
var sim_step_timer := 0.0
var sim_target_pos := Vector3.ZERO
var sim_target_rot := Vector3.ZERO
var trash_panel: Panel = null

# ──────────────────────────── INIT ────────────────────────────────
func _ready():
	_build_comp_list()
	_build_floor()
	_build_grid()
	_place("PVC Pipe Frame", Vector3.ZERO)
	_update_all()
	play_btn.pressed.connect(_on_play)
	pause_btn.pressed.connect(_on_pause)
	stop_btn.pressed.connect(_on_stop)
	comp_list.item_selected.connect(_on_item_selected)
	hier_tree.item_selected.connect(_on_hier_item_selected)
	hier_del_btn.pressed.connect(_remove_selected)
	_setup_blocks()
	_create_trash_zone()
	# Pre-populate workspace with a standard 'When flag clicked' stack
	_create_block("start", "When ⚐ clicked", Color(0.85, 0.65, 0), Vector2(50, 50))
	# Initialize physics bridge
	_init_bridge()
	_log("Flyntic Studio initialized", "success")

func _init_bridge():
	var bridge_script = load("res://PhysicsBridge.gd")
	if bridge_script == null:
		_log("PhysicsBridge.gd not found — kinematic mode only", "warning")
		return
	bridge = Node.new()
	bridge.set_script(bridge_script)
	bridge.name = "PhysicsBridge"
	add_child(bridge)
	bridge.bridge_connected.connect(_on_bridge_connected)
	bridge.bridge_disconnected.connect(_on_bridge_disconnected)
	bridge.state_received.connect(_on_bridge_state)
	_log("Physics bridge initialized — connecting to TCP server...", "info")

func _on_bridge_connected():
	bridge_connected = true
	_log("Bridge: Connected (" + bridge.bridge_mode + " mode)", "success")

func _on_bridge_disconnected():
	bridge_connected = false
	_log("Bridge: Disconnected — using kinematic fallback", "warning")

func _setup_blocks():
	# Wire up toolbox buttons to spawn blocks
	for child in toolbox_v.get_children():
		if is_instance_valid(child) and (child is Button or child is Panel):
			child.gui_input.connect(_on_toolbox_input.bind(child))

func _on_toolbox_input(event, node):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var type = node.name.to_lower()
		var label = ""
		var color = Color(1, 0.7, 0)
		
		match type:
			"b1": # Events
				label = "When ⚐ clicked"
				type = "start"
			"bt1": # Take off
				label = "Take Off"
				type = "take_off"
				color = Color(0.3, 0.6, 1.0)
			"bm1": # Forward
				label = "Forward [ 50 ] cm"
				type = "forward"
				color = Color(0.25, 0.55, 0.95)
			"bm2": # Hover
				label = "Hover (2s)"
				type = "hover"
				color = Color(0.2, 0.5, 0.9)
			"bl1": # Land
				label = "Land drone"
				type = "land"
				color = Color(0.9, 0.5, 0.1)

		_create_block(type, label, color, get_global_mouse_position() - workspace.global_position + Vector2(10, 0))

func _create_block(type: String, text: String, color: Color, pos: Vector2):
	var b = Panel.new()
	b.set_script(block_script)
	b.custom_minimum_size = Vector2(190, 48) # Slightly taller for notches
	b.block_type = type
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	b.add_theme_stylebox_override("panel", sb)
	
	# Visual Connector: Top Cutout (Darker overlay)
	if type != "start":
		var cutout = Panel.new()
		cutout.custom_minimum_size = Vector2(24, 8)
		var csb = StyleBoxFlat.new()
		csb.bg_color = Color(0.1, 0.1, 0.1) # Dark like workspace
		csb.corner_radius_bottom_left = 6
		csb.corner_radius_bottom_right = 6
		cutout.add_theme_stylebox_override("panel", csb)
		cutout.position = Vector2(25, -1)
		b.add_child(cutout)

	# Visual Connector: Bottom Notch (Same color)
	var notch = Panel.new()
	notch.custom_minimum_size = Vector2(24, 8)
	var nsb = StyleBoxFlat.new()
	nsb.bg_color = color
	nsb.corner_radius_bottom_left = 6
	nsb.corner_radius_bottom_right = 6
	notch.add_theme_stylebox_override("panel", nsb)
	notch.position = Vector2(25, 47)
	b.add_child(notch)
	var block_label = Label.new()
	block_label.name = "L"
	block_label.text = text
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block_label.add_theme_font_size_override("font_size", 11)
	b.add_child(block_label)

	# Editable Input for specific blocks
	if type == "forward":
		block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		block_label.position.x = 10
		block_label.text = "Forward                      cm" # More space
		block_label.add_theme_font_size_override("font_size", 12)
		
		# White circular background for input
		var input_bg = Panel.new()
		input_bg.custom_minimum_size = Vector2(50, 24)
		input_bg.position = Vector2(62, 12)
		var ibsb = StyleBoxFlat.new()
		ibsb.bg_color = Color(1, 1, 1)
		ibsb.corner_radius_top_left = 12
		ibsb.corner_radius_top_right = 12
		ibsb.corner_radius_bottom_left = 12
		ibsb.corner_radius_bottom_right = 12
		input_bg.name = "input_bg"
		input_bg.add_theme_stylebox_override("panel", ibsb)
		b.add_child(input_bg)

		var input = LineEdit.new()
		input.name = "Input"
		input.text = "50"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", Color(0, 0, 0))
		input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Transparent line edit over the white background
		var empty_sb = StyleBoxEmpty.new()
		input.add_theme_stylebox_override("normal", empty_sb)
		input.add_theme_stylebox_override("focus", empty_sb)
		input_bg.add_child(input)

	workspace.add_child(b)
	b.position = pos
	
	b.drag_started.connect(func(): if is_instance_valid(trash_panel): trash_panel.visible = true)
	b.drag_ended.connect(func(): 
		if is_instance_valid(trash_panel): trash_panel.visible = false
		_check_snapping(b)
	)
	return b

func _create_trash_zone():
	trash_panel = Panel.new()
	trash_panel.name = "TrashZone"
	trash_panel.visible = false
	var tsb = StyleBoxFlat.new()
	tsb.bg_color = Color(0.8, 0.2, 0.1, 0.4)
	tsb.border_width_left = 2
	tsb.border_width_top = 2
	tsb.border_width_right = 2
	tsb.border_width_bottom = 2
	tsb.border_color = Color(1, 0, 0, 0.8)
	trash_panel.add_theme_stylebox_override("panel", tsb)
	trash_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var label = Label.new()
	label.text = "DROP HERE TO DELETE"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 14)
	trash_panel.add_child(label)
	
	toolbox.add_child(trash_panel)

func _check_snapping(moving_block: Panel):
	if not is_instance_valid(moving_block): return
	if trash_panel: trash_panel.visible = false
	var mpos = get_global_mouse_position()
	
	# 1. FIXED DELETION: Use the global rect of the toolbox panel
	if is_instance_valid(toolbox) and toolbox.get_global_rect().has_point(mpos):
		moving_block.queue_free()
		_log("Block deleted", "warning")
		return

	# 2. Preparation: Temporarily move to workspace for world-space calculation
	var old_pos = moving_block.global_position
	if moving_block.get_parent() != workspace:
		moving_block.get_parent().remove_child(moving_block)
		workspace.add_child(moving_block)
		moving_block.global_position = old_pos

	# 3. FIXED SNAPPING: Scan ALL blocks, not just root children
	var best_parent = null
	var min_dist = 40.0 # Increased snap range
	
	var all_blocks = _get_all_blocks(workspace)
	for other in all_blocks:
		if not is_instance_valid(other): continue
		if other == moving_block: continue
		if other.is_ancestor_of(moving_block): continue # Don't snap to your own children
		
		var other_bottom_global = other.global_position + Vector2(0, other.size.y)
		var d = moving_block.global_position.distance_to(other_bottom_global)
		
		# Also check horizontal alignment (Scratch-style)
		var dx = abs(moving_block.global_position.x - other.global_position.x)
		
		if d < min_dist and dx < 50:
			min_dist = d
			best_parent = other
	
	if best_parent and is_instance_valid(best_parent):
		# Hierarchy snap!
		workspace.remove_child(moving_block)
		best_parent.add_child(moving_block)
		moving_block.position = Vector2(0, best_parent.size.y)
		_log("Snapped to stack", "success")

# Helper to find all blocks regardless of nesting
func _get_all_blocks(parent_node) -> Array:
	var list = []
	if not is_instance_valid(parent_node): return list
	for child in parent_node.get_children():
		if is_instance_valid(child):
			if "block_type" in child:
				list.append(child)
			list.append_array(_get_all_blocks(child))
	return list

# ──────────────────────────── UI BUILD ────────────────────────────
func _build_comp_list():
	comp_list.clear()
	for cat in CATEGORIES:
		var ci = comp_list.add_item("▸ " + cat)
		comp_list.set_item_selectable(ci, false)
		comp_list.set_item_custom_fg_color(ci, Color(0.5, 0.5, 0.5))
		for cid in CATEGORIES[cat]:
			if COMPONENTS.has(cid):
				var ii = comp_list.add_item("   " + cid)
				comp_list.set_item_metadata(ii, cid)
				var c = COMPONENTS[cid]
				match c.type:
					"Motor": comp_list.set_item_custom_fg_color(ii, Color(0.9, 0.4, 0.4))
					"Battery": comp_list.set_item_custom_fg_color(ii, Color(0.9, 0.8, 0.2))
					"Frame": comp_list.set_item_custom_fg_color(ii, Color(0.7, 0.7, 0.7))
					_: comp_list.set_item_custom_fg_color(ii, Color(0.6, 0.7, 0.8))

func _build_floor():
	var m = MeshInstance3D.new()
	var p = PlaneMesh.new()
	p.size = Vector2(100, 100)
	m.mesh = p
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.16) # Darker, more neutral
	mat.metallic = 0.0
	mat.roughness = 1.0 # Pure matte
	mat.specular = 0.0 # No reflections
	m.material_override = mat
	scene_root.add_child(m)

func _build_grid():
	# Professional subtle grid on the floor
	var grid_size := 50
	var grid_mat = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.25, 0.25, 0.28, 0.3)
	grid_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	grid_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	var span = float(grid_size * 2)
	for i in range(-grid_size, grid_size + 1):
		# Standard grid line
		var thickness = 0.015
		var color = grid_mat.albedo_color
		
		# Axis coloring
		if i == 0:
			thickness = 0.04
		
		# Draw X lines
		var lx = MeshInstance3D.new()
		var bx = BoxMesh.new()
		bx.size = Vector3(span, 0.001, thickness)
		lx.mesh = bx
		var lm = grid_mat.duplicate()
		if i == 0: lm.albedo_color = Color(0.8, 0.2, 0.2, 0.6) # Red X axis
		lx.material_override = lm
		lx.position = Vector3(0, 0.005, float(i))
		scene_root.add_child(lx)

		# Draw Z lines
		var lz = MeshInstance3D.new()
		var bz = BoxMesh.new()
		bz.size = Vector3(thickness, 0.001, span)
		lz.mesh = bz
		var lzm = grid_mat.duplicate()
		if i == 0: lzm.albedo_color = Color(0.2, 0.6, 0.8, 0.6) # Blue/Cyan Z axis
		lz.material_override = lzm
		lz.position = Vector3(float(i), 0.005, 0)
		scene_root.add_child(lz)

# ──────────────────────────── INPUT ───────────────────────────────
func _input(event):
	# CRITICAL: Ignore 3D interactions if we are not ở Canvas tab hoặc đang simulation
	if tabs.current_tab != 0:
		orbiting = false
		panning = false
		return

	# Nếu đang simulation thì chỉ cho phép điều khiển camera (orbit, pan, zoom), KHÔNG cho phép chọn, thêm, xóa, di chuyển, wiring
	var sim_locked = sim_state == "playing"

	if event is InputEventMouseButton:
		var in_canvas = vpc.get_global_rect().has_point(get_global_mouse_position())
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if not sim_locked:
						if ghost:
							if in_canvas:
								var snap = _find_snap()
								if snap:
									_place(cur_id, snap.pos, snap.port, snap.parent_uid)
									_cancel_ghost()
								else:
									var mpos = viewport.get_mouse_position()
									var ro = camera.project_ray_origin(mpos)
									var rd = camera.project_ray_normal(mpos)
									var gp = Plane(Vector3.UP, 0)
									var ghit = gp.intersects_ray(ro, rd)
									if ghit:
										_place(cur_id, ghit + Vector3(0, 0.5, 0))
										_cancel_ghost()
						elif in_canvas:
							# Try to pick up existing component
							_pick_existing()
							if not ghost: # If nothing picked, start orbiting
								orbiting = true
					else:
						# Khi đang simulation, chỉ cho phép orbit camera
						if in_canvas:
							orbiting = true
				else:
					orbiting = false
					panning = false
			MOUSE_BUTTON_RIGHT:
				if in_canvas:
					panning = event.pressed
				else:
					panning = false
			MOUSE_BUTTON_MIDDLE:
				if in_canvas:
					panning = event.pressed
				else:
					panning = false
			MOUSE_BUTTON_WHEEL_UP:
				if tabs.current_tab == 0 and in_canvas:
					zoom = max(1.0, zoom - 1.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				if tabs.current_tab == 0 and in_canvas:
					zoom = min(60.0, zoom + 1.5)

	if event is InputEventMouseMotion:
		if orbiting:
			camera_rot.y -= event.relative.x * 0.005
			camera_rot.x = clamp(camera_rot.x - event.relative.y * 0.005, -PI/2.1, PI/2.1)
		elif panning:
			var pan_speed = zoom * 0.001
			var cam_basis = camera.global_transform.basis
			pivot.global_position -= cam_basis.x * event.relative.x * pan_speed
			pivot.global_position += cam_basis.y * event.relative.y * pan_speed

	if event is InputEventKey and event.pressed:
		if not sim_locked:
			if event.keycode == KEY_R and ghost:
				ghost_rot += PI / 2
			if event.keycode == KEY_ESCAPE:
				_cancel_ghost()
			if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
				_remove_selected()

func _process(_delta):
	# WASD Movement support
	var move_vec = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move_vec += -camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): move_vec += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): move_vec += -camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): move_vec += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_Q): move_vec += Vector3.DOWN
	if Input.is_key_pressed(KEY_E): move_vec += Vector3.UP
	
	if move_vec.length() > 0:
		var speed = zoom * 0.8
		if Input.is_key_pressed(KEY_SHIFT): speed *= 3.0
		pivot.global_position += move_vec.normalized() * _delta * speed

	# Update camera transform based on rot/zoom
	if tabs.current_tab == 0:
		pivot.rotation.y = camera_rot.y
		pivot.rotation.x = camera_rot.x
		camera.position.z = zoom
		camera.position.y = 0 # Camera is child of pivot, pivot handles X/Y rotation
	
	if is_instance_valid(ghost):
		_move_ghost()
	if sim_state == "playing":
		_simulate(_delta)

# ──────────────────────────── GHOST / PLACEMENT ───────────────────
func _on_item_selected(idx: int):
	var id = comp_list.get_item_metadata(idx)
	if id == null:
		return
	if id == "PVC Pipe Frame" or id == "Carbon Fiber Body":
		for c in placed:
			if c.type == "Frame":
				_log("Only one frame allowed!", "error")
				return
	cur_id = id
	_cancel_ghost()
	ghost = _build_mesh(id, true)
	components_group.add_child(ghost)
	_show_snap_hints(id)
	
	# Deselect so it can be clicked again
	comp_list.deselect_all()

func _move_ghost():
	var mpos = viewport.get_mouse_position()
	var ro = camera.project_ray_origin(mpos)
	var rd = camera.project_ray_normal(mpos)

	var snap = _find_snap()
	if snap:
		ghost.global_position = snap.pos
		_ghost_tint(Color(0, 1, 0.5, 0.6))
	else:
		# Follow cursor on ground plane
		var plane = Plane(Vector3.UP, 0)
		var hit = plane.intersects_ray(ro, rd)
		if hit == null:
			return
		ghost.global_position = hit + Vector3(0, 0.5, 0)
		_ghost_tint(Color(1, 1, 1, 0.25))
	ghost.rotation.y = ghost_rot

func _find_snap() -> Variant:
	var mpos = viewport.get_mouse_position()
	var ro = camera.project_ray_origin(mpos)
	var rd = camera.project_ray_normal(mpos)
	# Cast ray against MULTIPLE planes at different heights to find snap points
	var best_d := 2.5  # Generous snap distance
	var best = null

	for hint in snap_hints.get_children():
		if not is_instance_valid(hint): continue
		# Cast ray on a plane at the SAME Y height as this hint
		var hint_y = hint.global_position.y
		var h_plane = Plane(Vector3.UP, hint_y)
		var hit = h_plane.intersects_ray(ro, rd)
		if hit == null:
			continue
		# Compare XZ distance only (ignore Y — we snap to the hint's exact Y)
		var dx = hit.x - hint.global_position.x
		var dz = hit.z - hint.global_position.z
		var d = sqrt(dx * dx + dz * dz)
		if d < best_d:
			best_d = d
			best = {
				"pos": hint.global_position, 
				"port": hint.name,
				"parent_uid": hint.get_meta("parent_uid", -1)
			}
	return best

func _show_snap_hints(id: String):
	_clear_children(snap_hints)
	var cdata = COMPONENTS[id]
	# Scan ALL placed components for matching ports
	for comp in placed:
		if not is_instance_valid(comp.get("node")): continue
		var ports = COMPONENTS[comp.id].get("ports", [])
		for port in ports:
			if port.get("slot", false) and port.get("allowed", []).has(cdata.type):
				# Check port not already occupied
				var occupied := false
				for other in placed:
					if other.get("port_name", "") == port.name and other.get("parent_id", -1) == comp.uid:
						occupied = true
						break
				if occupied:
					continue

				var hint = MeshInstance3D.new()
				var torus = TorusMesh.new()
				torus.inner_radius = 0.15
				torus.outer_radius = 0.25
				hint.mesh = torus
				hint.name = port.name
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0, 1, 0.8, 0.7)
				mat.emission_enabled = true
				mat.emission = Color(0, 1, 0.8)
				mat.emission_energy_multiplier = 2.0
				mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
				hint.material_override = mat
				snap_hints.add_child(hint)
				hint.global_position = comp.node.global_transform * port.pos
				hint.set_meta("parent_uid", comp.uid)

func _cancel_ghost():
	if ghost:
		ghost.queue_free()
		ghost = null
	_clear_children(snap_hints)
	ghost_rot = 0.0

func _ghost_tint(c: Color):
	if not ghost:
		return
	for ch in ghost.get_children():
		if not is_instance_valid(ch): continue
		if ch is MeshInstance3D and ch.material_override:
			ch.material_override.albedo_color = c
		# Handle nested children from OBJ imports
		for sub in ch.get_children():
			if is_instance_valid(sub) and sub is MeshInstance3D and sub.material_override:
				sub.material_override.albedo_color = c

# ──────────────────────────── PLACE & WIRE ────────────────────────
func _place(id: String, pos: Vector3, port_name: String = "", parent_uid: int = -1):
	var node = _build_mesh(id, false)
	node.global_position = pos
	
	var uid = Time.get_ticks_msec() # Unique ID
	var cdata = COMPONENTS[id]
	var entry := {
		"uid": uid, "id": id, "type": cdata.type,
		"node": node, "port_name": port_name,
		"parent_id": parent_uid,
	}

	# Link hierarchy
	if parent_uid != -1:
		for p in placed:
			if p.uid == parent_uid:
				p.node.add_child(node)
				node.position = p.node.global_transform.affine_inverse() * pos
				break
	else:
		components_group.add_child(node)

	placed.append(entry)
	_rebuild_wires()
	_update_all()
	_log("Assembled: " + id, "success")

func _pick_existing():
	var mpos = viewport.get_mouse_position()
	var ro = camera.project_ray_origin(mpos)
	var rd = camera.project_ray_normal(mpos)
	
	var best_uid := -1
	var best_d := 1000.0
	
	for c in placed:
		if not is_instance_valid(c.node): continue
		if c.type == "Frame": continue # Don't pick frame
		var d = ro.distance_to(c.node.global_position) # Simple distance check for picking
		# check if ray passes near the node
		var to_node = c.node.global_position - ro
		var projection = to_node.dot(rd)
		if projection > 0:
			var closest_point = ro + rd * projection
			var dist = closest_point.distance_to(c.node.global_position)
			if dist < 1.0 and dist < best_d:
				best_d = dist
				best_uid = c.uid
	
	if best_uid != -1:
		# Find the entry
		for i in range(placed.size()):
			if placed[i].uid == best_uid:
				var c = placed[i]
				cur_id = c.id
				_remove_component(c.uid)
				# Convert to ghost
				ghost = _build_mesh(cur_id, true)
				components_group.add_child(ghost)
				_show_snap_hints(cur_id)
				_log("Picking up: " + cur_id, "info")
				return

func _rebuild_wires():
	if sim_state == "playing":
		return # Block wiring changes during simulation
	_clear_children(wires_group)
	# Find frame center for wiring hub
	var center = Vector3.ZERO
	var frame_node = null
	for f in placed:
		if is_instance_valid(f.get("node")) and f.type == "Frame":
			frame_node = f.node
			center = f.node.global_position + Vector3(0, 1.2, 0)
			break
	if not is_instance_valid(frame_node): return
	# Draw wires from each motor to the center hub
	for c in placed:
		if is_instance_valid(c.get("node")) and c.type == "Motor" and c.get("port_name", "") != "":
			_add_wire(c.node.global_position, center)

func _add_wire(from: Vector3, to: Vector3):
	if sim_state == "playing":
		return # Block adding wires during simulation
	var dist = from.distance_to(to)
	if dist < 0.1:
		return
	# Build a curved wire using multiple segments
	var wire_root = Node3D.new()
	var segments = 8
	var sag = max(0.1, dist * 0.15)
	var mid = (from + to) / 2.0
	mid.y -= sag
	# Simple 3-point curve
	for i in range(segments):
		var t0 = float(i) / segments
		var t1 = float(i + 1) / segments
		var p0 = _bezier3(from, mid, to, t0)
		var p1 = _bezier3(from, mid, to, t1)
		var seg_dist = p0.distance_to(p1)
		var cyl = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = seg_dist
		cyl.mesh = cm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.1)
		mat.metallic = 0.3
		cyl.material_override = mat
		wire_root.add_child(cyl)
		cyl.look_at_from_position((p0 + p1) / 2.0, p1, Vector3.UP)
		cyl.rotate_object_local(Vector3.RIGHT, PI / 2)
	wires_group.add_child(wire_root)

func _bezier3(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var ab = a.lerp(b, t)
	var bc = b.lerp(c, t)
	return ab.lerp(bc, t)

# ──────────────────────────── BUILD MESH ──────────────────────────
func _build_mesh(id: String, is_ghost: bool) -> Node3D:
	var cdata = COMPONENTS[id]
	var root = Node3D.new()

	# Check if this component uses an OBJ model file
	if cdata.get("use_obj", false):
		_build_frame_from_obj(root, cdata)
	else:
		match cdata.type:
			"Frame":
				_build_frame_procedural(root)
			"Motor":
				_build_motor(root)
			"Propeller":
				_build_propeller(root)
			"Battery":
				_build_battery(root)
			"FC":
				_build_fc(root)
			"ESC":
				_build_esc(root)
			_:
				var m = MeshInstance3D.new()
				m.mesh = BoxMesh.new()
				root.add_child(m)

	var mat = StandardMaterial3D.new()
	if is_ghost:
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0, 1, 0.8, 0.3)
	else:
		var raw_c = cdata.color
		# Make it pop even more
		mat.albedo_color = Color(min(raw_c.r * 1.3, 1.0), min(raw_c.g * 1.3, 1.0), min(raw_c.b * 1.3, 1.0))
		mat.metallic = 0.0 # No reflections to avoid black artifacts
		mat.roughness = 0.5 # Balanced matte
		mat.specular = 0.3

	_apply_material_recursive(root, mat)
	return root

func _apply_material_recursive(node: Node, mat: Material):
	for ch in node.get_children():
		if ch is MeshInstance3D:
			ch.material_override = mat
		if ch.get_child_count() > 0:
			_apply_material_recursive(ch, mat)

func _build_frame_from_obj(root: Node3D, cdata: Dictionary):
	# Load the real OBJ model
	var obj_path = cdata.get("obj_path", "")
	var mesh_res = load(obj_path)
	if mesh_res == null:
		_log("Failed to load OBJ: " + obj_path + ", using procedural frame", "warning")
		_build_frame_procedural(root)
		return

	var mi = MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.scale = Vector3(OBJ_SCALE, OBJ_SCALE, OBJ_SCALE) 
	root.add_child(mi)

	_log("Loaded PVC Pipe Frame from OBJ model", "info")

func _build_frame_procedural(root: Node3D):
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.18, 0.18, 0.18)
	arm_mat.metallic = 0.3
	arm_mat.roughness = 0.5

	# 4 diagonal arms
	for i in range(4):
		var arm = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(4.5, 0.4, 0.4) 
		arm.mesh = bm
		arm.material_override = arm_mat
		root.add_child(arm)
		var angle = PI / 4.0 + i * PI / 2.0
		arm.rotation.y = angle
		arm.position = Vector3(cos(angle) * 2, 0.75, -sin(angle) * 2)

		# Motor mount at tip
		var mount = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 0.2
		mount.mesh = cm
		mount.material_override = arm_mat
		root.add_child(mount)
		mount.position = Vector3(cos(angle) * 4, 0.85, -sin(angle) * 4)

	# Top plate (main chassis)
	var top = MeshInstance3D.new()
	top.mesh = BoxMesh.new()
	top.mesh.size = Vector3(2.6, 0.15, 5.0) 
	top.position.y = 1.0
	root.add_child(top)

	# Bottom plate
	var bot = MeshInstance3D.new()
	bot.mesh = BoxMesh.new()
	bot.mesh.size = Vector3(2.3, 0.15, 4.5)
	bot.position.y = 0.5
	root.add_child(bot)

	# Landing skids
	for side in [-1.0, 1.0]:
		var runner = MeshInstance3D.new()
		var rcyl = CylinderMesh.new()
		rcyl.top_radius = 0.06
		rcyl.bottom_radius = 0.06
		rcyl.height = 3.5
		runner.mesh = rcyl
		runner.rotation.x = PI / 2
		runner.position = Vector3(side * 1.3, -0.5, 0)
		root.add_child(runner)

	# Status LEDs
	var led_r = MeshInstance3D.new()
	led_r.mesh = BoxMesh.new()
	led_r.mesh.size = Vector3(0.1, 0.05, 0.1)
	var led_mat_r = StandardMaterial3D.new()
	led_mat_r.albedo_color = Color(0.2, 0, 0)
	led_mat_r.emission_enabled = true
	led_mat_r.emission = Color.RED
	led_mat_r.emission_energy_multiplier = 3.0
	led_r.material_override = led_mat_r
	led_r.position = Vector3(0.8, 1.06, 2.0)
	root.add_child(led_r)

	var led_g = MeshInstance3D.new()
	led_g.mesh = BoxMesh.new()
	led_g.mesh.size = Vector3(0.1, 0.05, 0.1)
	var led_mat_g = StandardMaterial3D.new()
	led_mat_g.albedo_color = Color(0, 0.2, 0)
	led_mat_g.emission_enabled = true
	led_mat_g.emission = Color.GREEN
	led_mat_g.emission_energy_multiplier = 3.0
	led_g.material_override = led_mat_g
	led_g.position = Vector3(-0.8, 1.06, 2.0)
	root.add_child(led_g)

	root.position.y = 0.7

func _build_motor(root: Node3D):
	# Stator
	var st = MeshInstance3D.new()
	st.mesh = CylinderMesh.new()
	st.mesh.top_radius = 0.4
	st.mesh.bottom_radius = 0.4
	st.mesh.height = 0.5
	root.add_child(st)
	# Bell/Rotor
	var bell = MeshInstance3D.new()
	bell.mesh = CylinderMesh.new()
	bell.mesh.top_radius = 0.45
	bell.mesh.bottom_radius = 0.45
	bell.mesh.height = 0.2
	bell.position.y = 0.25
	root.add_child(bell)
	# Shaft
	var shaft = MeshInstance3D.new()
	shaft.mesh = CylinderMesh.new()
	shaft.mesh.top_radius = 0.1
	shaft.mesh.bottom_radius = 0.1
	shaft.mesh.height = 0.3
	shaft.position.y = 0.5
	root.add_child(shaft)

func _build_propeller(root: Node3D):
	var blade = MeshInstance3D.new()
	blade.mesh = BoxMesh.new()
	blade.mesh.size = Vector3(4.5, 0.04, 0.25)
	blade.name = "prop_blade"
	root.add_child(blade)
	var hub = MeshInstance3D.new()
	hub.mesh = CylinderMesh.new()
	hub.mesh.top_radius = 0.12
	hub.mesh.bottom_radius = 0.12
	hub.mesh.height = 0.08
	root.add_child(hub)

func _build_battery(root: Node3D):
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	# Resized to be more realistic (smaller relative to the frame)
	body.mesh.size = Vector3(1.2, 0.6, 2.8)
	root.add_child(body)

func _build_fc(root: Node3D):
	var pcb = MeshInstance3D.new()
	pcb.mesh = BoxMesh.new()
	pcb.mesh.size = Vector3(1.5, 0.08, 1.5)
	root.add_child(pcb)

func _build_esc(root: Node3D):
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.0, 0.25, 1.8)
	root.add_child(body)

# ──────────────────────────── SIMULATION ──────────────────────────
func _on_play():
	var check = _preflight_check()
	# Only block play if basic structure is missing
	if check.reason == "No frame" or check.reason == "No battery":
		_log("SYSTEM ERROR: " + check.reason, "error")
		sim_label.text = "ERROR"
		return

	# Start simulation state
	sim_state = "playing"
	sim_time = 0.0
	sim_step_idx = 0
	sim_step_timer = 0.0
	sim_target_pos = Vector3.ZERO # Start at floor
	sim_label.text = "Idle/Armed"
	topbar_status.text = "playing"
	
	# Find the 'start' block and build the sequence
	sim_sequence = []
	var start_block = null
	for child in workspace.get_children():
		if is_instance_valid(child) and "block_type" in child and child.block_type == "start":
			start_block = child
			break
	
	if start_block:
		_parse_block_stack(start_block)
	
	if sim_sequence.size() == 0:
		_log("No sequence to execute. Connect blocks to 'When flag clicked'!", "warning")
		return

	_log("Executing Flight Plan: " + str(sim_sequence.size()) + " steps", "info")
	
	sim_state = "playing"
	sim_time = 0.0
	sim_step_idx = 0
	sim_step_timer = 0.0
	sim_target_pos = Vector3.ZERO
	sim_target_rot = Vector3.ZERO
	sim_label.text = "Flying..."
	topbar_status.text = "playing"
	
	# ── PhysicsBridge: Configure and arm ──
	if _bridge_active():
		var tw := 0.0
		var tt := 0.0
		var motor_with_prop_count := 0
		
		# Identify all propellers and find their parent motor IDs
		var prop_parents = []
		for c in placed:
			if c.type == "Propeller":
				prop_parents.append(c.parent_id)
		
		for c in placed:
			var d = COMPONENTS[c.id]
			tw += d.weight
			tt += d.thrust
			if d.type == "Motor":
				if c.uid in prop_parents:
					motor_with_prop_count += 1
		
		# Update UI state to "Locked"
		comp_list.enabled = false
		hier_tree.enabled = false
		hier_del_btn.disabled = true
		for btn in toolbox_v.get_children():
			if btn is Button: btn.disabled = true
		
		bridge.cmd_set_drone(tw / 1000.0, motor_with_prop_count, tt / 1000.0 * 9.81)
		bridge.cmd_arm()
		_log("Bridge: Drone configured (%.0fg, %d functional motors) & armed" % [tw, motor_with_prop_count], "info")

func _parse_block_stack(block):
	if not is_instance_valid(block): return
	# Follow Godot hierarchy to find connected blocks
	for child in block.get_children():
		if is_instance_valid(child) and "block_type" in child:
			var val = 0.0
			# STRICT search for Input field only within this block's immediate UI
			var input_node = child.get_node_or_null("input_bg/Input")
				
			if is_instance_valid(input_node) and input_node is LineEdit:
				val = input_node.text.to_float()
				if val <= 0.0: val = 50.0 # Default fallback
			
			# Calculate duration based on distance to maintain constant speed
			# Speed = 2.0 meters/sec (100 units/sec at 0.05 scale)
			var duration = max(1.0, (val * 0.05) / 2.0)
			
			sim_sequence.append({
				"type": child.block_type,
				"value": val,
				"duration": duration
			})
			_parse_block_stack(child)

func _on_pause():
	if sim_state == "playing":
		sim_state = "paused"
		sim_label.text = "Paused"
		topbar_status.text = "paused"

func _on_stop():
	sim_state = "stopped"
	sim_label.text = "Ready"
	topbar_status.text = "stopped"
	# Reset positions
	components_group.rotation = Vector3.ZERO
	components_group.position = Vector3.ZERO
	sim_step_idx = 0
	# CRITICAL: Rebuild wires at home position to prevent "bulging"
	_rebuild_wires()
	# Stop bridge simulation
	if _bridge_active():
		bridge.cmd_stop()
		_log("Bridge: Simulation stopped & reset", "info")
	
	# Unlock UI
	comp_list.enabled = true
	hier_tree.enabled = true
	hier_del_btn.disabled = false
	for btn in toolbox_v.get_children():
		if btn is Button: btn.disabled = false

func _simulate(delta: float):
	sim_time += delta
	var check = _preflight_check()

	# 1. Propeller Spin — use bridge RPMs if available
	if sim_state == "playing":
		var bridge_rpms = []
		if _bridge_active():
			bridge_rpms = bridge.get_motor_rpms()
		var prop_idx := 0
		for comp in placed:
			if is_instance_valid(comp.get("node")) and comp.type == "Propeller":
				for ch in comp.node.get_children():
					if is_instance_valid(ch) and ch.name == "prop_blade":
						var spin_speed := 35.0
						if prop_idx < bridge_rpms.size() and bridge_rpms[prop_idx] > 0:
							spin_speed = bridge_rpms[prop_idx] / 150.0  # Increased multiplier for realism
						ch.rotation.y += delta * spin_speed
						prop_idx += 1

	if check.capability == "Cannot fly" and not _bridge_active():
		components_group.position.y = lerp(components_group.position.y, 0.0, 0.08)
		return

	# ── BRIDGE PHYSICS MODE ──
	if _bridge_active() and use_bridge_physics:
		_simulate_bridge(delta)
		return

	# ── KINEMATIC FALLBACK MODE ──
	_simulate_kinematic(delta, check)

func _bridge_active() -> bool:
	"""Check if bridge is available and connected."""
	return bridge != null and bridge_connected and is_instance_valid(bridge)

func _simulate_bridge(delta: float):
	"""Simulation driven by real physics from bridge (Gazebo/standalone)."""
	# Step processing: send commands to bridge based on block sequence
	if sim_state == "playing" and sim_step_idx < sim_sequence.size():
		var step = sim_sequence[sim_step_idx]
		sim_step_timer += delta
		
		# Send bridge commands only when step starts or changes
		if sim_step_timer <= delta * 2:  # First frame of step
			match step.type:
				"take_off":
					bridge.cmd_takeoff(2.5)
					_log("Bridge → Takeoff to 2.5m", "info")
				"forward":
					var speed = step.value * 0.05 / step.duration
					var fwd = -components_group.global_transform.basis.z.normalized()
					fwd.y = 0; fwd = fwd.normalized()
					bridge.cmd_move(fwd.x * speed, 0.0, fwd.z * speed)
					_log("Bridge → Move forward %.1f cm (%.2f m/s)" % [step.value, speed], "info")
				"hover":
					bridge.cmd_hover()
					_log("Bridge → Hover", "info")
				"land":
					bridge.cmd_land()
					_log("Bridge → Land", "info")

		if sim_step_timer >= step.duration:
			sim_step_idx += 1
			sim_step_timer = 0.0
			if sim_step_idx < sim_sequence.size():
				_log("Step " + str(sim_step_idx + 1) + ": Executing " + sim_sequence[sim_step_idx].type, "info")
			else:
				bridge.cmd_hover()  # Hold position after program ends
				_log("Program finished — hovering", "success")
				sim_label.text = "Finished"

	# Position/rotation update happens in _on_bridge_state callback

func _on_bridge_state(state: Dictionary):
	"""Callback: apply physics state from bridge to the 3D drone visual."""
	if sim_state != "playing" and sim_state != "paused":
		return
	
	var pos_arr = state.get("pos", [0, 0, 0])
	var rot_arr = state.get("rot", [0, 0, 0, 1])
	
	# Apply position from physics engine
	var target_pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
	components_group.position = components_group.position.lerp(target_pos, 0.3)
	
	# Apply quaternion rotation from physics engine
	var quat = Quaternion(rot_arr[0], rot_arr[1], rot_arr[2], rot_arr[3])
	var target_euler = quat.get_euler()
	components_group.rotation = components_group.rotation.lerp(target_euler, 0.3)
	
	# Update status display
	var status_text = state.get("status", "unknown")
	if sim_state == "playing":
		sim_label.text = status_text.capitalize()

func _simulate_kinematic(delta: float, check: Dictionary):
	"""Original kinematic simulation as fallback when bridge is not connected."""
	# 2. Logic Step Processing
	if sim_state == "playing" and sim_step_idx < sim_sequence.size():
		var step = sim_sequence[sim_step_idx]
		sim_step_timer += delta
		
		match step.type:
			"take_off":
				sim_target_pos.y = 2.5
			"forward":
				# REAL MOVEMENT: Calculate target based on horizontal plane only
				var target_dist = step.value * 0.05
				var forward_dir = -components_group.global_transform.basis.z
				forward_dir.y = 0 # FORCED HORIZONTAL
				forward_dir = forward_dir.normalized()
				
				# Incremental movement to target
				sim_target_pos += forward_dir * target_dist * (delta / step.duration)
				# Lock Y to prevent altitude bleed during tilt
				if sim_target_pos.y < 2.0: sim_target_pos.y = 2.5
			"hover":
				# Just bob in place (handled by physics below)
				pass
			"land":
				sim_target_pos.y = 0.0
		
		if sim_step_timer >= step.duration:
			sim_step_idx += 1
			sim_step_timer = 0.0
			if sim_step_idx < sim_sequence.size():
				_log("Step " + str(sim_step_idx + 1) + ": Executing " + sim_sequence[sim_step_idx].type, "info")
			else:
				_log("Program finished", "success")
				sim_label.text = "Finished"

	# 3. Physics & Visuals
	var final_target = sim_target_pos
	if check.capability == "Cannot fly":
		final_target.y = 0.0
	
	components_group.position = components_group.position.lerp(final_target, 0.05)
	
	# DYNAMIC TILT: Drone must pitch DOWN to go forward
	var displacement = (sim_target_pos - components_group.position)
	var dynamic_pitch = clamp(displacement.z * 0.3, -0.3, 0.3)
	var dynamic_roll = clamp(-displacement.x * 0.3, -0.3, 0.3)
	
	var tilt_x = check.tilt_x * 0.2 + dynamic_pitch + sin(sim_time*1.5)*0.01
	var tilt_z = check.tilt_z * 0.2 + dynamic_roll + cos(sim_time*1.5)*0.01
	
	components_group.rotation.x = lerp(components_group.rotation.x, tilt_x, 0.1)
	components_group.rotation.z = lerp(components_group.rotation.z, tilt_z, 0.1)

func _preflight_check() -> Dictionary:
	var motors_with_props = []
	var motors_total = 0
	var has_frame := false
	var has_battery := false

	for c in placed:
		var c_type = c["type"]
		if c_type == "Frame": has_frame = true
		elif c_type == "Battery": has_battery = true
		elif c_type == "Motor": 
			motors_total += 1
			# Check if has prop
			var has_p = false
			for p in placed:
				if p.parent_id == c.uid and p.type == "Propeller":
					has_p = true
					break
			if has_p:
				motors_with_props.append(c)

	if not has_frame:
		return {"capability": "Cannot fly", "reason": "No frame", "tilt_x": 0, "tilt_z": 0}
	if not has_battery:
		return {"capability": "Cannot fly", "reason": "No battery", "tilt_x": 0, "tilt_z": 0}
	if motors_with_props.size() == 0:
		return {"capability": "Cannot fly", "reason": "No motors with props", "tilt_x": 0, "tilt_z": 0}

	# Real Physics: Each motor provides lift at its position
	# Calculate total net force and torque
	var total_lift := motors_with_props.size()
	var torque_x := 0.0
	var torque_z := 0.0
	
	for m in motors_with_props:
		if is_instance_valid(m.node):
			# Use LOCAL position for torque calculation
			var lpos = m.node.position 
			torque_x += lpos.z * 0.5
			torque_z -= lpos.x * 0.5

	var tilt_x = torque_x / max(total_lift, 1)
	var tilt_z = torque_z / max(total_lift, 1)

	var cap = "Stable"
	if motors_with_props.size() < 4:
		cap = "Unstable"
		if motors_with_props.size() < 2:
			return {"capability": "Cannot fly", "reason": "Asymmetric lift", "tilt_x": tilt_x, "tilt_z": tilt_z}
	
	if abs(tilt_x) > 1.0 or abs(tilt_z) > 1.0:
		cap = "Unstable"

	return {"capability": cap, "reason": "", "tilt_x": tilt_x, "tilt_z": tilt_z}

# ──────────────────────────── UPDATE UI ───────────────────────────
func _update_all():
	var tw := 0.0
	var tt := 0.0
	var bat_cap := 0
	for c in placed:
		var d = COMPONENTS[c.id]
		tw += d.weight
		tt += d.thrust
		bat_cap += d.get("capacity", 0)

	weight_val.text = "%.1f g" % tw
	thrust_val.text = "%.2f kg" % (tt / 1000.0)
	var ratio = (tt / tw) if tw > 0 else 0.0
	twr_val.text = "%.2f:1" % ratio

	# Capability badge
	if ratio >= 2.0:
		cap_val.text = "Good"
		cap_val.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	elif ratio >= 1.5:
		cap_val.text = "Marginal"
		cap_val.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	else:
		cap_val.text = "N/A"
		cap_val.remove_theme_color_override("font_color")

	bat_val.text = str(bat_cap) + " mAh"
	var draw_a = tt * 0.001 * 30 # rough amps estimate
	var ft_min = (bat_cap / 1000.0 * 60.0 / max(draw_a, 1)) if bat_cap > 0 else 0
	ft_val.text = "%.1f min" % ft_min

	comp_count.text = "  Components: " + str(placed.size())

	# Diagnostics
	_update_diagnostics()

	# Hierarchy tree sync
	hier_tree.clear()
	var root_item = hier_tree.create_item()
	root_item.set_text(0, "Drone")
	# root_item.set_icon(0, preload("res://icon_chip.png")) # If we had one
	
	for c in placed:
		if not is_instance_valid(c.get("node")): continue
		var item = hier_tree.create_item(root_item)
		item.set_text(0, c.id)
		item.set_metadata(0, c.uid)
		# item.set_icon(0, preload("res://icon_box.png")) # If we had one

func _on_hier_item_selected():
	var item = hier_tree.get_selected()
	if item:
		var uid = item.get_metadata(0)
		_highlight_component(uid)
		_log("Selected: " + item.get_text(0), "info")

func _highlight_component(uid: int):
	for c in placed:
		if c.uid == uid:
			var node = c.node
			# Create a temporary pulse animation
			var tween = create_tween()
			var original_color = Color(1, 1, 1, 1) # Default
			
			# Attempt to find meshes and pulse their emission
			for child in node.get_children():
				if child is MeshInstance3D:
					var mat = child.material_override
					if mat:
						original_color = mat.albedo_color
						tween.tween_property(mat, "emission_enabled", true, 0)
						tween.tween_property(mat, "emission", Color(0, 0.8, 1), 0.2)
						tween.tween_property(mat, "emission_energy_multiplier", 10.0, 0.2)
						tween.parallel().tween_property(child, "scale", Vector3(1.1, 1.1, 1.1), 0.2)
						tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4)
						tween.parallel().tween_property(child, "scale", Vector3(1.0, 1.0, 1.0), 0.4)
						tween.tween_property(mat, "emission_enabled", false, 0)
						# Ensure scale is reset to 1 after animation (in case tween is interrupted)
						tween.finished.connect(func(): child.scale = Vector3(1, 1, 1))
			return

func _remove_selected():
	var item = hier_tree.get_selected()
	if item and item.get_parent(): # Don't delete root
		var uid = item.get_metadata(0)
		_remove_component(uid)

func _remove_component(uid: int):
	var found_idx = -1
	for i in range(placed.size()):
		if placed[i].uid == uid:
			found_idx = i
			break
	
	if found_idx != -1:
		var comp = placed[found_idx]
		if comp.type == "Frame":
			_log("Cannot remove the main frame!", "error")
			return
			
		_log("Removed: " + comp.id, "warning")
		comp.node.queue_free()
		placed.remove_at(found_idx)
		
		_rebuild_wires()
		_update_all()
	else:
		_log("Nothing selected to delete", "info")

func _update_diagnostics():
	var issues := []
	var has_bat := false
	var has_frame := false
	var motor_count := 0
	var prop_count := 0

	for c in placed:
		var c_type = c["type"]
		if c_type == "Battery": has_bat = true
		elif c_type == "Frame": has_frame = true
		elif c_type == "Motor": motor_count += 1
		elif c_type == "Propeller": prop_count += 1

	if not has_frame:
		issues.append("[color=#f44336]No frame detetced[/color]")
	if not has_bat:
		issues.append("[color=#f44336]No battery placed[/color]")
	if motor_count == 0:
		issues.append("[color=#f44336]No motors installed[/color]")
	elif motor_count < 4:
		issues.append("[color=#ff9800]Only %d motors (4 recommended)[/color]" % motor_count)
	if prop_count < motor_count:
		issues.append("[color=#ff9800]%d motors missing propellers[/color]" % (motor_count - prop_count))
	if issues.size() == 0:
		issues.append("[color=#4caf50]All systems nominal[/color]")

	diag_text.text = "\n".join(issues)

# ──────────────────────────── UTILS ───────────────────────────────
func _clear_children(n: Node):
	if not is_instance_valid(n): return
	for c in n.get_children():
		if is_instance_valid(c):
			c.queue_free()

func _log(msg: String, type: String = "info"):
	var c = "#aaa"
	match type:
		"success": c = "#4caf50"
		"error": c = "#f44336"
		"warning": c = "#ff9800"
	var t = Time.get_time_string_from_system()
	log_box.append_text("[color=%s][%s] %s[/color]\n" % [c, t, msg])
