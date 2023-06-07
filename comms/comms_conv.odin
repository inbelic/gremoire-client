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
DisplayRequest :: struct {}

OrderRequest :: struct {
    size        : u8, // number of triggers to urder
    triggers    : [127]AbilityIdx, // maximum is 127 since 254 / 2 = 127
    order       : [127]u8, // the output of orders that we will respond with
}

TargetRequest :: struct {
    aIdx        : AbilityIdx, // index of card and ability we need to target
    size        : u8, // number of potential targets
    targets     : [254]u8,   // maximum number of targets is 254
    target      : card.CardID, // the output of which card we will target
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
    switch msg.cmd {
        case GameCmd.DISPLAY:   req = to_display_request(msg)
        case GameCmd.ORDER:     req = to_order_request(msg)
        case GameCmd.TARGET:    req = to_target_request(msg)
        case GameCmd.RESULT:    req = ResultRequest{msg^.info[0] > 0}
    }
    return
}

to_display_request :: proc(msg : ^Message) -> (req : DisplayRequest) {
    return
}

to_order_request :: proc(msg : ^Message) -> (req : OrderRequest) {
    return
}

to_target_request :: proc(msg : ^Message) -> (req : TargetRequest) {
    return
}
