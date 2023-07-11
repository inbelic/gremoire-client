package client

import rl "vendor:raylib"
import s "core:slice"

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

// Defines the various components of a card on the client side
CardID :: distinct u8
AbilityID :: distinct u8
StatementID :: distinct u8

CardData :: struct {
    id: CardID,    // 0 denotes that the card is hidden and is NOT the card id
    fieldMap: map[Field]u8,
    abilities: map[AbilityID]StatementID,
}

// A CardHead is used to visually denote the order of a cards ability when
// ordering triggered abilities
Trigger :: struct {
    card_id: CardID,
    ability_id: AbilityID,
    statement_id: StatementID,
    order: u8,
    posn: u8,
    selected: bool,
}

GameContext :: struct {
    cur_cmd: GameCmd,
    cmd_active: bool,

    card_state: [dynamic]CardData,
    cards: [dynamic]Card,

    order_ctx: OrderContext,
    target_ctx: TargetContext,
}

OrderContext :: struct {
    triggers: [dynamic]Trigger,
    selected: bool,
    ordered: u8,
}

TargetContext :: struct {
    trigger: Trigger,
    target_ids: [dynamic]CardID,
    targeted: bool,
    target: CardID,
}

reload_game_ctx :: proc(msg : ^Message, game_ctx : ^GameContext) {
    switch v in msg.cmd {
        case GameCmd: {
            reload_game_cmd(msg, game_ctx)
            game_ctx.cur_cmd = GameCmd(v)
        }
        case GeneralCmd:
        case LobbyCmd:
    }
    game_ctx.cmd_active = true
    return
}

reload_game_cmd :: proc(msg : ^Message, game_ctx : ^GameContext) {
    switch msg.cmd {
        case GameCmd.DISPLAY: reload_display(msg, game_ctx)
        case GameCmd.ORDER: reload_order(msg, game_ctx)
        case GameCmd.TARGET: reload_target(msg, game_ctx)
    }
    return
}

reload_cards :: proc(game_ctx: ^GameContext, card_ids: ^[dynamic]CardID) {
    new_cards: [dynamic]Card
    defer delete(new_cards)

    for card in game_ctx.cards {
        cur_id := card.card_id
        index, found := s.linear_search(card_ids[:], cur_id)
        if found {
            unordered_remove(card_ids, index)
            append(&new_cards, card)
        }
    }
    for card_id in card_ids {
        append(&new_cards, Card{card_id, rl.Vector2{0,0}, 1, rl.Vector2{0, 0}})
    }
    clear(&game_ctx.cards)
    for card in new_cards {
        append(&game_ctx.cards, card)
    }
}

reload_display :: proc(msg : ^Message, game_ctx: ^GameContext) {
    size := msg.size
    buf := &msg.info
    buf_idx := u8(0)


    field: Field
    val: u8
    field_bytes: u8

    ability_bytes: u8
    abilityID: AbilityID
    statementID: StatementID

    card_ids: [dynamic]CardID
    defer delete(card_ids)

    clear(&game_ctx.card_state)
    for buf_idx < size {
        cur_card: CardData

        if (size < buf_idx + 2) {
            return 
        }
        // 0 denotes that the CardID is hidden so we store nil
        cur_card.id = CardID(buf[buf_idx])
        if cur_card.id != 0 {
            append(&card_ids, cur_card.id)
        }

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

        append(&game_ctx.card_state, cur_card)
    }

    reload_cards(game_ctx, &card_ids)
    return
}

reload_order :: proc(msg : ^Message, game_ctx : ^GameContext) -> (ok : bool) {
    size := msg.size
    buf := &msg.info
    buf_idx := u8(0)

    card_id: CardID
    ability_id: AbilityID
    order_pos := u8(0)

    clear(&game_ctx.order_ctx.triggers)
    for buf_idx < size {
        if (size < buf_idx + 2) {
            return false
        }
        card_id = CardID(buf[buf_idx])
        buf_idx += 1
        ability_id = AbilityID(buf[buf_idx])
        buf_idx += 1

        TODO_statement_id := StatementID(0)
        trigger := Trigger{card_id, ability_id, TODO_statement_id,
                           order_pos, order_pos + 1, false}
        append(&game_ctx.order_ctx.triggers, trigger)
        order_pos += 1
    }
    game_ctx.order_ctx.ordered = order_pos

    ok = true
    return
}

reload_target :: proc(msg : ^Message, game_ctx : ^GameContext) -> (ok : bool) {
    size := msg.size
    buf := &msg.info
    buf_idx := u8(0)

    if (size < buf_idx + 2) {
        ok = false
        return 
    }
    card_id :=  CardID(buf[buf_idx])
    buf_idx += 1
    ability_id := AbilityID(buf[buf_idx])
    buf_idx += 1

    TODO_statement_id := StatementID(0)
    game_ctx.target_ctx.trigger = Trigger{card_id, ability_id, TODO_statement_id,
                                          0, 0, false}
    
    clear(&game_ctx.target_ctx.target_ids)
    for buf_idx < size {
        card_id = CardID(buf[buf_idx])
        buf_idx += 1
        append(&game_ctx.target_ctx.target_ids, card_id)
    }

    ok = true
    return
}
