package ui

import fmt "core:fmt"
import "core:c/libc"
import slc "core:slice"

import SDL "vendor:sdl2"
import mu "vendor:microui"

import comms "../comms"
import game "../game"

// This package defines the main loop when we are running with a ui

state := struct {
	mu_ctx			: mu.Context,
	bg				: mu.Color,

	atlas_texture	: ^SDL.Texture,
	game_ctx		: game.GameCtx,

	mailbox			: ^comms.MailBox,
	socket			: ^comms.SendSocket,
	msg				: comms.Message,
    comm_err    	: comms.Comm_Error,
}{
	bg = {90, 95, 100, 255},
}


ui_main :: proc(socket : ^comms.SendSocket, mailbox : ^comms.MailBox) {
	// State initializations
	state.socket = socket
	state.mailbox = mailbox

    // Incomings comms declarations
    in_msg      : comms.Message
    recvd       : bool
	
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
    
    if err := SDL.Init({.VIDEO}); err != 0 {
		fmt.eprintln(err)
		return
	}
	defer SDL.Quit()

	window := SDL.CreateWindow("gremoire", SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, 1920, 1080, {.SHOWN, .RESIZABLE})
	if window == nil {
		fmt.eprintln(SDL.GetError())
		return
	}
	defer SDL.DestroyWindow(window)

	backend_idx: i32 = -1
	if n := SDL.GetNumRenderDrivers(); n <= 0 {
		fmt.eprintln("No render drivers available")
		return
	} else {
		for i in 0..<n {
			info: SDL.RendererInfo
			if err := SDL.GetRenderDriverInfo(i, &info); err == 0 {
				// NOTE(bill): "direct3d" seems to not work correctly
				if info.name == "opengl" {
					backend_idx = i
					break
				}
			}
		}
	}

	renderer := SDL.CreateRenderer(window, backend_idx, {.ACCELERATED, .PRESENTVSYNC})
	if renderer == nil {
		fmt.eprintln("SDL.CreateRenderer:", SDL.GetError())
		return
	}
	defer SDL.DestroyRenderer(renderer)

	state.atlas_texture = SDL.CreateTexture(renderer, u32(SDL.PixelFormatEnum.RGBA32), .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT)
	assert(state.atlas_texture != nil)
	if err := SDL.SetTextureBlendMode(state.atlas_texture, .BLEND); err != 0 {
		fmt.eprintln("SDL.SetTextureBlendMode:", err)
		return
	}

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH*mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i].rgb = 0xff
		pixels[i].a   = alpha
	}

	if err := SDL.UpdateTexture(state.atlas_texture, nil, raw_data(pixels), 4*mu.DEFAULT_ATLAS_WIDTH); err != 0 {
		fmt.eprintln("SDL.UpdateTexture:", err)
		return
	}

	ctx := &state.mu_ctx
	mu.init(ctx)

	ctx.text_width = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height

	main_loop: for {
		for e: SDL.Event; SDL.PollEvent(&e); /**/ {
			#partial switch e.type {
			case .QUIT:
				break main_loop
			case .MOUSEMOTION:
				mu.input_mouse_move(ctx, e.motion.x, e.motion.y)
			case .MOUSEWHEEL:
				mu.input_scroll(ctx, e.wheel.x * 30, e.wheel.y * -30)
			case .TEXTINPUT:
				mu.input_text(ctx, string(cstring(&e.text.text[0])))

			case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP:
				fn := mu.input_mouse_down if e.type == .MOUSEBUTTONDOWN else mu.input_mouse_up
				switch e.button.button {
				case SDL.BUTTON_LEFT:   fn(ctx, e.button.x, e.button.y, .LEFT)
				case SDL.BUTTON_MIDDLE: fn(ctx, e.button.x, e.button.y, .MIDDLE)
				case SDL.BUTTON_RIGHT:  fn(ctx, e.button.x, e.button.y, .RIGHT)
				}

			case .KEYDOWN, .KEYUP:
				if e.type == .KEYUP && e.key.keysym.sym == .ESCAPE {
					SDL.PushEvent(&SDL.Event{type = .QUIT})
				}

				fn := mu.input_key_down if e.type == .KEYDOWN else mu.input_key_up

				#partial switch e.key.keysym.sym {
				case .LSHIFT:    fn(ctx, .SHIFT)
				case .RSHIFT:    fn(ctx, .SHIFT)
				case .LCTRL:     fn(ctx, .CTRL)
				case .RCTRL:     fn(ctx, .CTRL)
				case .LALT:      fn(ctx, .ALT)
				case .RALT:      fn(ctx, .ALT)
				case .RETURN:    fn(ctx, .RETURN)
				case .KP_ENTER:  fn(ctx, .RETURN)
				case .BACKSPACE: fn(ctx, .BACKSPACE)
				}
			}
		}
        // Checking mailbox
        in_msg, recvd = comms.check_mailbox(mailbox).?
        if recvd {
            game.reload_game_ctx(&in_msg, &state.game_ctx)
			fmt.println("got message")
        }

		if state.game_ctx.cmd_active && state.game_ctx.cur_cmd == comms.GameCmd.DISPLAY {
			state.msg.cmd = comms.GameCmd.DISPLAY
			state.msg.size = 0
			state.comm_err = comms.send_message(state.socket, state.msg)
			state.game_ctx.cmd_active = false
		}

		mu.begin(ctx)
		all_windows(ctx, &state.game_ctx)
		mu.end(ctx)

		render(ctx, renderer)
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

