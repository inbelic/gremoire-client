package client

import fmt "core:fmt"

import s "core:slice"
import rl "vendor:raylib"

// Initilization RayLib constants
screenWidth :: i32(1920)
screenHeight :: i32(1080)

State :: struct {
    update_info: UpdateInfo,
	draw_info: DrawInfo,

	mailbox: ^MailBox,
	socket: ^SendSocket,
	msg: Message,
    comm_err: CommError,
}

main :: proc() {
    // Initialzie communications
    socket := new(Socket)
    defer free(socket)
    comm_err := dial_tcp(socket, "127.0.0.1:3565")
    recv_socket, send_socket := split_socket(socket)

    if comm_err != nil {
        fmt.println("no conn:", comm_err)
        return
    }

    mail_lock := MailLock{}
    mailbox := new(MailBox)
    mailbox^.lock = &mail_lock
    defer free(mailbox)

    data := new(MailData)
    data^.mailbox = mailbox
    data^.socket = recv_socket
    defer free(data)

    mail_man := employ_mailman(data)
    defer unemploy_mailman(mail_man)
	
    // Incoming declarations
    in_msg: Message
    recvd: bool

	// Initilization RayLib window
    rl.InitWindow(screenWidth, screenHeight, "ui prototype")
    defer rl.CloseWindow()


    // State initializations
    state := State{}

	state.socket = send_socket
	state.mailbox = mailbox

    // Initilization Custom "globals"
    cards_txtr := rl.LoadTexture("build/assets/cards.png")
    defer rl.UnloadTexture(cards_txtr)

    buttons_txtr := rl.LoadTexture("build/assets/buttons.png")
    defer rl.UnloadTexture(buttons_txtr)

    background_txtr := rl.LoadTexture("build/assets/background.png")
    defer rl.UnloadTexture(background_txtr)

    state.draw_info = DrawInfo{ cards_txtr, buttons_txtr }
    state.update_info = UpdateInfo{}

    ok_button := Button{rl.Rectangle{f32(screenWidth) - 256,
                                     f32(screenHeight) - 71,
                                     256, 71},
                        rl.Rectangle{0, 0, 256, 71}, false, false}

// TEMPORARY START
    // Test Login
    state.msg.cmd = LobbyCmd.LOGIN
    state.msg.size = 4
    state.msg.info[0] = 't'
    state.msg.info[1] = 'e'
    state.msg.info[2] = 's'
    state.msg.info[3] = 't'

    state.comm_err = send_message(state.socket, state.msg)
    if state.comm_err != nil {
        fmt.println("bad login:", state.comm_err)
    }

    // Test Start game
    state.msg.cmd = LobbyCmd.QUEUE
    state.msg.size = 4
    state.msg.info[0] = 'c'
    state.msg.info[1] = 'o'
    state.msg.info[2] = 'n'
    state.msg.info[3] = 'f'
    state.comm_err = send_message(state.socket, state.msg)

    if state.comm_err != nil {
        fmt.println("bad queue:", state.comm_err)
    }
// TEMPORARY END

    // Some helpful references
    game := &state.update_info.game

    // Main Interactive Loop
    for !rl.WindowShouldClose() {
        // Checking mailbox
        in_msg, recvd = check_mailbox(mailbox).?
        if recvd {
            reload_game_ctx(&in_msg, game)
        }

        // Update
        fill_info(&state.update_info)

        if game.cur_cmd == GameCmd.ORDER {
            for _, i in game.order_ctx.triggers {
                update_trigger(&state.update_info, &game.order_ctx.triggers[i])
            }
        }

        for card, i in game.cards {
            update_card(&state.update_info, &game.cards[i])
        }
        
        update_button(&state.update_info, &ok_button)

        // Update card update/draw ordering
        for card, i in game.cards {
            if card.id == state.update_info.mouse.top_card {
                s.swap(game.cards[:], 0, i)
                break
            }
        }

        // Update the mailbox if we are sending a message depending on type
        // of cmd
		if game.cmd_active {
            send := false
            #partial switch game.cur_cmd {
                case GameCmd.DISPLAY: {
                    state.msg.cmd = GameCmd.DISPLAY
                    state.msg.size = 0
                    send = true
                }
                case GameCmd.ORDER: {
                    if ok_button.pressed {
                        // Def our sort function
                        fun :: proc(i: Trigger, j: Trigger) -> bool {
                            return i.order < j.order
                        }
                        s.sort_by(game.order_ctx.triggers[:], fun)
                        
                        state.msg.size = 0
                        state.msg.cmd = GameCmd.ORDER
                        for trigger, i in game.order_ctx.triggers {
                            state.msg.info[i] = u8(trigger.posn)
                            state.msg.size += 1
                        }
                        send = true
                    }
                }
                case GameCmd.TARGET: {
                    if ok_button.pressed {
                        state.msg.cmd = GameCmd.TARGET
                        state.msg.size = 1
                        state.msg.info[0] = u8(game.target_ctx.target)
                        send = true
                    }
                }
            }
            if send {
                fmt.print("sent message")
                fmt.println(state.msg)
                state.comm_err = send_message(state.socket, state.msg)
                game.cmd_active = false
                ok_button.pressed = false
            }
        }

        // Drawing
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)
        rl.DrawTexture(background_txtr, 0, 0, rl.WHITE)

        #reverse for card in game.cards {
            draw_card(&state.draw_info, card)
        }

        if state.update_info.response_ready {
            draw_button(&state.draw_info, ok_button)
        }

        if game.cur_cmd == GameCmd.ORDER {
            for trigger in game.order_ctx.triggers {
                draw_trigger(&state.draw_info, trigger)
            }
        }
        if game.cur_cmd == GameCmd.TARGET {
            draw_trigger(&state.draw_info, game.target_ctx.trigger)
        }

        rl.EndDrawing()
	}

    // Ping server to denote that we are exiting (should be changed to EXIT or
    // some better description)
    state.msg.cmd = GeneralCmd.ECHO
    state.msg.size = 0
    state.comm_err = send_message(state.socket, state.msg)
    if state.comm_err != nil {
        fmt.println("bad exit:", state.comm_err)
    }

    return
}
