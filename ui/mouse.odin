package ui

import rl "vendor:raylib"
import game "../game"

MouseInfo :: struct {
    has_card: bool,
    cur_card: game.CardID,   // Updated when has_card switches from false -> true
    top_card: game.CardID,  // Denotes which card is currently being magnified

    // things that should be updated each frame
    posn: rl.Vector2,
    pressed: bool,
}

update_mouse :: proc(mouse_info: ^MouseInfo) {
    mouse_info.posn = rl.GetMousePosition()
    mouse_info.pressed = rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
    mouse_info.top_card = 0
}
