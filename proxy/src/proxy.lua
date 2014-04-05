local proxy = {}
proxy.cjson = require "cjson"
proxy.ssdb = require "resty.ssdb"
proxy.db = proxy.ssdb:new()

function proxy.db_connect()
	local ok, err = proxy.db:connect("127.0.0.1", "8888")
	if not ok then
		ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR 
		ngx.say("500")
		return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
	end
end

function proxy.fetch ()
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

function proxy.response(res, x_cache)
	for k,v in pairs(res.header) do
		ngx.header[k] = v
	end
	ngx.header["X-Cache"] = x_cache

	if res.status == ngx.HTTP_OK then
		ngx.print(res.body)
	end
	
	return ngx.exit(res.status)
end

function proxy.cache_key()
        local cache_raw = ngx.var.cache_key
        if cache_raw == nil then
                local args = ""
                if ngx.var.args ~= nil then
                        args = ngx.var.args
                end
                cache_raw = ngx.var.host..ngx.var.uri..ngx.var.is_args..args
        end

        local cache_key = ngx.md5(cache_raw)

        return cache_key
end

function proxy.purge()
	return proxy.db:del(proxy.cache_key())
end

function proxy.get()
	local cache_key = proxy.cache_key()
	local cache_content, err = proxy.db:get(cache_key)

	local cache_string = ""
	if type(cache_content) == "table" then
		cache_string = cache_content[1]
	elseif type(cache_content) == "string" then
		cache_string = cache_content
	end

	if cache_string and cache_string ~= "not_found" then
		local res = cache_string
		return proxy.cjson.decode(res), "HIT"
	else
		local res = proxy.fetch()
		if res.status == ngx.HTTP_OK and ngx.var.request_method ~= "HEAD" then
			proxy.db:set(cache_key, proxy.cjson.encode(res))
		end
		return res, "MISS"
	end
end

function proxy.run()
	proxy.db_connect()

	if ngx.var.request_method == "PURGE" then
		proxy.purge()
	else
		local res, x_cache = proxy.get()
		return proxy.response(res, x_cache)
	end
end

proxy.run()
