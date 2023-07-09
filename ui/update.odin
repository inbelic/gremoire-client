package ui

import comms "../comms"
import game "../game"

UpdateInfo :: struct {
    mouse: MouseInfo,
    order: OrderInfo,
    target: TargetInfo,

    response_ready: bool,
}

// TODO:
// REFACTOR: This info structs should be merged with their corresponding
// Contexts in Game. (Most likely just remove these)
OrderInfo :: struct {
    card_heads: [dynamic]CardHead,
    selected: bool,
    ordered: u8,
}

TargetInfo :: struct {
    card_head: CardHead,
    card_ids: [dynamic]game.CardID,
    targeted: bool,
    target: game.CardID,
}

update_info :: proc(info: ^UpdateInfo, game_ctx: ^game.GameContext) {
    update_mouse(&info.mouse)

    info.response_ready = false
    info.order.selected = false

    if game_ctx.cmd_active {
        #partial switch game_ctx.cur_cmd {
            case comms.GameCmd.ORDER: {
                // Load the triggers to be ordered into the card_heads
                if !game_ctx.loaded {
                    clear(&info.order.card_heads)
                    info.order.ordered = 0
                    for i in 0..<game_ctx.order_ctx.num_triggers {
                        ability_idx := game_ctx.order_ctx.triggers[i]
                        card_head := CardHead{ability_idx.cID, ability_idx.aID, i, i + 1, false}
                        append(&info.order.card_heads, card_head)
                    }
                    game_ctx.loaded = true
                // Or check if all the triggers have been ordered
                } else if info.order.ordered == game_ctx.order_ctx.num_triggers {
                   info.response_ready = true 
                }
            }
            case comms.GameCmd.TARGET: {
                if !game_ctx.loaded {
                    ability_idx := game_ctx.target_ctx.trigger
                    info.target.card_head = CardHead{ability_idx.cID, ability_idx.aID, 0, 0, false}
                    clear(&info.target.card_ids)
                    optional := false
                    for i in 0..<game_ctx.target_ctx.num_targets {
                        x := game_ctx.target_ctx.targets[i]
                        if x == 0 {
                            optional = true
                        }
                        append(&info.target.card_ids, x)
                    }
                    if optional {
                        info.target.targeted = true
                        info.target.target = 0
                    } else {
                        info.target.targeted = false
                    }
                }
                if info.target.targeted {
                    info.response_ready = true
                }
            }
        }
    }
}
