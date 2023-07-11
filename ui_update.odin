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
            info.mouse.cur_card = card.card_id
            if s.contains(target_ctx.target_ids[:], card.card_id) {
                target_ctx.targeted = true
                target_ctx.target = card.card_id
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
