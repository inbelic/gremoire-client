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

GameContext :: struct {
    cur_cmd     : comms.GameCmd,
    cmd_active  : bool,
    loaded      : bool,
    num_cards   : u8,
    card_state  : Cards,
    order_ctx   : OrderContext,
    target_ctx  : TargetContext,
}

OrderContext :: struct {
    num_triggers : u8,
    triggers     : [128]AbilityIdx,
}

TargetContext :: struct {
    trigger     : AbilityIdx,
    num_targets : u8,
    targets     : [256]CardID,
}

reload_game_ctx :: proc(msg : ^comms.Message, game_ctx : ^GameContext) {
    switch v in msg.cmd {
        case comms.GameCmd: {
            reload_game_cmd(msg, game_ctx)
            game_ctx.cur_cmd = comms.GameCmd(v)
        }
        case comms.GeneralCmd:
        case comms.LobbyCmd:
    }
    game_ctx.cmd_active = true
    game_ctx.loaded = false
    return
}

reload_game_cmd :: proc(msg : ^comms.Message, game_ctx : ^GameContext) {
    switch msg.cmd {
        case comms.GameCmd.DISPLAY: reload_display(msg, game_ctx)
        case comms.GameCmd.ORDER: reload_order(msg, game_ctx)
        case comms.GameCmd.TARGET: reload_target(msg, game_ctx)
    }
    return
}

reload_display :: proc(msg : ^comms.Message, game_ctx : ^GameContext) {
    size    := msg.size
    buf     := &msg.info
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

        game_ctx.card_state[card_pos] = cur_card
        card_pos += 1
    }
    game_ctx.num_cards = card_pos
    return
}

reload_order :: proc(msg : ^comms.Message, game_ctx : ^GameContext) -> (ok : bool) {
    size := msg.size
    buf := &msg.info
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

        game_ctx.order_ctx.triggers[order_pos] = AbilityIdx{cardID, abilityID}
        order_pos += 1
    }
    game_ctx.order_ctx.num_triggers = order_pos
    ok = true
    return
}

reload_target :: proc(msg : ^comms.Message, game_ctx : ^GameContext) -> (ok : bool) {
    size := msg.size
    buf := &msg.info
    buf_idx := u8(0)

    if (size < buf_idx + 2) {
        ok = false
        return 
    }
    cardID :=  CardID(buf[buf_idx])
    buf_idx += 1
    abilityID := AbilityID(buf[buf_idx])
    buf_idx += 1

    game_ctx.target_ctx.trigger = AbilityIdx{cardID, abilityID}
    target_pos := u8(0)
    
    for buf_idx < size {
        cardID = CardID(buf[buf_idx])
        buf_idx += 1
        game_ctx.target_ctx.targets[target_pos] = cardID
        target_pos += 1
    }
    game_ctx.target_ctx.num_targets = target_pos

    ok = true
    return
}
