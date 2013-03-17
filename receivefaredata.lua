-- buyhome <huangqi@rhomobi.com> 20130321 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/23
-- FARE data-base interface

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

local ok, err = red:connect("127.0.0.1", 6366)
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
		local tmprandom = math.random(1,1000000);
		local content = JSON.decode(pcontent);
		-- Check baseSEGMENTS's S_NUMBER.
		local cscount = 0;
		for idx, value in ipairs(content.SEGMENTS) do
			cscount = cscount + 1;
		end
		-- Check farePERIODS's P_NUMBER.
		local cpcount = 0;
		local oraclefids = ""; -- Get the fareids from oracleDB.
		for idx, value in ipairs(content.PERIODS) do
			for key, value1 in pairs(value) do
				if key == "FARE_ID" then
					oraclefids = oraclefids .. value1;
				end
			end
			cpcount = cpcount + 1;
		end
		ngx.print(oraclefids);
		ngx.print("\r\n---------------------\r\n");
		-- Check if S_NUMBER NOT baseSEGMENTS' number Or P_NUMBER NOT farePERIODS' number?
		if (cscount ~= tonumber(content.S_NUMBER) or cpcount ~= tonumber(content.P_NUMBER)) then
			ngx.print("Please Check if S_NUMBER NOT baseSEGMENTS' number Or P_NUMBER NOT farePERIODS' number!");
			-- ngx.exit(ngx.HTTP_BAD_REQUEST);
			-- return will NOT end to excute the following code.
		else
			-- Caculate farekey:ORG+DST+BASE_AIRLINE+CITY_PATH+SELL_START_DATE+SELL_END_DATE+TRAVELER_TYPE_ID
			-- Add oraclefids to protect the farekey is unique.
			local farekey = ngx.md5(tmprandom .. ngx.now() .. oraclefids .. content.ORG .. content.DST .. content.BASE_AIRLINE .. content.CITY_PATH .. content.SELL_START_DATE .. content.SELL_END_DATE .. content.TRAVELER_TYPE_ID);
			local cavhcmd = content.ORG .. content.DST .. content.BASE_AIRLINE;
			local avhmulti = content.ORG .. "/" .. content.DST .. "/" .. content.BASE_AIRLINE .. "/";
			local fid = "";
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
				-- fare:id INCR
				-- local farecounter, cerror = red:incr("next.fare.id")
				local farecounter, cerror = red:incr("fare:id")
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
				-- if resultsetnx ~= 1 that is SETNX is NOT sucess.
				if resultsetnx == 1 then
					fid = farecounter;
				else
					fid = red:get("fare:" .. farekey .. ":id");
				end
				-- Get the fid = fare:[farekey]:id
				ngx.say("The real fare.id is fid: ", fid);
				ngx.print("\r\n---------------------\r\n");
				-- baseFARE information.
				local resbasefare, bferror = red:mset("fare:" .. fid .. ":AVHCMD", avhmulti, "fare:" .. fid .. ":ORGDST", content.ORG .. content.DST, "fare:" .. fid .. ":BASE_AIRLINE", content.BASE_AIRLINE, "fare:" .. fid .. ":CITY_PATH", content.CITY_PATH, "fare:" .. fid .. ":SELL_START_DATE", content.SELL_START_DATE, "fare:" .. fid .. ":SELL_END_DATE", content.SELL_END_DATE, "fare:" .. fid .. ":TRAVELER_TYPE_ID", content.TRAVELER_TYPE_ID, "fare:" .. fid .. ":S_NUMBER", content.S_NUMBER, "fare:" .. fid .. ":POLICY_ID", content.POLICY_ID, "fare:" .. fid .. ":CURRENCY_CODE", content.CURRENCY_CODE, "fare:" .. fid .. ":PRICE", content.PRICE, "fare:" .. fid .. ":CHILD_PRICE", content.CHILD_PRICE, "fare:" .. fid .. ":MIN_TRAVELER_COUNT", content.MIN_TRAVELER_COUNT)
				if not resbasefare then
					ngx.say("failed to MSET basefare info: ", bferror);
					return
				end
				local avhres, avherr = red:sadd("AVHCMD:" .. cavhcmd, fid)
				if not avhres then
					ngx.say("failed to SET AVHCMD: ", avherr);
					return
				end
				local cityres, cityerr = red:sadd("ORGDST:" .. content.ORG .. content.DST .. ":FID", fid)
				if not cityres then
					ngx.say("failed to SET ORGDST: ", cityerr);
					return
				else
					-- change Caculate structure @20130306
					local snumres, snumerr = red:sadd("ORGDST:" .. content.ORG .. content.DST .. ":S_NUMBER:" .. content.S_NUMBER, fid)
					if not snumres then
						ngx.say("failed to SET S_NUMBER: ", snumerr);
						return
					end
					local trares, traerr = red:sadd("ORGDST:" .. content.ORG .. content.DST .. ":TRAVELER:" .. content.TRAVELER_TYPE_ID, fid)
					if not trares then
						ngx.say("failed to SET TRAVELER_TYPE_ID: ", traerr);
						return
					end
					--[[
					-- destroy 20130308 if content.AIRLINE is null, i will get the fid' AVHCMD (CAN/LAX/CZ/ etc.)
					local cityres, cityerr = red:sadd("ORGDST:" .. content.ORG .. content.DST .. ":CMD", cavhcmd)
					if not cityres then
						ngx.say("failed to SET ORGDST'S CMD: ", cityerr);
						return
					end
					--]]
				end
				-- sort fid by MIN_TRAVELER_COUNT
				local mtcres, mtcerr = red:zadd("fare:MIN_TRAVELER_COUNT", content.MIN_TRAVELER_COUNT, fid)
				if not mtcres then
					ngx.say("failed to zadd the fare:MIN_TRAVELER_COUNT:" .. content.MIN_TRAVELER_COUNT, mtcerr);
					return
				end
				-- sort fid by SELL_END_DATE
				local sendres, senderr = red:zadd("fare:SELL_END_DATE", content.SELL_END_DATE, fid)
				if not sendres then
					ngx.say("failed to zadd the fare:SELL_END_DATE:" .. content.SELL_END_DATE, senderr);
					return
				end
				-- sort fid by SELL_START_DATE
				local sstartres, sstarterr = red:zadd("fare:SELL_START_DATE", content.SELL_START_DATE, fid)
				if not sstartres then
					ngx.say("failed to zadd the fare:SELL_START_DATE:" .. content.SELL_START_DATE, sstarterr);
					return
				end
				-- farePERIODS information.
				local pcount = 1;
				for idx, value in ipairs(content.PERIODS) do
					local oraclefid = "";
					local startdate = "";
					local enddate = "";
					for key, value1 in pairs(value) do
						if key ~= "LIMITEDWEEKS" then
							ngx.print(key, ":", value1);
							ngx.print("\r\n---------------------\r\n");
							local res, err = red:hmset("fare:" .. fid .. ":PERIODS:" .. pcount, key, value1)
							if not res then
								ngx.say("failed to hmset the hashes data : [fare:" .. fid .. ":PERIODS:" .. pcount .. "]", err);
								return
							end
							if key == "FARE_ID" then
								oraclefid =  value1;
							end
							if key == "START_DATE" then
								startdate =  tonumber(value1);
							end
							if key == "END_DATE" then
								enddate =  tonumber(value1);
							end
							-- sort FARE_ID by startdate
							local stares, staerr = red:zadd("PERIODS:START", startdate, oraclefid)
							if not stares then
								ngx.say("failed to zadd the PERIODS:START:" .. oraclefid, staerr);
								return
							end
							-- sort FARE_ID by enddate
							local endres, enderr = red:zadd("PERIODS:END", enddate, oraclefid)
							if not endres then
								ngx.say("failed to zadd the PERIODS:END:" .. oraclefid, enderr);
								return
							end
						else
							-- LIMITEDWEEKS SETS
							for wkey, wvalue1 in ipairs(value1) do
								local wres, werr = red:sadd("PERIODS:" .. wvalue1, oraclefid)
								if not wres then
									ngx.say("failed to SET LIMITEDWEEKS: ", werr);
									return
								end
								ngx.print(wvalue1);
								ngx.print("\r\n+++++++++\r\n");
							end
						end
						-- HASHES FARE_ID
						if key == "FARE_ID" then
							local farehkey = string.sub(string.format("%011d", value1), 1, 8);
							local res, err = red:hmset("PERIODS:fid:" .. farehkey, value1, fid)
							if not res then
								ngx.say("failed to hmset the hashes data : [PERIODS:fid:" .. farehkey .. "]", err);
								return
							end
						end
					end
					pcount = pcount + 1;
					ngx.print(pcount);
					ngx.print("\r\n+++++++++\r\n");
				end
				-- baseSEGMENTS information.
				local scount = 1;
				for idx, value in ipairs(content.SEGMENTS) do
					for key, value1 in pairs(value) do
						if (key ~= "LIMITEDTIMEINDEX" and key ~= "LIMITEDTIMEDATA" and key ~= "ALLOWTIMEINDEX" and key ~= "ALLOWTIMEDATA") then
							ngx.print(key, ":", value1);
							ngx.print("\r\n---------------------\r\n");
							local res, err = red:hmset("fare:" .. fid .. ":SEGMENTS:" .. scount, key, value1)
							if not res then
								ngx.say("failed to hmset the hashes data : [fare:" .. fid .. ":SEGMENTS:" .. scount .. "]", err);
								return
							end
						end
						if key == "BUNKLEVEL" then
							-- change Caculate structure @20130306
							local res, err = red:sadd("ORGDST:" .. content.ORG .. content.DST .. ":BUNKLEVEL:" .. value1, fid)
							if not res then
								ngx.say("failed to SET BUNKLEVEL for Caculate: ", err);
								return
							end
						end
					end
					scount = scount + 1;
					ngx.print(scount);
					ngx.print("\r\n+++++++++\r\n");
				end
			else
				ngx.print("The FARE had already been stored!");
				ngx.print("\r\n---------------------\r\n");
				ngx.print("fare:" .. farekey .. ":id: ", getfidres);
				ngx.print("\r\n---------------------\r\n");
			end
