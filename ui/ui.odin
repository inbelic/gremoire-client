package ui

import fmt "core:fmt"
import "core:c/libc"
import s "core:slice"
import rl "vendor:raylib"

import comms "../comms"
import game "../game"

// This package defines the main loop when we are running with a ui

State :: struct {
	game_ctx		: game.GameContext,
	draw_ctx		: DrawContext,

	mailbox			: ^comms.MailBox,
	socket			: ^comms.SendSocket,
	msg				: comms.Message,
    comm_err    	: comms.Comm_Error,
}

DrawContext :: struct {
    cards : rl.Texture,
    buttons: rl.Texture,
}

// Initilization RayLib constants
screenWidth :: i32(1920)
screenHeight :: i32(1080)
    
// Constants for position of ordered/unordered CardHeads
orderedPosn     := rl.Vector2{f32(screenWidth) / 4, f32(screenHeight) / 8}
unorderedPosn   := rl.Vector2{f32(screenWidth) / 4, f32(screenHeight) / 8 + 128}

ui_main :: proc(socket : ^comms.SendSocket, mailbox : ^comms.MailBox) {
	state := State{}
    
	// Initilization RayLib window
    rl.InitWindow(screenWidth, screenHeight, "ui prototype")
    defer rl.CloseWindow()

	// State initializations
	state.socket = socket
	state.mailbox = mailbox

    // Incomings comms declarations
    in_msg      : comms.Message
    recvd       : bool

    // Initilization Custom "globals"
    cards_txtr := rl.LoadTexture("build/assets/cards.png")
    defer rl.UnloadTexture(cards_txtr)

    buttons_txtr := rl.LoadTexture("build/assets/buttons.png")
    defer rl.UnloadTexture(buttons_txtr)

    ctx := DrawContext{ cards_txtr, buttons_txtr }

    // Init entities
    cards : [dynamic]Card
    append(&cards, Card{1, rl.Vector2{128, 128}, 1, rl.Vector2{128, 128}})
    append(&cards, Card{2, rl.Vector2{384, 384}, 1, rl.Vector2{384, 384}})

    ok_button := Button{rl.Rectangle{f32(screenWidth) - 256,
                                     f32(screenHeight) - 71,
                                     256, 71},
                        rl.Rectangle{0, 0, 256, 71}, false, false}

    info := UpdateInfo{}

// TEMPORARY START
    // Test Login
    state.msg.cmd = comms.LobbyCmd.LOGIN
    state.msg.size = 4
    state.msg.info[0] = 't'
    state.msg.info[1] = 'e'
    state.msg.info[2] = 's'
    state.msg.info[3] = 't'

    state.comm_err = comms.send_message(state.socket, state.msg)
    if state.comm_err != nil {
        fmt.println("bad login:", state.comm_err)
    }

    // Test Start game
    state.msg.cmd = comms.LobbyCmd.QUEUE
    state.msg.size = 4
    state.msg.info[0] = 'c'
    state.msg.info[1] = 'o'
    state.msg.info[2] = 'n'
    state.msg.info[3] = 'f'
    state.comm_err = comms.send_message(state.socket, state.msg)
    if state.comm_err != nil {
        fmt.println("bad queue:", state.comm_err)
    }
// TEMPORARY END
    
    for !rl.WindowShouldClose() {
        // Checking mailbox
        in_msg, recvd = comms.check_mailbox(mailbox).?
        if recvd {
            game.reload_game_ctx(&in_msg, &state.game_ctx)
			fmt.println("got message")
            fmt.println(in_msg)
        }

        // Update
        update_info(&info, &state.game_ctx)

        if state.game_ctx.cur_cmd == comms.GameCmd.ORDER {
            for _, i in info.order.card_heads {
                update_card_head(&info, &info.order.card_heads[i])
            }
        }

        for card, i in cards {
            update_card(&info, &cards[i])
        }
        
        update_button(&info, &ok_button)

        // Update card update/draw ordering
        for card, i in cards {
            if card.card_id == info.mouse.top_card {
                s.swap(cards[:], 0, i)
                break
            }
        }

        // Update the mailbox if we are sending a message depending on type
        // of cmd
		if state.game_ctx.cmd_active {
            send := false
            #partial switch state.game_ctx.cur_cmd {
                case comms.GameCmd.DISPLAY: {
                    state.msg.cmd = comms.GameCmd.DISPLAY
                    state.msg.size = 0
                    send = true
                }
                case comms.GameCmd.ORDER: {
                    if ok_button.pressed {
                        fun := proc(i: CardHead, j: CardHead) -> bool {
                            return i.order < j.order
                        }
                        s.sort_by(info.order.card_heads[:], fun)
                        for card_head, i in info.order.card_heads {
                            state.msg.info[i] = u8(card_head.posn)
                        }
                        state.msg.cmd = comms.GameCmd.ORDER
                        state.msg.size = info.order.ordered
                        send = true
                    }
                }
                case comms.GameCmd.TARGET: {
                    if ok_button.pressed {
                        state.msg.cmd = comms.GameCmd.TARGET
                        state.msg.size = 1
                        state.msg.info[0] = u8(info.target.target)
                        send = true
                    }
                }
            }
            if send {
                fmt.print("sent message")
                fmt.println(state.msg)
                state.comm_err = comms.send_message(state.socket, state.msg)
                state.game_ctx.cmd_active = false
                ok_button.pressed = false
            }
        }

        // Drawing
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)
        #reverse for card in cards {
            draw_card(&ctx, card)
        }

        if info.response_ready {
            draw_button(&ctx, ok_button)
        }

        if state.game_ctx.cur_cmd == comms.GameCmd.ORDER {
            draw_card_heads(&ctx, &info.order.card_heads)
        }
        if state.game_ctx.cur_cmd == comms.GameCmd.TARGET {
            draw_card_head(&ctx, info.target.card_head)
        }

        rl.EndDrawing()
	}

    // Ping server to denote that we are exiting (should be changed to EXIT or
    // some better description)
    state.msg.cmd = comms.GeneralCmd.ECHO
    state.msg.size = 0
    state.comm_err = comms.send_message(state.socket, state.msg)
    if state.comm_err != nil {
        fmt.println("bad exit:", state.comm_err)
    }

    return
}
