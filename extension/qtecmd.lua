-- buyhome <huangqi rhomobi com> 20130321 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- QTE costum command of hangxin interface

-- load library
local JSON = require("cjson");
local redis = require "resty.redis"
local http = require "resty.http"
local memcached = require "resty.memcached"
-- originality
local sbeId = "dataservice01";
local Pwd = "dataservice01";
local authclientinfo = sbeId .. "#" .. ngx.md5(Pwd) .. "#" .. "23456915";
local clientinfo = ngx.encode_base64(authclientinfo);
local error001 = JSON.encode({ ["errorcode"] = 001, ["description"] = "Get token from hangxin is no response"});
local error002 = JSON.encode({ ["errorcode"] = 002, ["description"] = "Get PID from hangxin is no response"});
local error003 = JSON.encode({ ["errorcode"] = 003, ["description"] = "Get QTEdata from hangxin is no response"});
local error004 = JSON.encode({ ["errorcode"] = 004, ["description"] = "Free PID from hangxin is no response"});
-- ready to connect to master redis.
local red, err = redis:new()
if not red then
	ngx.say("failed to instantiate redis: ", err)
	return
end
-- ready to connect to memcached
local memc, err = memcached:new()
if not memc then
	ngx.say("failed to instantiate memc: ", err)
	return
end
memc:set_timeout(1000) -- 1 sec
-- Sets the timeout (in ms) protection for subsequent operations, including the connect method.
red:set_timeout(600)

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
	ngx.say("failed to connect: ", err)
	return
end

local ok, err = memc:connect("127.0.0.1", 11211)
if not ok then
	ngx.say("failed to connect: ", err)
	return
end

function gettoken (id)
	local basetime = ngx.localtime();
	local resultCode = 0;
	local tres, tflags, terr = memc:get(id)
	if tres then
		return resultCode, tres
	else
		-- GET Token
		local APPTOKEN = JSON.encode({ ["authenticator"] = clientinfo, ["timestamp"] = basetime, ["token"] = null, ["serviceName"] = "APPLY_TOKEN", ["class"] = "com.travelsky.sbeclient.authorization.AuthorizationRequest"});
		local hc = http:new()
		local ok, code, headers, status, body = hc:request {
			url = "http://113.108.131.149:8060/sbe",
			--- proxy = "http://127.0.0.1:8888",
			--- timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
			body = APPTOKEN,
		}
		local resbody = JSON.decode(body);
		local ok, err = memc:set(id, resbody.token)
		return resbody.resultCode, resbody.token
	end
end

function getpid (tok)
	local basetime = ngx.localtime();
	local resultCode = 0;
	local tres, tflags, terr = memc:get(tok)
	if tres then
		return resultCode, tres
	else
		-- GET PID
		local getpiddata = JSON.encode({ ["ibeFlag"] = null, ["officeNo"] = "CAN911", ["serviceName"] = "SBE_PID_APPLY", ["timestamp"] = basetime, ["token"] = tok});
		local skybusAuth = ngx.md5(tok .. "_" .. getpiddata);
		local hc = http:new()
		local ok, code, headers, status, body = hc:request {
			url = "http://113.108.131.149:8060/sbe",
			--- proxy = "http://127.0.0.1:8888",
			--- timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
			body = getpiddata,
		}
		if body then
			local resbody = JSON.decode(body);
			local ok, err = memc:set(tok, resbody.resultMsg)
			return resbody.resultCode, resbody.resultMsg
		end
	end
end

function command (rms)
	local basetime = ngx.localtime();
	-- send command
	local getpiddata = JSON.encode({ ["ibeFlag"] = null, ["officeNo"] = "CAN911", ["serviceName"] = "SBE_PID_APPLY", ["timestamp"] = basetime, ["token"] = tok});
	local skybusAuth = ngx.md5(tok .. "_" .. getpiddata);
	local hc = http:new()
	local ok, code, headers, status, body = hc:request {
		url = "http://113.108.131.149:8060/sbe",
		--- proxy = "http://127.0.0.1:8888",
		--- timeout = 3000,
		method = "POST", -- POST or GET
		-- add post content-type and cookie
		headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
		body = getpiddata,
	}
	if body then
		local resbody = JSON.decode(body);
		local ok, err = memc:set(tok, resbody.resultMsg)
		return resbody.resultCode, resbody.resultMsg
	end
end

if ngx.var.request_method == "POST" then
	ngx.exit(ngx.HTTP_FORBIDDEN);
end

if ngx.var.request_method == "GET" then
	local resultCode1, token = gettoken(sbeId)
	local resultCode2, resultMsg = getpid(token)
	ngx.say(resultCode1)
	ngx.say(resultCode2)
	ngx.print(resultMsg);
	
	-- put it into the connection pool of size 512,
	-- with 0 idle timeout
	local ok, err = red:set_keepalive(0, 512)
	if not ok then
		ngx.say("failed to set keepalive: ", err)
		return
	end
	-- or just close the connection right away:
	-- local ok, err = red:close()
	-- if not ok then
		-- ngx.say("failed to close: ", err)
		-- return
	-- end
end
