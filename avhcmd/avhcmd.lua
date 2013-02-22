-- buyhome <huangqi rhomobi com> 20130321 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/23
-- hangxin interface

-- load library
local redis = require "resty.redis"
-- ready to connect to master redis.
local red, err = redis:new()
if not red then
	ngx.say("failed to instantiate redis: ", err)
	return
end

-- Sets the timeout (in ms) protection for subsequent operations, including the connect method.
red:set_timeout(600)

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
	ngx.say("failed to connect: ", err)
	return
end

local JSON = require("cjson");

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
	local sbeId = "CANZHTD01";
	local Pwd = "canzhtd01";
	local tmptoken = "ZGF0YXNlcnZpY2UwMSMyMDEzLTAyLTIxIDE1OjI1OjI1";
	-- ngx.localtime() == os.date("%Y-%m-%d %X", ngx.now());
	local avhdata = JSON.encode({ ["org"] = ngx.var.org,  ["dst"] = ngx.var.dst, ["airline"] = ngx.var.airline, ["date"] = tonumber(ngx.var.date), ["direct"] = null, ["fltNo"] = null, ["ibeFlag"] = "false", ["nonstop"] = "false", ["officeNo"] = "CAN911", ["page"] = 0, ["serviceName"] = "SBE_AV", ["stopCity"] = "", ["timestamp"] = ngx.localtime(), ["token"] = tmptoken});
	ngx.print(avhdata);
	ngx.print("\r\n---------------------\r\n");
	-- test hangxin
	-- local testvalue = JSON.encode({ ["org"] = "CAN",  ["dst"] = "LAX", ["airline"] = "CA", ["date"] = 20130301, ["direct"] = null, ["fltNo"] = null, ["ibeFlag"] = "false", ["nonstop"] = "false", ["officeNo"] = "CAN911", ["page"] = 0, ["serviceName"] = "SBE_AV", ["stopCity"] = "", ["timestamp"] = "2013-02-19 17:55:41", ["token"] = "ZGF0YXNlcnZpY2UwMSMyMDEzLTAyLTIxIDE1OjI1OjI1"});
	local skybusAuth = ngx.md5(tmptoken .. "_" .. avhdata);
	ngx.print(skybusAuth);
	ngx.print("\r\n---------------------\r\n");
	-- cosocket post
	local http = require "resty.http"
	local hc = http:new()
	local ok, code, headers, status, body  = hc:request {
	url = "http://rhomobi.com/",
	--- proxy = "http://127.0.0.1:8888",
	--- timeout = 3000,
	method = "GET", -- POST or GET
	-- add post content-type and cookie
	-- headers = { Cookie = "ABCDEFG", ["Content-Type"] = "application/x-www-form-urlencoded" },
	-- body = "uid=1234567890",
	}
	ngx.say(ok)
	ngx.say(code)
	ngx.say(body)
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