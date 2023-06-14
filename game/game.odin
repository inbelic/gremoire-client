package card

import comms "../comms"
import rl "vendor:raylib"

// Defines the various components of a card on the client side

CardID      :: distinct u8
AbilityID   :: distinct u8
StatementID :: distinct u8
Cards       :: [256]Card

AbilityIdx :: struct {
    cID : CardID,
    aID : AbilityID,
}

// Corresponding to Core.Fields of the game instance
Field :: enum u8 {
    Revealed, ActiveFlag, AttackFlag,
    Nominated,                          // Flags
    //////////////////////////////////////
    Zone, Phase,                        // Enums
    SetID, CardNum, Owner, Position,
    //////////////////////////////////////
    Power, Toughness,                   // U8
}

Card :: struct {
    id : CardID,    // 0 denotes that the card is hidden and is NOT the card id
    fieldMap : map[Field]u8,
    abilities : map[AbilityID]StatementID,
}

GameCtx :: struct {
    cur_cmd     : comms.GameCmd,
    display_ctx : DisplayCtx,
    order_ctx   : OrderCtx,
    target_ctx  : TargetCtx,
}

DisplayCtx :: struct {
    num_cards   : u8,
    card_state  : Cards,
    responded   : bool,
}

OrderCtx :: struct {
    num_triggers : u8,
    triggers     : [256]AbilityIdx,
    num_orders   : u8,
    out_order    : [256]u8,
}

TargetCtx :: struct {
    trigger     : AbilityIdx,
    num_targets : u8,
    targets     : [256]CardID,
    targeted    : bool,
    targetCID   : CardID,
}

reload_game_ctx :: proc(msg : ^comms.Message, game_ctx : ^GameCtx) {
    switch v in msg^.cmd {
        case comms.GameCmd: {
            reload_game_cmd(msg, game_ctx)
            game_ctx^.cur_cmd = comms.GameCmd(v)
        }
        case comms.GeneralCmd:
        case comms.LobbyCmd:
    }
    return
}

reload_game_cmd :: proc(msg : ^comms.Message, game_ctx : ^GameCtx) {
    switch msg^.cmd {
        case comms.GameCmd.DISPLAY: reload_display(msg, game_ctx)
        case comms.GameCmd.ORDER: reload_order(msg, game_ctx)
        case comms.GameCmd.TARGET: reload_target(msg, game_ctx)
    }
    return
}

reload_display :: proc(msg : ^comms.Message, game_ctx : ^GameCtx) {
    size    := msg^.size
    buf     := &msg^.info
    buf_idx := u8(0)

    card_pos := u8(0)

    field           : Field
    val             : u8
    field_bytes     : u8

    ability_bytes   : u8
    abilityID       : AbilityID
    statementID     : StatementID

    for buf_idx < size {
        cur_card : Card

        if (size < buf_idx + 2) {
            return 
        }
        // 0 denotes that the CardID is hidden so we store nil
        cur_card.id = CardID(buf[buf_idx])
        buf_idx += 1
        // Check the number of bytes that the fields associated with the
        // current card require (2 * the number fields)
        field_bytes = buf[buf_idx] + buf_idx + 1
        buf_idx += 1

        if (size < field_bytes) {
            return 
        }
        for buf_idx < field_bytes {
            field = Field(buf[buf_idx])
            buf_idx += 1

            val = buf[buf_idx]
            buf_idx += 1

            cur_card.fieldMap[field] = val
        }

        ability_bytes = buf[buf_idx] + buf_idx + 1
        buf_idx += 1
        if (size < ability_bytes) {
            return 
        }

        // Could probably use append here instead but will keep it consistent
        // with the rest of the implementation
        for buf_idx < ability_bytes {
            abilityID = AbilityID(buf[buf_idx])
            buf_idx += 1
            statementID = StatementID(buf[buf_idx])
            buf_idx += 1

            cur_card.abilities[abilityID] = statementID
        }

        game_ctx^.display_ctx.card_state[card_pos] = cur_card
        card_pos += 1
    }
    game_ctx^.display_ctx.num_cards = card_pos
    game_ctx^.display_ctx.responded = false
    return
}

reload_order :: proc(msg : ^comms.Message, game_ctx : ^GameCtx) -> (ok : bool) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    cardID      : CardID
    abilityID   : AbilityID
    order_pos := u8(0)

    for buf_idx < size {
        if (size < buf_idx + 2) {
            return false
        }
        cardID = CardID(buf[buf_idx])
        buf_idx += 1
        abilityID = AbilityID(buf[buf_idx])
        buf_idx += 1

        game_ctx^.order_ctx.triggers[order_pos] = AbilityIdx{cardID, abilityID}
        order_pos += 1
    }
    game_ctx^.order_ctx.num_triggers = order_pos
    ok = true
    return
}

reload_target :: proc(msg : ^comms.Message, game_ctx : ^GameCtx) -> (ok : bool) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    if (size < buf_idx + 2) {
        ok = false
        return 
    }
    cardID :=  CardID(buf[buf_idx])
    buf_idx += 1
    abilityID := AbilityID(buf[buf_idx])
    buf_idx += 1

    game_ctx^.target_ctx.trigger = AbilityIdx{cardID, abilityID}
    target_pos := u8(0)
    
    for buf_idx < size {
        cardID = CardID(buf[buf_idx])
        buf_idx += 1
        game_ctx^.target_ctx.targets[target_pos] = cardID
        target_pos += 1
    }
    game_ctx^.target_ctx.num_targets = target_pos
    game_ctx^.target_ctx.targeted = false

    ok = true
    return
}
