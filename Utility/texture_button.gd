extends TextureButton

func _on_mouse_entered():
	$snd_hover.play()
	
func _on_pressed():
	$snd_click.play()	
