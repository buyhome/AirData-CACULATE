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

if ngx.var.request_method == "GET" then
        ngx.exit(ngx.HTTP_FORBIDDEN);
end

if ngx.var.request_method == "POST" then

	ngx.req.read_body();
	local pcontent = ngx.req.get_body_data();
	if pcontent then
		-- Maybe 1000000 process POST faredata
		-- local tmprandom = math.random(1,1000000);
		local content = JSON.decode(pcontent);
		-- Caculate farekey:ORG+DST+BASE_AIRLINE+CITY_PATH+SELL_START_DATE+SELL_END_DATE+TRAVELER_TYPE_ID
		local farekey = ngx.md5(content.ORG .. content.DST .. content.BASE_AIRLINE .. content.CITY_PATH .. content.SELL_START_DATE .. content.SELL_END_DATE .. content.TRAVELER_TYPE_ID);
		local cavhcmd = content.ORG .. content.DST .. content.BASE_AIRLINE;
		ngx.print("AVHCMD is: ", cavhcmd);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(farekey);
		ngx.print("\r\n---------------------\r\n");
		
		local getfidres, getfiderr = red:get("fare:" .. farekey .. ":id")
		if not getfidres then
			ngx.say("failed to get " .. "fare:" .. farekey .. ":id: ", getfiderr)
			return
		end
		ngx.print(getfidres);
		ngx.print("\r\n---------------------\r\n");

		if tonumber(getfidres) == nil then
		
			local farecounter, cerror = red:incr("next.fare.id")
			if not farecounter then
				ngx.say("failed to INCR fare: ", cerror);
				return
			end
			
			ngx.say("INCR fare result: ", farecounter);
			ngx.print("\r\n---------------------\r\n");
			
			local resultsetnx, fiderror = red:setnx("fare:" .. farekey .. ":id", farecounter)
			if not resultsetnx then
				ngx.say("failed to SETNX fid: ", fiderror);
				return
			end

			ngx.say("SETNX fid result: ", resultsetnx);
			ngx.print("\r\n---------------------\r\n");
			
			local fid = "";
			if resultsetnx == 1 then
				fid = farecounter;
			else
				fid = red:get("fare:" .. farekey .. ":id");
			end
			-- Get the fid = fare:[farekey]:id
			ngx.say("The real fare.id is fid: ", fid);
			ngx.print("\r\n---------------------\r\n");
			
			-- basefare information.
			local resbasefare, bferror = red:mset("fare:" .. fid .. ":AVHCMD", cavhcmd, "fare:" .. fid .. ":ORG", content.ORG, "fare:" .. fid .. ":DST", content.DST, "fare:" .. fid .. ":BASE_AIRLINE", content.BASE_AIRLINE, "fare:" .. fid .. ":CITY_PATH", content.CITY_PATH, "fare:" .. fid .. ":SELL_START_DATE", content.SELL_START_DATE, "fare:" .. fid .. ":SELL_END_DATE", content.SELL_END_DATE, "fare:" .. fid .. ":TRAVELER_TYPE_ID", content.TRAVELER_TYPE_ID, "fare:" .. fid .. ":S_NUMBER", content.S_NUMBER, "fare:" .. fid .. ":POLICY_ID", content.POLICY_ID, "fare:" .. fid .. ":CURRENCY_CODE", content.CURRENCY_CODE, "fare:" .. fid .. ":PRICE", content.PRICE, "fare:" .. fid .. ":CHILD_PRICE", content.CHILD_PRICE, "fare:" .. fid .. ":MIN_TRAVELER_COUNT", content.MIN_TRAVELER_COUNT)
			if not resbasefare then
				ngx.say("failed to MSET basefare info: ", bferror);
				return
			end
			
			-- SEGMENTS information.
		
		else
		
			ngx.say("fare:" .. farekey .. ":id: ", getfidres);
			ngx.print("\r\n---------------------\r\n");
		
		end
		
		ngx.print(content.OP);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.LINE_TYPE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.CITY_PATH);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.ORG);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.DST);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.P_NUMBER);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.SELL_START_DATE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.SELL_END_DATE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.S_NUMBER);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.TRAVELER_TYPE_ID);
		ngx.print("\r\n---------------------\r\n");
		for idx, value in ipairs(content.PERIODS) do
			for key, value1 in pairs(value) do
				ngx.print(key, ":", value1);
				ngx.print("\r\n---------------------\r\n");
			end
		end
		for idx, value in ipairs(content.SEGMENTS) do
			for key, value1 in pairs(value) do
				if key == "LIMITEDTIMEINDEX" then
					for tkey, tvalue1 in ipairs(value1) do
						ngx.print(tvalue1);
						ngx.print("\r\n---------------------\r\n");
					end
				end
				if key == "LIMITEDTIMEDATA" then
					for tkey, tvalue1 in ipairs(value1) do
						ngx.print(tvalue1);
						ngx.print("\r\n---------------------\r\n");
					end
				end
				if key == "ALLOWTIMEINDEX" then
					for tkey, tvalue1 in ipairs(value1) do
						ngx.print(tvalue1);
						ngx.print("\r\n---------------------\r\n");
					end
				end
				if key == "ALLOWTIMEDATA" then
					for tkey, tvalue1 in ipairs(value1) do
						ngx.print(tvalue1);
						ngx.print("\r\n---------------------\r\n");
					end
				end
				if (key ~= "LIMITEDTIMEINDEX" and key ~= "LIMITEDTIMEDATA" and key ~= "ALLOWTIMEINDEX" and key ~= "ALLOWTIMEDATA") then
					ngx.print(key, ":", value1);
					ngx.print("\r\n---------------------\r\n");
				end
			end
		end
		for idx, value in ipairs(content.ALLOW_FLIGHT) do
			ngx.print(value);
			ngx.print("\r\n---------------------\r\n");
		end
		for idx, value in ipairs(content.NOT_ALLOW_FLIGHT) do
			ngx.print(value);
			ngx.print("\r\n---------------------\r\n");
		end
		ngx.print(content.MIN_TRAVELER_COUNT);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.PRICE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.CHILD_PRICE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.CURRENCY_CODE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.BASE_AIRLINE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.POLICY_ID);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.RETREAT);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.RULE);
		ngx.print("\r\n---------------------\r\n");
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