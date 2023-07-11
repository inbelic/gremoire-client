package client

import rl "vendor:raylib"

// Genernal DrawInfo for draw_* functions
DrawInfo :: struct {
    cards : rl.Texture,
    buttons: rl.Texture,
}

// Mouse components
MouseInfo :: struct {
    has_card: bool,
    cur_card: CardID,   // Updated when has_card switches from false -> true
    top_card: CardID,  // Denotes which card is currently being magnified

    // things that should be updated each frame
    posn: rl.Vector2,
    pressed: bool,
}

// Button component
Button :: struct {
    // Texture related
    posn: rl.Rectangle,
    source: rl.Rectangle,

    // Functionality
    hovering: bool,
    pressed: bool,
}

draw_button :: proc(info: ^DrawInfo, button: Button) {
    tint := rl.WHITE
    if button.hovering {
        tint = rl.GRAY
    }
	rl.DrawTexturePro(info.buttons, button.source, button.posn, rl.Vector2{0, 0}, 0, tint)
}

// Card component
Card :: struct {
    card_id: CardID,
    posn: rl.Vector2,   // Origin is set to be the center of the image
    scale: f32,         // 1 is 256x256 pixels

    // Card movement
    dest: rl.Vector2,
}

card_bounds :: proc(card: Card) -> rl.Rectangle {
    side_len := card.scale * 256
    return rl.Rectangle{card.posn.x - 128 * card.scale,
                        card.posn.y - 128 * card.scale,
                        256 * card.scale,
                        256 * card.scale}
}

card_unscaled_bounds :: proc(card: Card) -> rl.Rectangle {
    return rl.Rectangle{card.posn.x - 128, card.posn.y - 128, 256, 256}
}

card_source :: proc(card_id: CardID) -> rl.Rectangle {
    txtr_id := int(card_id)
    txtr_x := txtr_id % 8
    txtr_y := txtr_id / 8
    return rl.Rectangle{f32(txtr_x) * 256, f32(txtr_y) * 0, 256, 256}
}

draw_card :: proc(info: ^DrawInfo, card: Card) {
    @static frame_source := rl.Rectangle{0, 0, 256, 256}

    card_source := card_source(card.card_id)
    posn_rect := card_bounds(card)
	rl.DrawTexturePro(info.cards, card_source, posn_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
	rl.DrawTexturePro(info.cards, frame_source, posn_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
}

// Trigger components
trigger_bounds :: proc(trigger: Trigger) -> rl.Rectangle {
    @static orderedPosn     := rl.Vector2{f32(screenWidth) / 4, f32(screenHeight) / 8}
    @static unorderedPosn   := rl.Vector2{f32(screenWidth) / 4, f32(screenHeight) / 8 + 128}

    bounds := rl.Rectangle{}
    bounds.width = 128
    bounds.height = 128
    if trigger.selected {
        bounds.x = orderedPosn.x + 128 * f32(trigger.order)
        bounds.y = orderedPosn.y
    } else {
        bounds.x = unorderedPosn.x + 128 * f32(trigger.order)
        bounds.y = unorderedPosn.y
    }
    return bounds
}

get_next_order :: proc(triggers: ^[dynamic]Trigger, ordered: bool) -> u8 {
    posn := u8(0)
    for trigger in triggers^ {
        if trigger.selected == ordered {
            posn += 1
        }
    }
    return posn
}

trigger_source :: proc(trigger: Trigger) -> rl.Rectangle {
    card_id := trigger.card_id
    rect := card_source(card_id)
    rect.width /= 2
    rect.height /= 2
    rect.x += rect.width / 2
    rect.y += rect.height / 2
    return rect
}

draw_trigger :: proc(info: ^DrawInfo, trigger: Trigger) {
    bounds := trigger_bounds(trigger)
    posn := rl.Vector2{ bounds.x, bounds.y}
    trigger_source := trigger_source(trigger)
    posn_rect := rl.Rectangle{posn.x, posn.y,
                              trigger_source.width, trigger_source.height}
	rl.DrawTexturePro(info.cards, trigger_source, posn_rect, rl.Vector2{0,0},
                      0, rl.GRAY)
}
