local proxy = {}
proxy.cjson = require "cjson"
proxy.ssdb = require "resty.ssdb"
proxy.db = proxy.ssdb:new()


function proxy.db_connect()
	local ok, err = db:connect("127.0.0.1", "8888")
	if not ok then
		ngx.say("500")
		ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		return
	end
end

local cjson = require "cjson"
local ssdb = require 'resty.ssdb'
local db = ssdb:new()

function get_backend ()
	local action = ngx.var.request_method
	if action == "POST" then
		method = ngx.HTTP_POST
	elseif action == "GET" then 
		method = ngx.HTTP_GET
	elseif action == "HEAD" then
		method = ngx.HTTP_HEAD
	else
		ngx.exit(ngx.HTTP_NOT_ALLOWED)
	end
	
	res = ngx.location.capture (
		'/proxy', {method = method, always_forward_body = true, copy_all_vars = true}
	)

	return res
end

function response(res, x_cache)
	for k,v in pairs(res.header) do
		ngx.header[k] = v
	end
	ngx.header["X-Cache"] = x_cache
	ngx.print(res.body)
	ngx.exit(res.status)
end

local args = ""
if ngx.var.args ~= nil then
	args = ngx.var.args
end

local cache_raw = ngx.var.host..ngx.var.request_uri..args
local cache_key = ngx.md5(cache_raw)
local cache_content, err = db:get(cache_key)

if cache_content then
	local res = ""
	if type(cache_content) == "table" then
		res = cache_content[1]
	elseif type(cache_content) == "string" then
		res = cache_content
	end

	response(cjson.decode(res), "HIT")
else
	res = get_backend()
	if res.status == ngx.HTTP_OK then
		db:set(cache_key, cjson.encode(res))
		response(res, "MISS")
	end
end


