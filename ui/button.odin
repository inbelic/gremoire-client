package ui

import rl "vendor:raylib"

Button :: struct {
    // Texture related
    posn: rl.Rectangle,
    source: rl.Rectangle,

    // Functionality
    hovering: bool,
    pressed: bool,
}

update_button :: proc(info: ^UpdateInfo, button: ^Button) {
    button.hovering = rl.CheckCollisionPointRec(info.mouse.posn, button.posn)
    button.pressed = false
    if button.hovering && info.mouse.pressed {
        button.pressed = true
    }
}

draw_button :: proc(ctx: ^DrawContext, button: Button) {
    tint := rl.WHITE
    if button.hovering {
        tint = rl.GRAY
    }
	rl.DrawTexturePro(ctx.buttons, button.source, button.posn, rl.Vector2{0, 0}, 0, tint)
}
