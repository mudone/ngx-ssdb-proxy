local http = require "resty.http"
local http_client = http:new()
local url = "http://"

if ngx.var.http_host then
	url = url .. ngx.var.http_host
end

url = url .. ngx.var.request_uri

if ngx.var.is_args then
	url = url .. ngx.var.is_args .. ngx.var.args
end

local ok, code, headers, status, body = http_client:request {
	url = "http://backend",
	timeout = 30000,
	headers = ngx.req.get_headers(),
	method = ngx.var.request_method,
}

ngx.print(headers)
ngx.print(body)
