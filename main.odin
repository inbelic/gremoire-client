package main

import fmt "core:fmt"
import comms "comms"
import os "core:os"

main :: proc() {
    // Initialzie communications
    socket := new(comms.Socket)
    defer free(socket)
    comm_err := comms.dial_tcp(socket, "127.0.0.1:3565")
    recv_socket, send_socket := comms.split_socket(socket)

    if comm_err != nil {
        fmt.println("no conn:", comm_err)
        return
    }

    mail_lock := comms.MailLock{}
    mailbox := new(comms.MailBox)
    mailbox^.lock = &mail_lock
    defer free(mailbox)

    data := new(comms.MailData)
    data^.mailbox = mailbox
    data^.socket = recv_socket
    defer free(data)

    mail_man := comms.employ_mailman(data)
    defer comms.unemploy_mailman(mail_man)

    // Sending declrations
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
    comm_err = comms.send_message(send_socket, msg)
    if comm_err != nil {
        fmt.println("err send:", comm_err)
        return
    }

    // Main Interactive Loop
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

        comm_err = comms.send_message(send_socket, msg)
        if comm_err != nil {
            fmt.println("err send:", comm_err)
            return
        }
    }

    return
}
