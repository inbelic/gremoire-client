package comms

// Package to communicate with the erlang client_srvr and haskell game server
// requests. Incoming and messages follow the format as described in format.doc

import fmt "core:fmt" // FIXME: temp and all uses
import net "core:net"
import thread "core:thread"
import sync "core:sync"

// Socket that we will only use to listen and recv from
RecvSocket :: distinct net.TCP_Socket

// Socket that we will only use to send to
SendSocket :: distinct net.TCP_Socket 

// Wrappers
Socket :: net.TCP_Socket
MailLock :: sync.Atomic_Mutex
MailMan :: thread.Thread

Cmd :: union {
    GeneralCmd,
    LobbyCmd,
    GameCmd,
} // Corresponding to the cmds in server/include/cmds.hrl serverside

GeneralCmd :: enum u8 {
    OK = 0,
    INVALID,
    ECHO,
}

LobbyCmd :: enum u8 {
    LOGIN = 3,
    QUEUE,
    STARTED,
}

GameCmd :: enum u8 {
    DISPLAY = 6,
    ORDER,
    TARGET,
    RESULT,
}

Msg_Error :: enum u8 {
    None = 0,
    Graceful_Exit,
    Invalid_Size,
    Incorrect_Send,
    Incorrect_Recv,
}

Comm_Error :: union #shared_nil {
    net.Network_Error,
    Msg_Error,
}


// Structs
Message :: struct {
    cmd : Cmd,
    size : u8,
    info : [254]byte,
} // Simple wrapping struct around our messages being received or sent

MailBox :: struct {
    msg : Message,
    notif : bool,
    lock : ^MailLock,
}

MailData :: struct {
    mailbox : ^MailBox,
    socket : ^RecvSocket,
}

// Procedures

// Hacks to allow conversion between the greater enum and u8
cmd_to_u8 :: proc(cmd : Cmd) -> u8 {
    return (transmute([2]u8)cmd)[0]
}

u8_to_cmd :: proc(x : u8) -> (cmd : Cmd) {
    cmdbuf : [2]u8
    cmdbuf[0] = x
    switch {
        case x < 3:     cmdbuf[1] = 1
        case x < 6:     cmdbuf[1] = 2
        case x < 10:    cmdbuf[1] = 3
        case:
    }
    cmd = transmute(Cmd)cmdbuf
    return
}

// Simple wrapping function to not expose underlying packages
dial_tcp :: proc(socket : ^Socket, addr : string) -> (err : Comm_Error) {
    socket^, err = net.dial_tcp(addr)
    return
}

// When we want to exclusively read and write from a socket (most likely in
// two different threads) then we can 'split' the socket into their seperate
// entities. The general usage pattern would then be:
//      socket = new(comms.Socket)
//      defer free(socket)
//      err = comms.dial_tcp(socket, hostname_and_port)
//      if err != nil { ... }
//      recv_socket, send_socket := split_socket(socket)
// 
// and then there is no need to worry about freeing either of the split sockets
// or to use socket again in the program.
split_socket :: proc(socket : ^Socket) -> (recv_socket : ^RecvSocket, send_socket : ^SendSocket) {
    recv_socket = cast(^RecvSocket)socket
    send_socket = cast(^SendSocket)socket
    return
}


// Receive a message in the format of
// size:command:info, where size = 1 byte, command = 1 byte and
// info will contain less then or equal to 254 bytes as denoted by size
@(private)
recv_message :: proc(socket : ^RecvSocket) -> (msg : Message, err : Comm_Error) {
    recv_socket := cast(^net.TCP_Socket)socket
    buf : [256]u8
    bytes_read : int
    bytes_read, err = net.recv(recv_socket^, buf[:])
    if err != nil {
        return
    }

    msg.size = buf[0] // safe because it will be 0 if none read

    if msg.size == 0 {
        err = Msg_Error.Invalid_Size
        return
    }

    if bytes_read == 0 {
        err = Msg_Error.Invalid_Size
        return
    }

    if bytes_read != int(msg.size) + 1 {
        err = Msg_Error.Incorrect_Recv
        return
    }

    // Remove Cmd byte from size
    msg.size = msg.size - 1 
    msg.cmd = u8_to_cmd(buf[1])

    if msg.cmd == GeneralCmd.ECHO && msg.size == 0 {
        err = Msg_Error.Graceful_Exit
        return
    }

    for i in 0 ..< msg.size {
        msg.info[i] = buf[i + 2]
    }
    
    return
}


@(private)
mailman :: proc(ptr : rawptr) {
    data := cast(^MailData)ptr
    mailbox := data^.mailbox
    lock := mailbox^.lock
    socket := data^.socket

    msg : Message
    err : Comm_Error

    // Recv loop
    for ;; {
        msg, err = recv_message(socket)
        if err != nil {
            return
        }

        sync.atomic_mutex_lock(lock)
        defer sync.atomic_mutex_unlock(lock)

        // We will do a simple override of any old message if the other side
        // hasn't retreived it should be fine in our context
        mailbox^.msg = msg
        mailbox^.notif = true
        fmt.println(mailbox^.msg.info)
        req, ok := to_request(&mailbox^.msg)
        if ok {
            fmt.println(req)
        } else {
            fmt.println(req)
            fmt.println("bad request")
        }
    }

    return
}

employ_mailman :: proc(data : ^MailData) -> (th : ^MailMan) {
    // Start our mailbox thread which will exclusively get message from the
    // server
    th = thread.create_and_start_with_data(rawptr(data), mailman)
    thread.start(th)
    return
}

unemploy_mailman :: proc(th : ^MailMan) {
    thread.join(th)
    thread.destroy(th)
}

check_mailbox :: proc(mailbox : ^MailBox, lock : ^MailLock) -> (msg : Maybe(Message)) {
    if sync.atomic_mutex_try_lock(lock) { // No need to block, just check on the next frame
        defer sync.atomic_mutex_unlock(lock)

        if mailbox^.notif {
            mailbox^.notif = false
            msg = mailbox^.msg
        }
    }
    return
}

// Send a message in the format of
// size:command:info, where size = 1 byte, command = 1 byte and
// info will contain less then or equal to 254 bytes as denoted by (size - 1)
send_message :: proc(socket : ^SendSocket, msg : Message) -> (err : Comm_Error) {
    send_socket := cast(^net.TCP_Socket)socket
    if msg.size > 254 {
        err = Msg_Error.Invalid_Size
        return
    }

    buf : [258]u8
    buf[0] = msg.size + 1
    buf[1] = cmd_to_u8(msg.cmd)

    for i in 0 ..< msg.size {
        buf[i + 2] = msg.info[i]
    }

    bytes_written : int
    bytes_written, err = net.send(send_socket^, buf[0:msg.size + 2])
    if err != nil {
        return
    }
    if bytes_written != int(msg.size) + 2 {
        err = Msg_Error.Incorrect_Send
        return
    }
    return
}
