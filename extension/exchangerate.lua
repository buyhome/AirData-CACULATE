-- buyhome <huangqi rhomobi com> 20130321 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- exchangerate costum command of hangxin interface

-- load library
local JSON = require("cjson");
local redis = require "resty.redis"
local http = require "resty.http"
local memcached = require "resty.memcached"
-- originality
local sbeId = "";
local Pwd = "";
local authclientinfo = sbeId .. "#" .. ngx.md5(Pwd) .. "#" .. "23456915";
local clientinfo = ngx.encode_base64(authclientinfo);
local error001 = JSON.encode({ ["errorcode"] = 001, ["description"] = "Get token from hangxin is no response"});
local error002 = JSON.encode({ ["errorcode"] = 002, ["description"] = "Get PID from hangxin is no response"});
local error003 = JSON.encode({ ["errorcode"] = 003, ["description"] = "Get exchangerate from hangxin is no response"});
-- local error004 = JSON.encode({ ["errorcode"] = 004, ["description"] = "Free PID from hangxin is no response"});
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
	local error005 = JSON.encode({ ["errorcode"] = 005, ["description"] = "failed to connect huangqiCache/v0.5.1: " .. err});
	ngx.say(error005)
	return
end

function gettoken (id)
	local basetime = ngx.localtime();
	local resultCode = 0;
	local errorcodeNo = 404;
	local tres, tflags, terr = memc:get(id)
	if tres then
		return resultCode, tres
	else
		-- GET Token
		local APPTOKEN = JSON.encode({ ["authenticator"] = clientinfo, ["timestamp"] = basetime, ["token"] = null, ["serviceName"] = "APPLY_TOKEN", ["class"] = "com.travelsky.sbeclient.authorization.AuthorizationRequest"});
		local hc = http:new()
		local ok, code, headers, status, body = hc:request {
			url = "",
			--- proxy = "http://127.0.0.1:8888",
			--- timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
			body = APPTOKEN,
		}
		if code == 200 then
			local resbody = JSON.decode(body);
			local ok, err = memc:set(id, resbody.token, 18000)
			return resbody.resultCode, resbody.token
			-- return resbody.resultCode, body
		else
			return errorcodeNo, status
		end
	end
end

function getpid (tok)
	local basetime = ngx.localtime();
	local resultCode = 0;
	local resultbody = "Get pid from huangqiCache/v0.5.1 is ok!";
	local errorcodeNo404 = 404;
	local errorcodeNo403 = 403;
	local tres, tflags, terr = memc:get(tok)
	if tres then
		return resultCode, tres, resultbody
	else
		-- GET PID
		local getpiddata = JSON.encode({ ["ibeFlag"] = null, ["officeNo"] = "CAN911", ["serviceName"] = "SBE_PID_APPLY", ["timestamp"] = basetime, ["token"] = tok});
		local skybusAuth = ngx.md5(tok .. "_" .. getpiddata);
		local hc = http:new()
		local ok, code, headers, status, body = hc:request {
			url = "",
			--- proxy = "http://127.0.0.1:8888",
			--- timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
			body = getpiddata,
		}
		if code == 200 then
			local resbody = JSON.decode(body);
			if resbody.resultCode == 0 then
				-- expiretime must > 120
				local ok, err = memc:set(tok, resbody.resultMsg, 150)
				return resbody.resultCode, resbody.resultMsg, status
			else
				return errorcodeNo403, resbody.resultCode, body
			end
		else
			return errorcodeNo404, code, status
		end
	end
end

function exchangerate (pid, tok, command)
	local basetime = ngx.localtime();
	local errorcodeNo404 = 404;
	local errorcodeNo403 = 403;
	-- send command
	local commandata = JSON.encode({ ["commands"] = command, ["ibeFlag"] = "false", ["officeNo"] = "CAN911", ["pid"] = pid, ["serviceName"] = "SBE_PID_SEND_CMD", ["timestamp"] = basetime, ["token"] = tok});
	local skybusAuth = ngx.md5(tok .. "_" .. commandata);
	local hc = http:new()
	local ok, code, headers, status, body = hc:request {
		url = "",
		--- proxy = "http://127.0.0.1:8888",
		--- timeout = 3000,
		method = "POST", -- POST or GET
		-- add post content-type and cookie
		headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
		body = commandata,
	}
	if code == 200 then
		-- if 200 decode or it will be wrong.
		local resbody = JSON.decode(body);
		if resbody.resultCode == 0 then
			-- local ok, err = memc:set(tok, resbody.resultMsg, 18000)
			return resbody.resultCode, resbody.resultMsg
		else
			return errorcodeNo403, body
		end
	else
		return errorcodeNo404, status
	end
end

if ngx.var.request_method == "POST" then
	ngx.exit(ngx.HTTP_FORBIDDEN);
end

if ngx.var.request_method == "GET" then
	local commandexrate = {"xs fsc 100cny/" .. ngx.var.currency};
	local resultCode1, token = gettoken(sbeId)
	if resultCode1 == 404 then
		-- Apply token get no response.
		ngx.print(error001);
	else
		-- ngx.say(token)
		local resultCode2, resultMsg2, resbody2 = getpid(token)
		if resultCode2 == 0 then
			-- ngx.say(resultCode2)
			-- ngx.say(resultMsg2)
			-- ngx.say(resbody2)
			-- Call exchangerate function
			local resultCode3, resultMsg3 = exchangerate(resultMsg2, token, commandexrate)
			if resultCode3 == 0 then
				ngx.print(resultMsg3);
			else
				if resultCode3 == 403 then
					-- ngx.print(resultMsg3);
					local resexrate = JSON.decode(resultMsg3);
					if resexrate.resultCode == 10033 then
						local res = ngx.location.capture("/data-exrate/" .. ngx.var.currency .. "/");
						if res.status == 200 then
							ngx.print(res.body);
						end
					else
						if resexrate.resultCode == 20000 then
							local ok, err = memc:delete(token)
							if not ok then
								ngx.say("failed to delete PID: ", err)
								return
							else
								local res = ngx.location.capture("/data-exrate/" .. ngx.var.currency .. "/");
								if res.status == 200 then
									ngx.print(res.body);
								end
							end
						else
							ngx.print(resultMsg3);
						end
					end
				end
				if resultCode3 == 404 then
					ngx.print(error003);
				end
			end
		else
			if resultCode2 == 403 then
				ngx.print(resbody2);
			end
			if resultCode2 == 404 then
				ngx.print(error002);
			end
		end
	end
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