render :: proc(ctx: ^mu.Context, renderer: ^SDL.Renderer) {
	render_texture :: proc(renderer: ^SDL.Renderer, dst: ^SDL.Rect, src: mu.Rect, color: mu.Color) {
		dst.w = src.w
		dst.h = src.h
		SDL.SetTextureAlphaMod(state.atlas_texture, color.a)
		SDL.SetTextureColorMod(state.atlas_texture, color.r, color.g, color.b)
		SDL.RenderCopy(renderer, state.atlas_texture, &SDL.Rect{src.x, src.y, src.w, src.h}, dst)
	}

	viewport_rect := &SDL.Rect{}
	SDL.GetRendererOutputSize(renderer, &viewport_rect.w, &viewport_rect.h)
	SDL.RenderSetViewport(renderer, viewport_rect)
	SDL.RenderSetClipRect(renderer, viewport_rect)
	SDL.SetRenderDrawColor(renderer, state.bg.r, state.bg.g, state.bg.b, state.bg.a)
	SDL.RenderClear(renderer)

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text:
			dst := SDL.Rect{cmd.pos.x, cmd.pos.y, 0, 0}
			for ch in cmd.str do if ch&0xc0 != 0x80 {
				r := min(int(ch), 127)
				src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
				render_texture(renderer, &dst, src, cmd.color)
				dst.x += dst.w
			}
		case ^mu.Command_Rect:
			SDL.SetRenderDrawColor(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
			SDL.RenderFillRect(renderer, &SDL.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h})
		case ^mu.Command_Icon:
			src := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - src.w)/2
			y := cmd.rect.y + (cmd.rect.h - src.h)/2
			render_texture(renderer, &SDL.Rect{x, y, 0, 0}, src, cmd.color)
		case ^mu.Command_Clip:
			SDL.RenderSetClipRect(renderer, &SDL.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h})
		case ^mu.Command_Jump:
			unreachable()
		}
	}

	SDL.RenderPresent(renderer)
}


u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
	mu.push_id(ctx, uintptr(val))

	@static tmp: mu.Real
	tmp = mu.Real(val^)
	res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
	val^ = u8(tmp)
	mu.pop_id(ctx)
	return
}

all_windows :: proc(ctx: ^mu.Context, game_ctx: ^game.GameCtx) {
	@static opts := mu.Options{.NO_CLOSE}

	display_ctx := game_ctx^.display_ctx
	card : game.Card
	for i in 0..<i32(display_ctx.num_cards) {
		card = display_ctx.card_state[i]
		cardID := fmt.tprint("Card:", card.id)
		if mu.window(ctx, cardID, {540 + 10 * i, 40 + 10 * i, 300, 400}, opts) {
			mu.layout_row(ctx, {80, 20}, 0)
			for field, value in card.fieldMap {
				mu.label(ctx, fmt.tprint(field))
				mu.label(ctx, fmt.tprintf(": %d", value))
			}
		}
	}

	if game_ctx.cmd_active {
		if mu.window(ctx, "Inputs", {0, 0, 400, 400}) {
			// Don't deal with DISPLAY as it is dealt with automatically
			#partial switch game_ctx.cur_cmd {
				case comms.GameCmd.ORDER: {
					order_ctx := &game_ctx^.order_ctx
					num_orders := order_ctx.num_orders
					trg : game.AbilityIdx
					place : u8
					mu.layout_row(ctx, {-1})
					for i in 0..<order_ctx.num_triggers {
						trg = order_ctx.triggers[i]
						aID := fmt.tprint(trg.cID, ":", trg.aID)
						place = i + 1
						ordering, found := slc.linear_search(order_ctx.out_order[:], place)
						if .CHANGE in mu.checkbox(ctx, aID, &found) {
							if !found {
								// We are unordering it from the list
								slc.rotate_left(order_ctx.out_order[ordering:num_orders], 1)
								num_orders -= 1
							} else {
								// Just place it at the end of the orders
								order_ctx.out_order[num_orders] = place
								num_orders += 1
							}
						}
					}
					mu.label(ctx, fmt.tprint(order_ctx.out_order[:num_orders]))
					order_ctx.num_orders = num_orders
					if order_ctx.num_triggers == num_orders {
						if .SUBMIT in mu.button(ctx, "Ok") {
							mu.layout_row(ctx, {-1})
							state.msg.cmd = comms.GameCmd.ORDER
							state.msg.size = num_orders
							for x, i in order_ctx.out_order[:num_orders] {
								state.msg.info[i] = x
							}
							state.comm_err = comms.send_message(state.socket, state.msg)
							game_ctx.cmd_active = false
						}
					}
				}
				case comms.GameCmd.TARGET:
				case comms.GameCmd.RESULT:
			}
		}
	}
}