--[[
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
			-- ADD LIMITEDWEEKS so content.PERIODS changed to be table.
			for idx, value in ipairs(content.PERIODS) do
				for key, value1 in pairs(value) do
					ngx.print(key, ":", value1);
					ngx.print("\r\n---------------------\r\n");
				end
			end
--]]
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
			-- sets of FLIGHT by 0 = ALLOW_FLIGHT
			if content.ALLOW_FLIGHT ~= nil then
				for idx, value in ipairs(content.ALLOW_FLIGHT) do
					-- ngx.print(value);
					-- ngx.print("\r\n---------------------\r\n");
					local res, err = red:sadd("fare:" .. fid .. ":FLIGHT:0", value)
					if not res then
						ngx.say("failed to sadd the fare:" .. fid .. ":FLIGHT:0", err);
						return
					end
				end
			end
			-- sets of FLIGHT by 1 = NOT_ALLOW_FLIGHT
			if content.NOT_ALLOW_FLIGHT ~=nil then
				for idx, value in ipairs(content.NOT_ALLOW_FLIGHT) do
					-- ngx.print(value);
					-- ngx.print("\r\n---------------------\r\n");
					local res, err = red:sadd("fare:" .. fid .. ":FLIGHT:1", value)
					if not res then
						ngx.say("failed to sadd the fare:" .. fid .. ":FLIGHT:1", err);
						return
					end
				end
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
			-- Changed to following the SEGMENTS 20130130 .
			-- ngx.print(content.RETREAT);
			-- ngx.print(content.RULE);
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
