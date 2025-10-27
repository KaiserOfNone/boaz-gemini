package server

import "core:flags"
import "core:log"
import "core:mem"
import "core:net"
import "core:os"
import "core:os/os2"
import "core:strings"

import "../protocol"

Options :: struct {
	port:      int `usage:"Port to listen on. (default ./site)"`,
	serve_dir: string `usage:"The directory to serve. (default 1964)"`,
}

opts := Options{}

init_opts :: proc() {
	style: flags.Parsing_Style = .Unix
	flags.parse_or_exit(&opts, os.args, style)
	if opts.serve_dir == "" {
		opts.serve_dir = "./site/"
	}
	if opts.serve_dir[len(opts.serve_dir) - 1] != '/' {
		opts.serve_dir = strings.concatenate([]string{opts.serve_dir, "/"})
	}
	if opts.port == 0 {
		opts.port = 1964
	}
}

main :: proc() {
	init_opts()
	context.logger = log.create_console_logger()
	log.infof("Starting server port %d", opts.port)
	log.infof("Serving contents of %s", opts.serve_dir)
	socket, err := net.listen_tcp(net.Endpoint{port = opts.port, address = net.IP4_Any})
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
			write_error(socket, .bad_request, "bad request")
			break
		}
		uri, e := strings.clone_from_bytes(data_in_bytes[:], context.allocator)
		if (uri[n - 2:n] == "\r\n") {
			uri = uri[:n - 2]
		}
		log.infof("Request for %s", uri)
		path := get_file_path(uri)
		full_path := strings.concatenate([]string{opts.serve_dir, path})
		is_dir := os.is_dir_path(full_path)
		if (strings.contains(path, "..")) {
			write_error(socket, .bad_request, "very funny m8")
			break
		}
		if !is_dir {
			serve_file(socket, full_path)
			break
		}
		if is_dir {
			serve_directory(socket, path, full_path)
			break
		}
		write_error(socket, .not_fount, "not found")
		net.close(socket)
		break
	}
}

serve_directory :: proc(socket: net.TCP_Socket, gemini_path: string, full_path: string) {
	dir, open_err := os.open(full_path)
	if open_err != nil {
		write_error(socket, .not_fount, "not found")
		return
	}
	defer os.close(dir)
	contents, read_err := os.read_dir(dir, -1)
	if open_err != nil {
		write_error(socket, .internal_error, "failed to read dir")
		return
	}
	rsp := strings.concatenate([]string{"20 ", "text/gemini", "\r\n", "# ", gemini_path, "\n"})
	net.send_tcp(socket, transmute([]u8)rsp)
	delete(rsp)
	for elem in contents {
		rsp = strings.concatenate([]string{"=> ", gemini_path, "/", elem.name, "\n"})
		net.send_tcp(socket, transmute([]u8)rsp)
		delete(rsp)
	}
}

serve_file :: proc(socket: net.TCP_Socket, full_path: string) {
	file, open_err := os.open(full_path)
	if open_err != nil {
		write_error(socket, .not_fount, "not found")
		return
	}
	defer os.close(file)
	buf := make([]u8, mem.Megabyte * 10)
	defer delete(buf)
	fn, read_err := os.read_full(file, buf[:])
	if read_err != nil {
		write_error(socket, .internal_error, "failed to read file")
		return
	}
	mimetype := get_mimetype(full_path)
	defer delete(mimetype)
	rsp := strings.concatenate([]string{"20 ", mimetype, "\r\n", transmute(string)buf[:fn]})
	defer delete(rsp)
	net.send_tcp(socket, transmute([]u8)rsp)
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

write_error :: proc(socket: net.TCP_Socket, code: protocol.Status, excuse: string) {
	codes := protocol.status_strs
	net.send_tcp(socket, transmute([]u8)codes[code])
	net.send_tcp(socket, []u8{' '})
	net.send_tcp(socket, transmute([]u8)excuse)
	net.send_tcp(socket, []u8{'\r', '\n'})
}
