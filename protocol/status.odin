package protocol

Status :: enum {
	input              = 10,
	sensitive_input    = 11,
	success            = 20,
	temp_redirect      = 30,
	prem_redirect      = 31,
	temp_error         = 40,
	server_unavailable = 41,
	CGI_error          = 42,
	proxy_error        = 43,
	slow_down          = 44,
	internal_error     = 50,
	not_fount          = 51,
	gone               = 52,
	proxy_req_refused  = 53,
	bad_request        = 59,
}

status_strs :: #sparse[Status]string {
	.input              = "input",
	.sensitive_input    = "sensitive_input",
	.success            = "success",
	.temp_redirect      = "temp_redirect",
	.prem_redirect      = "prem_redirect",
	.temp_error         = "temp_error",
	.server_unavailable = "server_unavailable",
	.CGI_error          = "CGI_error",
	.proxy_error        = "proxy_error",
	.slow_down          = "slow_down",
	.internal_error     = "internal_error",
	.not_fount          = "not_fount",
	.gone               = "gone",
	.proxy_req_refused  = "proxy_req_refused",
	.bad_request        = "bad_request",
}
