package client

import rl "vendor:raylib"

// Genernal DrawInfo for draw_* functions
DrawInfo :: struct {
    cards : [dynamic]rl.Texture,
    buttons: rl.Texture,

    card_state: ^[dynamic]Card,
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
    id: CardID,
    posn: rl.Vector2,   // Origin is set to be the center of the image
    scale: f32,         // 1 is 256x256 pixels

    // Card movement
    dest: rl.Vector2,

    data: CardData,
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

card_source :: proc(card_num: u8) -> rl.Rectangle {
    txtr_id := int(card_num) - 1 // Account for offset of CardID starting at 1
    txtr_x := txtr_id % 8
    txtr_y := txtr_id / 8
    return rl.Rectangle{f32(txtr_x) * 256, f32(txtr_y) * 0, 256, 256}
}

draw_card :: proc(info: ^DrawInfo, card: Card) {
    frame_source :: rl.Rectangle{0, 0, 256, 256}

    source := rl.Rectangle{256, 0, 256, 256} // Cardback
    posn_rect := card_bounds(card)
    set_id := get_field(Field.SetID, 0, card.data)
    card_num := get_field(Field.CardNum, 0, card.data)
    if set_id * card_num != 0 {
        source = card_source(card_num)
    }
	rl.DrawTexturePro(info.cards[set_id], source, posn_rect,
                      rl.Vector2{0, 0}, 0, rl.WHITE)
	rl.DrawTexturePro(info.cards[0], frame_source, posn_rect,
                      rl.Vector2{0, 0}, 0, rl.WHITE)
}

// Trigger components
trigger_bounds :: proc(trigger: Trigger) -> rl.Rectangle {
    @static orderedPosn     := rl.Vector2{f32(screenWidth) / 4, f32(screenHeight) / 2 - 64}
    @static unorderedPosn   := rl.Vector2{f32(screenWidth) / 4, f32(screenHeight) / 2 + 64}

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

trigger_source :: proc(card_num: u8) -> rl.Rectangle {
    rect := card_source(card_num)
    rect.width /= 2
    rect.height /= 2
    rect.x += rect.width / 2
    rect.y += rect.height / 2
    return rect
}

draw_trigger :: proc(info: ^DrawInfo, trigger: Trigger) {
    bounds := trigger_bounds(trigger)
    posn := rl.Vector2{bounds.x, bounds.y}

    source := rl.Rectangle{256 + 64, 64, 128, 128} // Cardback
    card_data, ok := get_card(trigger.card_id, info.card_state^)
    set_id := get_field(Field.SetID, 0, card_data)
    card_num := get_field(Field.CardNum, 0, card_data)
    if set_id * card_num != 0 {
        source = trigger_source(card_num)
    }
    posn_rect := rl.Rectangle{posn.x, posn.y, source.width, source.height}
	rl.DrawTexturePro(info.cards[set_id], source, posn_rect, rl.Vector2{0,0}, 0, rl.GRAY)
}
