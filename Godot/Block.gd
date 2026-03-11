extends Panel

signal drag_started
signal drag_ended
signal value_changed(new_value)

var dragging = false
var drag_offset = Vector2.ZERO
var block_type = "" 
var value = "50" 

@onready var label: Label = $L
var input_field: LineEdit = null

func _ready():
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# If this block type supports input, find or create the input field
	if has_node("Input"):
		input_field = $Input
		input_field.text = value
		input_field.text_submitted.connect(_on_value_submitted)
		input_field.focus_exited.connect(func(): _on_value_submitted(input_field.text))
		# Stop dragging when typing
		input_field.gui_input.connect(func(event): 
			if event is InputEventMouseButton: 
				accept_event()
		)

func _on_value_submitted(new_text):
	value = new_text
	value_changed.emit(value)

func _gui_input(event):
	# Don't drag if interacting with input field
	if input_field and input_field.has_focus():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_local_mouse_position()
				drag_started.emit()
				get_parent().move_child(self, get_parent().get_child_count() - 1)
			else:
				dragging = false
				drag_ended.emit()

func _process(_delta):
	if dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		global_position = target_pos
