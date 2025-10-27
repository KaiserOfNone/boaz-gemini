package server

import "core:log"
import "core:mem"
import "core:net"
import "core:os"
import "core:os/os2"
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
			rsp := `59 bad request\r\n`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		uri, e := strings.clone_from_bytes(data_in_bytes[:], context.allocator)
		if (uri[n - 2:n] == "\r\n") {
			uri = uri[:n - 2]
		}
		path := get_file_path(uri)
		full_path := strings.concatenate([]string{"site/", path})
		if (strings.contains(full_path, "..")) {
			rsp := `59 very funny m8\r\n`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		file, open_err := os.open(full_path)
		if open_err != nil {
			rsp := `51 not found\r\n`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		defer os.close(file)
		buf := make([]u8, mem.Megabyte * 10)
		defer delete(buf)
		fn, read_err := os.read_full(file, buf[:])
		if read_err != nil {
			rsp := `59 failed to read file\r\n`
			net.send_tcp(socket, transmute([]u8)rsp)
			break
		}
		mimetype := get_mimetype(full_path)
		defer delete(mimetype)
		rsp := strings.concatenate([]string{"20 ", mimetype, "\r\n", transmute(string)buf[:fn]})
		defer delete(rsp)
		net.send_tcp(socket, transmute([]u8)rsp)
		net.close(socket)
		break
	}
}

get_mimetype :: proc(path: string) -> string {
	l := len(path)
	if (path[l - 4:l] == ".gem") {
		return strings.clone("text/gemini")
	}
	command := []string{"file", "-I", path}
	desc := os2.Process_Desc {
		command = command,
	}
	_, stdout, stderr, err := os2.process_exec(desc, context.allocator)
	defer delete(stdout)
	defer delete(stderr)
	if err != nil {
		return "idk"
	}
	res, split_err := strings.split_n(transmute(string)stdout, ": ", 2)
	if split_err != nil {
		return "fuck"
	}
	defer delete(res)
	n := 0
	for c in res[1] {
		if c == ';' {
			break
		}
		n += 1
	}
	mimetype := strings.clone_from(res[1][:n])
	log.info(mimetype)
	return mimetype
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
