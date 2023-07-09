package test_src_comms

import "core:testing"
import "core:fmt"
import "core:os"
import comms "../../../src/comms"

TEST_count := 0
TEST_fail  := 0

when ODIN_TEST {
	expect  :: testing.expect
	log     :: testing.log
} else {
	expect  :: proc(t: ^testing.T, condition: bool, message: string, loc := #caller_location) {
		TEST_count += 1
		if !condition {
			TEST_fail += 1
			fmt.printf("[%v] %v\n", loc, message)
			return
		}
	}
	log     :: proc(t: ^testing.T, v: any, loc := #caller_location) {
		fmt.printf("[%v] ", loc)
		fmt.printf("log: %v\n", v)
	}
}

main :: proc() {
    t := testing.T{}
	test_socket_split(&t)

	fmt.printf("%v/%v tests successful.\n", TEST_count - TEST_fail, TEST_count)
	if TEST_fail > 0 {
		os.exit(1)
	}
}

@test
test_socket_split :: proc(t: ^testing.T) {
	socket := new(comms.Socket)
	defer free(socket)
	recv_socket, send_socket := comms.split_socket(socket)
	raw_one := cast(rawptr)recv_socket
	raw_two := cast(rawptr)send_socket
    expect(t, raw_one == raw_two, "split sockets refer to the original")
}
