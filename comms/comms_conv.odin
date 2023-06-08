package comms

import "../card"

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
StartedRequest :: struct {}

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

to_request :: proc(msg : ^Message) -> (req : Request) {
    switch in msg^.cmd {
        case GeneralCmd:  req = to_general_request(msg)
        case LobbyCmd:    req = to_lobby_request(msg)
        case GameCmd:     req = to_game_request(msg)
    }
    return
}

to_general_request :: proc(msg : ^Message) -> (req : GeneralRequest) {
    switch msg^.cmd {
        case GeneralCmd.OK:        req = ValidityRequest{true}
        case GeneralCmd.INVALID:   req = ValidityRequest{false}
        case GeneralCmd.ECHO:      req = EchoRequest{msg^.info} // Copy info for now...
    }
    return
}

to_lobby_request :: proc(msg : ^Message) -> (req : LobbyRequest) {
    switch msg^.cmd {
        case LobbyCmd.STARTED:   req = StartedRequest{}
    }
    return
}

to_game_request :: proc(msg : ^Message) -> (req : GameRequest) {
    switch msg^.cmd {
        case GameCmd.DISPLAY:   req = to_display_request(msg)
        case GameCmd.ORDER:     req = to_order_request(msg)
        case GameCmd.TARGET:    req = to_target_request(msg)
        case GameCmd.RESULT:    req = ResultRequest{msg^.info[0] > 0}
    }
    return
}

to_display_request :: proc(msg : ^Message) -> (req : DisplayRequest) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    card_pos := u8(0)

    field : card.Field
    val : u8
    field_bytes : u8
    for buf_idx < size {
        cur_card : card.Card

        // 0 denotes that the CardID is hidden so we store nil
        cur_card.id = cast(card.CardID)buf[buf_idx]
        buf_idx += 1
        // Check the number of bytes that the fields associated with the
        // current card require (2 * the number fields)
        field_bytes = buf[buf_idx] + buf_idx
        buf_idx += 1
        for buf_idx < field_bytes {
            field = card.Field(buf[buf_idx])
            buf_idx += 1

            val = buf[buf_idx]
            buf_idx += 1

            cur_card.fieldMap[field] = val
        }

        req.cards[card_pos] = cur_card
        card_pos += 1
    }
    return
}

to_order_request :: proc(msg : ^Message) -> (req : OrderRequest) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    cardID      : card.CardID
    abilityID   : card.AbilityID
    order_pos := u8(0)

    for buf_idx < size {
        cardID = card.CardID(buf[buf_idx])
        buf_idx += 1
        abilityID = card.AbilityID(buf[buf_idx])
        buf_idx += 1

        req.triggers[order_pos] = AbilityIdx{cardID, abilityID}
        order_pos += 1
    }
    req.size = order_pos
    return
}

to_target_request :: proc(msg : ^Message) -> (req : TargetRequest) {
    size := msg^.size
    buf := &msg^.info
    buf_idx := u8(0)

    cardID :=  card.CardID(buf[buf_idx])
    buf_idx += 1
    abilityID := card.AbilityID(buf[buf_idx])
    buf_idx += 1

    req.aIdx = AbilityIdx{cardID, abilityID}
    target_pos := u8(0)
    
    for buf_idx < size {
        cardID = card.CardID(buf[buf_idx])
        buf_idx += 1
        req.targets = cardID
    }

    req.size = buf_idx - 2

    return
}
