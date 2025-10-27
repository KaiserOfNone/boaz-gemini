package server

import "core:log"
import "core:mem"
import "core:net"
import "core:os"
import "core:strings"

main :: proc() {
	context.logger = log.create_console_logger()
	log.infof("Starting server")

	socket, err := net.listen_tcp(net.Endpoint{port = 1964, address = net.IP4_Any})
	if err != nil {
		log.errorf("Failed to start socket: %s", err)
		os.exit(-1)
	}
	defer net.close(socket)

	for {
		client_socket, client_endpoint, accept_err := net.accept_tcp(socket)
		if accept_err != nil {
			log.errorf("Failed to accept connection: %s", accept_err)
			os.exit(-1)
		}
		handleClient(client_socket)
	}
}

handleClient :: proc(socket: net.TCP_Socket) {
	defer net.close(socket)
	for {
		data_in_bytes: [1028]byte
		n, err := net.recv_tcp(socket, data_in_bytes[:])
		if err == net.TCP_Recv_Error.Connection_Closed {
			break
		}
		if err != nil && err != net.TCP_Recv_Error.Connection_Closed {
			log.errorf("error while recieving data %s", err)
			break
		}
		// check for \r \n
		if (data_in_bytes[n - 1] != '\n') {
			rsp := `59 bad request`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		uri, e := strings.clone_from_bytes(data_in_bytes[:], context.allocator)
		if (uri[n - 2:n] == "\r\n") {
			uri = uri[:n - 2]
		}
		path := get_file_path(uri)
		full_path := strings.concatenate([]string{"site/", path})
		file, open_err := os.open(full_path)
		if open_err != nil {
			rsp := `59 not found`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		defer os.close(file)
		buf := make([]u8, mem.Megabyte * 10)
		fn, read_err := os.read_full(file, buf[:])
		if read_err != nil {
			rsp := `59 failed to read file`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		rsp := strings.concatenate([]string{"20 text/gemini\r\n", transmute(string)buf[:fn]})
		net.send_tcp(socket, transmute([]u8)rsp)
		net.close(socket)
		break
	}
}

get_file_path :: proc(_uri: string) -> string {
	uri := _uri
	if (uri[:9] == "gemini://") {
		uri = uri[9:]
	}
	res, err := strings.split_n(uri, "/", 2)
	if err != nil || len(res) == 1 || res[1] == "" {
		return "index.gem"
	}
	return res[1]
}
