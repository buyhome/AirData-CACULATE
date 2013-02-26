-- buyhome <huangqi rhomobi com> 20130321 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- avh of hangxin interface

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
local error002 = JSON.encode({ ["errorcode"] = 002, ["description"] = "Get avhdata from hangxin is no response"});
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

if ngx.var.request_method == "POST" then
        ngx.exit(ngx.HTTP_FORBIDDEN);
end

if ngx.var.request_method == "GET" then
--[[
	ngx.req.read_body();
	local pcontent = ngx.req.get_body_data();
	if pcontent then

		-- Maybe 1000000 process POST faredata
		-- local tmprandom = math.random(1,1000000);
		local content = JSON.decode(pcontent);
		ngx.print(content.org);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.dst);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.itemsCount);
		ngx.print("\r\n---------------------\r\n");

		-- avItems information.
		local itemcount = 1;
		for idx, value in ipairs(content.avItems) do
			for key, value1 in ipairs(value.segments) do
				for skey, value2 in pairs(value1) do
					if (skey ~= "cangwei_index" and skey ~= "cangwei_data" and skey ~= "cangwei_subclass_index" and skey ~= "cangwei_subclass_data") then
						ngx.print(skey, ":", value2);
						ngx.print("\r\n---------------------\r\n");
					end
				end
			end
			itemcount = itemcount + 1;
			-- ngx.print(itemcount);
			-- ngx.print("\r\n+++++++++\r\n");
		end

	end
--]]
	-- print the avhcmd arg[].
