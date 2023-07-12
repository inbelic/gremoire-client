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

Zone :: enum u8 {
    Hand, TopDeck, MidDeck, BotDeck,
    Stack, Throne, Barrack, Battlefield,
    Cemetery,
}

// Defines the various components of a card on the client side
CardID :: distinct u8
AbilityID :: distinct u8
StatementID :: distinct u8

CardData :: struct {
    id: CardID,    // 0 denotes that the card is hidden and is NOT the card id
    field_map: map[Field]u8,
    abilities: map[AbilityID]StatementID,
}

get_field :: proc(field: Field, default: u8, card_data: CardData) -> u8 {
    val, exists := card_data.field_map[field]
    if exists {
        return val
    }
    return default
}

get_card :: proc(id: CardID, state: [dynamic]Card) -> (CardData, bool) {
    for card in state {
        if card.id == id {
            return card.data, true
        }
    }
    return Card{}.data, false
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
    player_id: u8,

    cur_cmd: GameCmd,
    cmd_active: bool,

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

reload_cards :: proc(game_ctx: ^GameContext, state: [dynamic]CardData) {
    new_cards: [dynamic]Card
    defer delete(new_cards)

    num_cards := len(game_ctx.cards)
    card_ids := make([dynamic]CardID, num_cards, num_cards)
    defer delete(card_ids)

    for card, i in game_ctx.cards[:] {
        card_ids[i] = card.id
    }

    for card_data in state {
        cur_id := card_data.id
        if cur_id != 0 {
            index, found := s.linear_search(card_ids[:], cur_id)
            card : Card
            if found {
                // If found, then 'update' the card rather than create a new one
                card = game_ctx.cards[index]
            }
            card.data = card_data
            card.id = card.data.id
            append(&new_cards, card)
        } else {
            if is_card_visible(card_data) {
                append(&new_cards, Card{card_data.id, rl.Vector2{0,0}, 1,
                                        rl.Vector2{0, 0}, card_data})
            }
        }
    }

    clear(&game_ctx.cards)
    for card in new_cards {
        append(&game_ctx.cards, card)
    }
}

reload_display :: proc(msg : ^Message, game_ctx: ^GameContext) {
    size := msg.size
    buf := &msg.info
    if size < 1 {
        return
    }
    game_ctx.player_id = buf[0]
    buf_idx := u8(1)

    field: Field
    val: u8
    field_bytes: u8

    ability_bytes: u8
    abilityID: AbilityID
    statementID: StatementID

    state : [dynamic]CardData
    defer delete(state)
    for buf_idx < size {
        cur_card: CardData

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

            cur_card.field_map[field] = val
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

        append(&state, cur_card)
    }

    reload_cards(game_ctx, state)
    return
}

// A card being visible means that you can see it in the ui, it does not mean
// you can see the front side of the card. It may have a CardID of 0 and hence
// be just the backside
is_card_visible :: proc(cur_card: CardData) -> bool {
    zone := Zone(get_field(Field.Zone, 1, cur_card))
    if !(zone == Zone.TopDeck || zone == Zone.MidDeck || zone == Zone.BotDeck) {
        return true
    }
    if get_field(Field.Revealed, 0, cur_card) == 1 {
        return true
    }
    return false
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
