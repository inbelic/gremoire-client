package main

import fmt "core:fmt"

import comms "comms"
import term "terminal"
import ui "ui"

DEBUG :: #config(DEBUG, false)

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
    when DEBUG {
        term.debug_main(send_socket)
    } else {
        ui.ui_main(send_socket, mailbox)
    }
    return
}
