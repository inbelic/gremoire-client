package terminal

import os "core:os"
import fmt "core:fmt"

import comms "../comms"

debug_main :: proc(socket : ^comms.SendSocket) {
    // Sending declarations
    comm_err    : comms.Comm_Error
    hdl_err     : os.Errno
    input       : [255]u8
    bytes_read  : int
    msg         : comms.Message

    // Login
    fmt.print("username: ")
    bytes_read, hdl_err = os.read(os.stdin, input[:])

    msg.cmd = comms.LobbyCmd.LOGIN
    msg.size = u8(bytes_read - 1)
    for i in 0..<msg.size {
        msg.info[i] = input[i]
    }
    comm_err = comms.send_message(socket, msg)
    if comm_err != nil {
        fmt.println("err send:", comm_err)
        return
    }

    for {
        bytes_read, hdl_err = os.read(os.stdin, input[:])
        if bytes_read <= 1 { // 1 accounts for newlien
            break
        }

        msg.cmd = comms.u8_to_cmd(input[0] - 48)
        msg.size = u8(bytes_read - 2)

        for i in 0..<msg.size {
            msg.info[i] = u8(input[i + 1] - 48)
        }

        comm_err = comms.send_message(socket, msg)
        if comm_err != nil {
            fmt.println("err send:", comm_err)
            return
        }
    }
}
