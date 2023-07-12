package client

import s "core:slice"
import rl "vendor:raylib"

// General UpdateInfo for update_* functions
UpdateInfo :: struct {
    mouse: MouseInfo,
    game: GameContext,

    response_ready: bool,
}

fill_mouse :: proc(mouse_info: ^MouseInfo) {
    mouse_info.posn = rl.GetMousePosition()
    mouse_info.pressed = rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
    mouse_info.top_card = 0
}

// Update related functions
update_button :: proc(info: ^UpdateInfo, button: ^Button) {
    button.hovering = rl.CheckCollisionPointRec(info.mouse.posn, button.posn)
    button.pressed = false
    if button.hovering && info.mouse.pressed {
        button.pressed = true
    }
}

update_card :: proc(info: ^UpdateInfo, card: ^Card) {
    bounds := card_unscaled_bounds(card^)
    hovering := rl.CheckCollisionPointRec(info.mouse.posn, bounds)
    target_ctx := &info.game.target_ctx
    // Update card selection
    if info.mouse.pressed {
        if hovering && !info.mouse.has_card {
            info.mouse.has_card = true
            info.mouse.cur_card = card.id
            if s.contains(target_ctx.target_ids[:], card.id) {
                target_ctx.targeted = true
                target_ctx.target = card.id
            }
        } else if info.mouse.has_card && info.mouse.cur_card == card.id {
            info.mouse.has_card = false
        }
    }

    // Dragging a card around
    if info.mouse.has_card && info.mouse.cur_card == card.id {
        card.dest = info.mouse.posn
    } else {
        card.dest = get_zone_dest(info.game.card_state, card.id, info.game.player_id)
    }
    card.posn = card.posn + 4*(card.dest - card.posn) * rl.GetFrameTime()

    // Update card scale
    if hovering && !info.mouse.has_card && info.mouse.top_card == 0 {
        card.scale = min(card.scale + 0.002, 1.5)
        info.mouse.top_card = card.id
    } else {
        card.scale = max(card.scale - 0.002, 1)
    }
    if info.mouse.has_card && info.mouse.cur_card == card.id {
        card.scale = 1.5
    }
}

update_trigger :: proc(info: ^UpdateInfo, trigger: ^Trigger) {
    order_ctx := &info.game.order_ctx
    bounds := trigger_bounds(trigger^)
    hovering := rl.CheckCollisionPointRec(info.mouse.posn, bounds)
    if hovering && info.mouse.pressed && !order_ctx.selected {
        trigger.order = get_next_order(&order_ctx.triggers, !trigger.selected)
        trigger.selected = !trigger.selected
        if trigger.selected {
            order_ctx.ordered -= 1
        } else {
            order_ctx.ordered += 1
        }
        // Set selected so we don't get accidently double queues
        // shouldn't be needed if we space triggers so there is no overlap
        order_ctx.selected = true
    }
}

fill_info :: proc(info: ^UpdateInfo) {
    fill_mouse(&info.mouse)
    
    info.response_ready = false
    info.game.order_ctx.selected = false

    if info.game.cmd_active {
        #partial switch info.game.cur_cmd {
            case GameCmd.ORDER: {
                info.response_ready = (info.game.order_ctx.ordered == 0)
            }
            case GameCmd.TARGET: {
                info.response_ready = info.game.target_ctx.targeted
            }
        }
    }
}

// Determine the (resting) destination of a card based on its zone
get_zone_dest :: proc(state: [dynamic]CardData, id: CardID, player_id: u8) -> (posn: rl.Vector2) {
    sw :: f32(screenWidth)
    sh :: f32(screenHeight)
    handBase :: rl.Vector2{ sw / 4, sh - 135 }
    stackBase :: rl.Vector2{ sw / 4, sh - 390 }
    throneBase :: rl.Vector2{ 128, sh - 128 }
    barrackBase :: rl.Vector2{ sw / 4, sh - (sh / 4) }
    battleBase :: rl.Vector2{ sw / 4, sh - (sh / 3) }
    posn = rl.Vector2{-129, -129}
    card_data, ok := get_card_data(id, state)
    if ok {
        val, exists := card_data.field_map[Field.Zone]
        if exists {
            #partial switch Zone(val) {
                case Zone.Hand: posn = handBase
                case Zone.Stack: posn = stackBase
                case Zone.Throne: posn = throneBase
                case Zone.Barrack: posn = barrackBase
                case Zone.Battlefield: posn = battleBase
            }
        }
        val, exists = card_data.field_map[Field.Position]
        if exists {
            posn += rl.Vector2{260 * f32(val), 0}
        }
        val, exists = card_data.field_map[Field.Owner]
        if exists {
            if val != player_id {
                posn.y = f32(screenHeight) - posn.y
            }
        }
    }
    return posn
}
