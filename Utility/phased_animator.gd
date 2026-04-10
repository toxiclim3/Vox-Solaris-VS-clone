extends Node
class_name PhasedAnimator

# Universal Phased Animation Controller
# Handles START -> LOOP -> FINISH animation sequences on a Sprite2D.
# Supports color variants by mapping rows (vframes) and animation frames (hframes).

enum Phase { START, LOOP, FINISH }

@export_group("Sprite Configuration")
@export var target_sprite: Sprite2D
@export var row_index: int = 0
@export var col_offset: int = 0

@export_group("Animation Offsets")
@export var loop_start: int = 6
@export var loop_end: int = 8
@export var total_frames: int = 12

var current_phase = Phase.START
var local_frame = 0

func _ready():
	# Auto-detect sprite if not set
	if not target_sprite:
		target_sprite = get_parent().get_node_or_null("Sprite2D")
		if not target_sprite:
			push_warning("PhasedAnimator: No Sprite2D found for ", get_parent().name)
			return
	
	update_sprite()

# Called by external timer (e.g. AnimationTimer) to advance the frame
func advance(is_expiring: bool = false):
	if not target_sprite: return
	
	# Handle transition to FINISH phase
	if is_expiring and current_phase != Phase.FINISH:
		current_phase = Phase.FINISH
		# Don't reset local_frame, just keep moving forward from where we are
	
	match current_phase:
		Phase.START:
			if local_frame < loop_end:
				local_frame += 1
			else:
				current_phase = Phase.LOOP
				local_frame = loop_start
		
		Phase.LOOP:
			if local_frame < loop_end:
				local_frame += 1
			else:
				local_frame = loop_start
		
		Phase.FINISH:
			# Play until the very last frame of the sequence
			if local_frame < total_frames - 1:
				local_frame += 1
			# Stay at the last frame once reached
	
	update_sprite()

# Recalculates and sets the absolute frame on the target sprite
func update_sprite():
	if not target_sprite: return
	
	# absolute_index = (row * frames_per_row) + (horizontal_start + current_frame)
	var hframes = target_sprite.hframes
	var absolute_frame = (row_index * hframes) + (col_offset + local_frame)
	
	target_sprite.frame = absolute_frame

# Helper to setup row and offset quickly (useful for weapon levels)
func setup_variant(row: int, offset: int = 0):
	row_index = row
	col_offset = offset
	update_sprite()