--[[
	ngx.print(ngx.var.org);
	ngx.print("\r\n---------------------\r\n");
	ngx.print(ngx.var.dst);
	ngx.print("\r\n---------------------\r\n");
	ngx.print(ngx.var.airline);
	ngx.print("\r\n---------------------\r\n");
	ngx.print(ngx.var.date);
	ngx.print("\r\n---------------------\r\n");
--]]
	-- JSON.encode_sparse_array(true);
	-- ngx.localtime() == os.date("%Y-%m-%d %X", ngx.now());
	local basetime = ngx.localtime();
	local tres, tflags, terr = memc:get(sbeId)
	if terr then
		ngx.say("failed to get token: ", terr)
		return
	end
	if not tres then
		-- GET Token
		local APPTOKEN = JSON.encode({ ["authenticator"] = clientinfo, ["timestamp"] = basetime, ["token"] = null, ["serviceName"] = "APPLY_TOKEN", ["class"] = "com.travelsky.sbeclient.authorization.AuthorizationRequest"});
		local hc1 = http:new()
		local ok1, code1, headers, status, body1  = hc1:request {
			url = "",
			--- proxy = "http://127.0.0.1:8888",
			--- timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			-- headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
			body = APPTOKEN,
		}
		-- ngx.say(ok1)
		-- ngx.say(code1)
		-- ngx.say(body1)
		if body1 then
			local resbody1 = JSON.decode(body1);
			local tmptoken1 = resbody1.token;
			local ok, err = memc:set(sbeId, tmptoken1)
            if not ok then
                ngx.say("failed to set token: ", err)
                return
            end
			local avhdata1 = JSON.encode({ ["org"] = ngx.var.org,  ["dst"] = ngx.var.dst, ["airline"] = ngx.var.airline, ["date"] = tonumber(ngx.var.date), ["direct"] = null, ["fltNo"] = null, ["ibeFlag"] = "false", ["nonstop"] = "false", ["officeNo"] = "CAN911", ["page"] = 0, ["serviceName"] = "SBE_AV", ["stopCity"] = "", ["timestamp"] = basetime, ["token"] = tmptoken1});
			local skybusAuth1 = ngx.md5(tmptoken1 .. "_" .. avhdata1);
			-- ngx.say(avhdata1)
			-- ngx.say(skybusAuth1)
			local hc2 = http:new()
			local ok2, code2, headers, status, body2  = hc2:request {
				url = "",
				--- proxy = "http://127.0.0.1:8888",
				--- timeout = 3000,
				method = "POST", -- POST or GET
				-- add post content-type and cookie
				headers = { skybusAuth = skybusAuth1, ["Content-Type"] = "application/json" },
				body = avhdata1,
			}
			-- ngx.say(ok2)
			-- ngx.say(code2)
			if body2 then
				local resbody2 = JSON.decode(body2);
				local resultcode2 = tonumber(resbody2.resultCode);
				if resultcode2 == 0 then
					ngx.print(body2);
				else
					local res = ngx.location.capture("/data-avh/" .. ngx.var.org .. "/" .. ngx.var.dst .. "/" .. ngx.var.airline .. "/" .. ngx.var.date .. "/");
					if res.status == 200 then
						ngx.print(res.body);
					end
				end
			else
				ngx.print(error002);
			end
		else
			ngx.print(error001);
		end

	else
		-- ::callavh::
		local avhdata = JSON.encode({ ["org"] = ngx.var.org,  ["dst"] = ngx.var.dst, ["airline"] = ngx.var.airline, ["date"] = tonumber(ngx.var.date), ["direct"] = null, ["fltNo"] = null, ["ibeFlag"] = "false", ["nonstop"] = "false", ["officeNo"] = "CAN911", ["page"] = 0, ["serviceName"] = "SBE_AV", ["stopCity"] = "", ["timestamp"] = basetime, ["token"] = tres});
		-- ngx.print(avhdata);
		-- ngx.print("\r\n---------------------\r\n");
		-- test hangxin
		-- local testvalue = JSON.encode({ ["org"] = "CAN",  ["dst"] = "LAX", ["airline"] = "CA", ["date"] = 20130301, ["direct"] = null, ["fltNo"] = null, ["ibeFlag"] = "false", ["nonstop"] = "false", ["officeNo"] = "CAN911", ["page"] = 0, ["serviceName"] = "SBE_AV", ["stopCity"] = "", ["timestamp"] = "2013-02-19 17:55:41", ["token"] = "ZGF0YXNlcnZpY2UwMSMyMDEzLTAyLTIxIDE1OjI1OjI1"});
		local skybusAuthmem = ngx.md5(tres .. "_" .. avhdata);
		-- ngx.print(skybusAuth);
		-- ngx.print("\r\n---------------------\r\n");
		-- cosocket post
		local hc = http:new()
		local ok, code, headers, status, body  = hc:request {
			url = "http://113.108.131.149:8060/sbe",
			--- proxy = "http://127.0.0.1:8888",
			--- timeout = 3000,
			method = "POST", -- POST or GET
			-- add post content-type and cookie
			headers = { skybusAuth = skybusAuthmem, ["Content-Type"] = "application/json" },
			body = avhdata,
		}
		-- ngx.say(ok)
		-- ngx.say(code)
		if body then
			local resbody = JSON.decode(body);
			local resultcode = tonumber(resbody.resultCode);
			-- ngx.say(resultcode)
			if resultcode == 0 then
				ngx.print(body);
			else
				local APPTOKEN = JSON.encode({ ["authenticator"] = clientinfo, ["timestamp"] = basetime, ["token"] = null, ["serviceName"] = "APPLY_TOKEN", ["class"] = "com.travelsky.sbeclient.authorization.AuthorizationRequest"});
				local hc1 = http:new()
				local ok1, code1, headers, status, body1  = hc1:request {
					url = "http://113.108.131.149:8060/sbe",
					--- proxy = "http://127.0.0.1:8888",
					--- timeout = 3000,
					method = "POST", -- POST or GET
					-- add post content-type and cookie
					-- headers = { skybusAuth = skybusAuth, ["Content-Type"] = "application/json" },
					body = APPTOKEN,
				}
				-- ngx.say(ok1)
				-- ngx.say(code1)
				-- ngx.say(body1)
				if body1 then
					local resbody1 = JSON.decode(body1);
					local tmptoken2 = resbody1.token;
					local ok, err = memc:set(sbeId, tmptoken2)
					if not ok then
						ngx.say("failed to set token: ", err)
						return
					end
					local avhdata2 = JSON.encode({ ["org"] = ngx.var.org,  ["dst"] = ngx.var.dst, ["airline"] = ngx.var.airline, ["date"] = tonumber(ngx.var.date), ["direct"] = null, ["fltNo"] = null, ["ibeFlag"] = "false", ["nonstop"] = "false", ["officeNo"] = "CAN911", ["page"] = 0, ["serviceName"] = "SBE_AV", ["stopCity"] = "", ["timestamp"] = basetime, ["token"] = tmptoken2});
					local skybusAuth2 = ngx.md5(tmptoken2 .. "_" .. avhdata2);
					-- ngx.say(avhdata2)
					-- ngx.say(skybusAuth2)
					local hc2 = http:new()
					local ok2, code2, headers, status, body2  = hc2:request {
						url = "http://113.108.131.149:8060/sbe",
						--- proxy = "http://127.0.0.1:8888",
						--- timeout = 3000,
						method = "POST", -- POST or GET
						-- add post content-type and cookie
						headers = { skybusAuth = skybusAuth2, ["Content-Type"] = "application/json" },
						body = avhdata2,
					}
					-- ngx.say(ok2)
					-- ngx.say(code2)
					if body2 then
						local resbody2 = JSON.decode(body2);
						local resultcode2 = tonumber(resbody2.resultCode);
						if resultcode2 == 0 then
							ngx.print(body2);
						else
							local res = ngx.location.capture("/data-avh/" .. ngx.var.org .. "/" .. ngx.var.dst .. "/" .. ngx.var.airline .. "/" .. ngx.var.date .. "/");
							if res.status == 200 then
								ngx.print(res.body);
							end
						end
					else
						ngx.print(error002);
					end
				else
					ngx.print(error001);
				end
			end
		else
			ngx.print(error002);
		end
	end
--[[
	-- Extenal POST.
        local handle = io.popen("lua /home/www/luadev/http-test.lua");
        local resw = handle:read("*a");
        handle:close();
	ngx.print(resw);

	-- http://113.108.131.149:8060/sbe
	-- local sbeId = "dataservice01";
	-- local Pwd = "dataservice01";
	-- http://113.108.131.149:7060/sbeTry
	-- local hangxin = "emh0ZHRlc3QwMSMxZjU0NTY5MmRkZDJiZWFjOWZjNTc0M2U2MmM0ZmMxMyNhYWFkMzQ1Ng";
	local hangxin = "ZGF0YXNlcnZpY2UwMSM1NzZlYTNhMTU1YTE4Mjg2ZjM2NWYwMGZiZTg1ZThjYSMyMzQ1NjkxNQ==";
	local authclientinfo = sbeId .. "#" .. ngx.md5(Pwd) .. "#" .. "23456915";
	ngx.print(authclientinfo);
	ngx.print("\r\n---------------------\r\n");
	local hxclient = ngx.decode_base64(hangxin);
	local clientinfo = ngx.encode_base64(hxclient);
	ngx.print(clientinfo);
	ngx.print("\r\n---------------------\r\n");
	ngx.print(hxclient);
	ngx.print("\r\n---------------------\r\n");
        local handle = io.input("/home/www/AVResponse.json");
        local resw = handle:read("*all");
        handle:close();
	ngx.print(resw);
--]]
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
