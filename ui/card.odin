package ui

import rl "vendor:raylib"
import game "../game"
import s "core:slice"

Card :: struct {
    card_id: game.CardID,
    posn: rl.Vector2,   // Origin is set to be the center of the image
    scale: f32,         // 1 is 256x256 pixels

    // Card movement
    dest: rl.Vector2,
}

// A CardHead is used to visually denote the order of a cards ability when
// ordering triggered abilities
CardHead :: struct {
    card_id: game.CardID,
    ability_id: game.AbilityID,
    order: u8,
    posn: u8,
    selected: bool,
}

// General functions
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

card_head_bounds :: proc(card_head: CardHead) -> rl.Rectangle {
    bounds := rl.Rectangle{}
    bounds.width = 128
    bounds.height = 128
    if card_head.selected {
        bounds.x = orderedPosn.x + 128 * f32(card_head.order)
        bounds.y = orderedPosn.y
    } else {
        bounds.x = unorderedPosn.x + 128 * f32(card_head.order)
        bounds.y = unorderedPosn.y
    }
    return bounds
}

// Update related functions
update_card :: proc(info: ^UpdateInfo, card: ^Card) {
    bounds := card_unscaled_bounds(card^)
    hovering: = rl.CheckCollisionPointRec(info.mouse.posn, bounds)
    // Update card selection
    if info.mouse.pressed {
        if hovering && !info.mouse.has_card {
            info.mouse.has_card = true
            info.mouse.cur_card = card.card_id
            if s.contains(info.target.card_ids[:], card.card_id) {
                info.target.targeted = true
                info.target.target = card.card_id
            }
        } else if info.mouse.has_card && info.mouse.cur_card == card.card_id {
            info.mouse.has_card = false
        }
    }

    // Dragging a card around
    if info.mouse.has_card && info.mouse.cur_card == card.card_id {
        card.dest = info.mouse.posn
    }
    card.posn = card.posn + 4*(card.dest - card.posn) * rl.GetFrameTime()

    // Update card scale
    if hovering && !info.mouse.has_card && info.mouse.top_card == 0 {
        card.scale = min(card.scale + 0.002, 1.5)
        info.mouse.top_card = card.card_id
    } else {
        card.scale = max(card.scale - 0.002, 1)
    }
    if info.mouse.has_card && info.mouse.cur_card == card.card_id {
        card.scale = 1.5
    }
}

get_next_order :: proc(card_heads: ^[dynamic]CardHead, ordered: bool) -> u8 {
    posn := u8(0)
    for card_head in card_heads^ {
        if card_head.selected == ordered {
            posn += 1
        }
    }
    return posn
}

update_card_head :: proc(info: ^UpdateInfo, card_head: ^CardHead) {
    bounds := card_head_bounds(card_head^)
    hovering := rl.CheckCollisionPointRec(info.mouse.posn, bounds)
    if hovering && info.mouse.pressed && !info.order.selected {
        card_head.order = get_next_order(&info.order.card_heads, !card_head.selected)
        card_head.selected = !card_head.selected
        if card_head.selected {
            info.order.ordered += 1
        } else {
            info.order.ordered -= 1
        }
        info.order.selected = true
    }
}

// Drawing related functions
card_source :: proc(card_id: game.CardID) -> rl.Rectangle {
    txtr_id := int(card_id) + 1 // offset by 1 to account for the cardframe
    txtr_x := txtr_id % 8
    txtr_y := txtr_id / 8
    return rl.Rectangle{f32(txtr_x) * 256, f32(txtr_y) * 0, 256, 256}
}

card_head_source :: proc(card_id: game.CardID) -> rl.Rectangle {
    rect := card_source(card_id)
    rect.width /= 2
    rect.height /= 2
    rect.x += rect.width / 2
    rect.y += rect.height / 2
    return rect
}

draw_card :: proc(ctx: ^DrawContext, card: Card) {
    @static frame_source := rl.Rectangle{0, 0, 256, 256}

    card_source := card_source(card.card_id)
    posn_rect := card_bounds(card)
	rl.DrawTexturePro(ctx.cards, card_source, posn_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
	rl.DrawTexturePro(ctx.cards, frame_source, posn_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
}

draw_card_head :: proc(ctx: ^DrawContext, card_head: CardHead) {
    bounds := card_head_bounds(card_head)
    posn := rl.Vector2{ bounds.x, bounds.y}
    card_source := card_head_source(card_head.card_id)
    posn_rect := rl.Rectangle{posn.x, posn.y, card_source.width, card_source.height}
	rl.DrawTexturePro(ctx.cards, card_source, posn_rect, rl.Vector2{0,0}, 0, rl.GRAY)
}

draw_card_heads :: proc(ctx: ^DrawContext, card_heads: ^[dynamic]CardHead) {
    for card_head in card_heads^ {
        draw_card_head(ctx, card_head)
    }
}
