package comms

import "../card"
import endian "core:encoding/endian"

AbilityIdx :: struct {
    cID : card.CardID,
    aID : card.AbilityID,
}

// Sub-package to convert the info field of a Message into a Request

Request :: union {
    GeneralRequest,
    LobbyRequest,
    GameRequest,
}

GeneralRequest :: union {
    ValidityRequest,
    EchoRequest,
}

LobbyRequest :: union {
    StartedRequest,
}

GameRequest :: union {
    DisplayRequest,
    OrderRequest,
    TargetRequest,
    ResultRequest,
}

// General Requests
ValidityRequest :: struct {
    valid : bool,
}
EchoRequest :: struct {
    contents : [254]u8,
}

// Lobby Requests
StartedRequest :: struct {
    game_id : u32,
}

// Game Requests
DisplayRequest :: struct {
    cards : card.Cards,
}

OrderRequest :: struct {
    size        : u8, // number of triggers to order
    triggers    : [127]AbilityIdx, // maximum is 127 since 254 / 2 = 127
}

TargetRequest :: struct {
    aIdx        : AbilityIdx, // index of card and ability we need to target
    size        : u8, // number of potential targets
    targets     : [254]card.CardID,   // maximum number of targets is 254
}

ResultRequest :: struct {
    result      : bool,  // Just denote if we won or not
}

to_request :: proc(msg : ^Message) -> (req : Request, ok : bool) {
    switch in msg^.cmd {
        case GeneralCmd:  req, ok = to_general_request(msg)
        case LobbyCmd:    req, ok = to_lobby_request(msg)
        case GameCmd:     req, ok = to_game_request(msg)
    }
    return
}

to_general_request :: proc(msg : ^Message) -> (req : GeneralRequest, ok : bool) {
    switch msg^.cmd {
        case GeneralCmd.OK:        req = ValidityRequest{true}
        case GeneralCmd.INVALID:   req = ValidityRequest{false}
        case GeneralCmd.ECHO:      req = EchoRequest{msg^.info} // Copy info for now...
    }
    ok = true
    return
}

to_lobby_request :: proc(msg : ^Message) -> (req : LobbyRequest, ok : bool) {
    switch msg^.cmd {
        case LobbyCmd.STARTED: req, ok = to_started_request(msg)
    }
    return
}

to_started_request :: proc(msg : ^Message) -> (req : StartedRequest, ok : bool) {
    req.game_id, ok = endian.get_u32(msg^.info[0:4], endian.Byte_Order.Big)
    return
}

to_game_request :: proc(msg : ^Message) -> (req : GameRequest, ok : bool) {
    switch msg^.cmd {
        case GameCmd.DISPLAY:   req, ok = to_display_request(msg)
        case GameCmd.ORDER:     req, ok = to_order_request(msg)
        case GameCmd.TARGET:    req, ok = to_target_request(msg)
        case GameCmd.RESULT:    req, ok = to_result_request(msg)
    }
    return
}

to_display_request :: proc(msg : ^Message) -> (req : DisplayRequest, ok : bool) {
    size    := msg^.size
    buf     := &msg^.info
    buf_idx := u8(0)

    card_pos := u8(0)

    field           : card.Field
    val             : u8
    field_bytes     : u8
    ability_bytes   : u8
    for buf_idx < size {
        cur_card : card.Card

        if (size < buf_idx + 2) {
            ok = false
            return 
        }
        // 0 denotes that the CardID is hidden so we store nil
        cur_card.id = cast(card.CardID)buf[buf_idx]
        buf_idx += 1
        // Check the number of bytes that the fields associated with the
        // current card require (2 * the number fields)
        field_bytes = buf[buf_idx] + buf_idx + 1
        buf_idx += 1

        if (size < field_bytes) {
            ok = false
            return 
        }
        for buf_idx < field_bytes {
            field = card.Field(buf[buf_idx])
            buf_idx += 1

            val = buf[buf_idx]
            buf_idx += 1

            cur_card.fieldMap[field] = val
        }

        ability_bytes = buf[buf_idx] + buf_idx + 1
        buf_idx += 1
        if (size < ability_bytes) {
            ok = false
            return 
        }

        // Could probably use append here instead but will keep it consistent
        // with the rest of the implementation
        for buf_idx < ability_bytes {
            append(&cur_card.abilities, card.AbilityID(buf[buf_idx]))
            buf_idx += 1
        }

        req.cards[card_pos] = cur_card
        card_pos += 1
    }
    ok = true
    return
}

to_order_request :: proc(msg : ^Message) -> (req : OrderRequest, ok : bool) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    cardID      : card.CardID
    abilityID   : card.AbilityID
    order_pos := u8(0)

    for buf_idx < size {
        if (size < buf_idx + 3) {
            ok = false
            return 
        }
        cardID = card.CardID(buf[buf_idx])
        buf_idx += 1
        abilityID = card.AbilityID(buf[buf_idx])
        buf_idx += 1

        req.triggers[order_pos] = AbilityIdx{cardID, abilityID}
        order_pos += 1
    }
    req.size = order_pos
    ok = true
    return
}

to_target_request :: proc(msg : ^Message) -> (req : TargetRequest, ok : bool) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    if (size < buf_idx + 2) {
        ok = false
        return 
    }
    cardID :=  card.CardID(buf[buf_idx])
    buf_idx += 1
    abilityID := card.AbilityID(buf[buf_idx])
    buf_idx += 1

    req.aIdx = AbilityIdx{cardID, abilityID}
    target_pos := u8(0)
    
    for buf_idx < size {
        cardID = card.CardID(buf[buf_idx])
        buf_idx += 1
        req.targets[target_pos] = cardID
        target_pos += 1
    }

    req.size = target_pos

    ok = true
    return
}

to_result_request :: proc(msg : ^Message) -> (req : ResultRequest, ok : bool) {
    req = ResultRequest{msg^.info[0] > 0}
    ok = true
    return
}
