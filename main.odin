package main

import fmt "core:fmt"

import comms "comms"
import term "terminal"


ui_main :: proc(socket : ^comms.SendSocket, mailbox : ^comms.MailBox) {
        fmt.println("not debug mode")
}

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

        // Main Interactive Loop
    when #config(DEBUG, false) {
        term.debug_main(send_socket)
    } else {
        ui_main(send_socket, mailbox)
    }
    return
}
