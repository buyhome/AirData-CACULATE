-- buyhome <huangqi@rhomobi.com> 20130321 (v0.5.2)
-- because wks had changed the idname at 20130320
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
red:set_timeout(6000)
local ok, err = red:connect("127.0.0.1", 6366)
if not ok then
	ngx.say("failed to connect: ", err);
	return
end
local JSON = require("cjson");
local error000 = JSON.encode({ ["errorcode"] = 0, ["description"] = "The FARE has been stored"});
local error001 = JSON.encode({ ["errorcode"] = 1, ["description"] = "Please Check if S_NUMBER NOT baseSEGMENTS' number Or P_NUMBER NOT farePERIODS' number!"});
local error003 = JSON.encode({ ["errorcode"] = 3, ["description"] = "Please Check if content.ticketSegments[1].goStartTime=goEndTime?"});
local error004 = JSON.encode({ ["errorcode"] = 4, ["description"] = "Please Check if content.ticketSegments[1].goStartTime&goEndTime.allowtime array?"});
local error005 = JSON.encode({ ["errorcode"] = 5, ["description"] = "Please Check if content.ticketSegments[1].goStartTime&goEndTime.limitedTime array?"});
-- The FARE had already been stored
function error002(des)
	local res = JSON.encode({ ["errorcode"] = 2, ["description"] = des});
	return res
end
-- alltime&limtime Check
function timecac(st, ed)
	if ( st ~= nil and ed == nil ) or ( st == nil and ed ~= nil ) then
		return 1, nil
	else
		if st ~= nil and ed ~= nil then
			local lenst = table.getn(st);
			local lened = table.getn(ed);
			if lenst ~= lened then
				return 1, nil
			else
				if lenst ~= 0 then
					return 0, lenst
				end
			end
		end
		if st == nil and ed == nil then
			return 2, nil
		end
	end
end
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
		-- Check baseSEGMENTS's S_NUMBER.
		local cscount = 0;
		for idx, value in ipairs(content.ticketSegments) do
			cscount = cscount + 1;
		end
		-- Check farePERIODS's P_NUMBER.
		local cpcount = 0;
		local oraclefids = "";
		-- Get the fareids from oracleDB.
		for idx, value in ipairs(content.ticketPeriods) do
			for key, value1 in pairs(value) do
				if key == "fareId" then
					oraclefids = oraclefids .. "|" .. value1;
				end
			end
			cpcount = cpcount + 1;
		end
		-- ngx.print(oraclefids);
		-- ngx.print("\r\n----------------fareids from oracleDB-----------------\r\n");
		-- Check if S_NUMBER NOT baseSEGMENTS' number Or P_NUMBER NOT farePERIODS' number?
		if (cscount ~= tonumber(content.SNumber) or cpcount ~= tonumber(content.PNumber)) then
			ngx.print(error001);
		else
			-- LT data Check
			local limtimesta = content.ticketSegments[1].goStartTime.limitedTime;
			local alltimesta = content.ticketSegments[1].goStartTime.allowTime;
			local limtimeend = content.ticketSegments[1].goEndTime.limitedTime;
			local alltimeend = content.ticketSegments[1].goEndTime.allowTime;
			local allcac, alllen = timecac(alltimesta, alltimeend);
			local limcac, limlen = timecac(limtimesta, limtimeend);
			if allcac == 1 or limcac == 1 then
				ngx.print(error003);
			else
				if allcac == 0 then
					if alllen > 1 then
						for idx = 1, alllen-1 do
							if ( tonumber(alltimesta[idx]) > tonumber(alltimeend[idx]) ) or ( tonumber(alltimesta[idx]) > tonumber(alltimesta[idx+1]) ) or ( tonumber(alltimeend[idx]) > tonumber(alltimeend[idx+1]) ) then
								ngx.print(error004);
								ngx.exit(200);
							end
						end
					else
						if alllen == 1 then
							if tonumber(alltimesta[1]) > tonumber(alltimeend[1]) then
								ngx.print(error004);
								ngx.exit(200);
							end
						end
					end
				end
				if limcac == 0 then
					if limlen > 1 then
						for idx = 1, limlen-1 do
							if ( tonumber(limtimesta[idx]) > tonumber(limtimeend[idx]) ) or ( tonumber(limtimesta[idx]) > tonumber(limtimesta[idx+1]) ) or ( tonumber(limtimeend[idx]) > tonumber(limtimeend[idx+1]) ) then
								ngx.print(error005);
								ngx.exit(200);
							end
						end
					else
						if limlen == 1 then
							if tonumber(limtimesta[1]) > tonumber(limtimeend[1]) then
								ngx.print(error005);
								ngx.exit(200);
							end
						end
					end
				end
				-- Caculate farekey:ORG+DST+BASE_AIRLINE+CITY_PATH+SELL_START_DATE+SELL_END_DATE+TRAVELER_TYPE_ID
				-- Add oraclefids to protect the farekey is unique.
				local farekey = ngx.md5(oraclefids .. content.org .. content.dst .. content.baseAirLine .. content.airPortPath .. content.sellStartDate .. content.sellEndDate .. content.travelerTypeId);
				local cavhcmd = content.org .. content.dst .. content.baseAirLine;
				local avhmulti = content.org .. "/" .. content.dst .. "/" .. content.baseAirLine .. "/";
				local fid = "";
				-- ngx.print("AVHCMD is: ", cavhcmd);
				-- ngx.print("\r\n---------------------\r\n");
				-- ngx.print("avhmulti is: ", avhmulti);
				-- ngx.print("\r\n---------------------\r\n");
				-- ngx.print(farekey);
				-- ngx.print("\r\n---------------------\r\n");
				local getfidres, getfiderr = red:get("fare:" .. farekey .. ":id")
				if not getfidres then
					ngx.print("failed to get " .. "fare:" .. farekey .. ":id: ", getfiderr)
					return
				end
				-- ngx.print(getfidres);
				-- ngx.print("\r\n---------------------\r\n");
				if tonumber(getfidres) == nil then
					-- fare:id INCR
					-- local farecounter, cerror = red:incr("next.fare.id")
					local farecounter, cerror = red:incr("fare:id")
					if not farecounter then
						ngx.print("failed to INCR fare: ", cerror);
						return
					end
					-- ngx.print("INCR fare result: ", farecounter);
					-- ngx.print("\r\n---------------------\r\n");
					local resultsetnx, fiderror = red:setnx("fare:" .. farekey .. ":id", farecounter)
					if not resultsetnx then
						ngx.print("failed to SETNX fid: ", fiderror);
						return
					end
					-- ngx.print("SETNX fid result: ", resultsetnx);
					-- ngx.print("\r\n---------------------\r\n");
					-- if resultsetnx ~= 1 that is SETNX is NOT sucess.
					if resultsetnx == 1 then
						fid = farecounter;
					else
						fid = red:get("fare:" .. farekey .. ":id");
					end
					-- Get the fid = fare:[farekey]:id
					-- ngx.print("The real fare.id is fid: ", fid);
					-- ngx.print("\r\n---------------------\r\n");
					-- ready to store the fare information.
					-- baseFARE information.
					local resbasefare, bferror = red:mset("fare:" .. fid .. ":AVHCMD", avhmulti, "fare:" .. fid .. ":ORGDST", content.org .. content.dst, "fare:" .. fid .. ":BASE_AIRLINE", content.baseAirLine, "fare:" .. fid .. ":CITY_PATH", content.airPortPath, "fare:" .. fid .. ":SELL_START_DATE", content.sellStartDate, "fare:" .. fid .. ":SELL_END_DATE", content.sellEndDate, "fare:" .. fid .. ":TRAVELER_TYPE_ID", content.travelerTypeId, "fare:" .. fid .. ":S_NUMBER", content.SNumber, "fare:" .. fid .. ":POLICY:ID", content.policyId, "fare:" .. fid .. ":CURRENCY_CODE", content.currencyCode, "fare:" .. fid .. ":PRICE", content.price, "fare:" .. fid .. ":CHILD_PRICE", content.childPrice, "fare:" .. fid .. ":MIN_TRAVELER_COUNT", content.minTravelerCount)
					if not resbasefare then
						ngx.say("failed to MSET basefare info: ", bferror);
						return
					end
					local avhres, avherr = red:sadd("AVHCMD:" .. cavhcmd, fid)
					if not avhres then
						ngx.say("failed to SET AVHCMD: ", avherr);
						return
					end
					local cityres, cityerr = red:sadd("ORGDST:" .. content.org .. content.dst .. ":FID", fid)
					if not cityres then
						ngx.say("failed to SET ORGDST: ", cityerr);
						return
					else
						-- change Caculate structure @20130306
						local snumres, snumerr = red:sadd("ORGDST:" .. content.org .. content.dst .. ":S_NUMBER:" .. content.SNumber, fid)
						if not snumres then
							ngx.say("failed to SET S_NUMBER: ", snumerr);
							return
						end
						local trares, traerr = red:sadd("ORGDST:" .. content.org .. content.dst .. ":TRAVELER:" .. content.travelerTypeId, fid)
						if not trares then
							ngx.say("failed to SET TRAVELER_TYPE_ID: ", traerr);
							return
						end
						-- destroy 20130308 if content.AIRLINE is null, i will get the fid' AVHCMD (CAN/LAX/CZ/ etc.)
						local cityres, cityerr = red:sadd("ORGDST:" .. content.org .. content.dst .. ":CMD", cavhcmd)
						if not cityres then
							ngx.say("failed to SET ORGDST'S CMD: ", cityerr);
							return
						end
						-- sort fid
						-- sort fid by MIN_TRAVELER_COUNT
						local mtcres, mtcerr = red:zadd("ORGDST:" .. content.org .. content.dst .. ":MIN_TRAVELER_COUNT", content.minTravelerCount, fid)
						if not mtcres then
							ngx.say("failed to zadd the ORGDST:MIN_TRAVELER_COUNT:" .. content.minTravelerCount, mtcerr);
							return
						end
						-- sort fid by SELL_END_DATE
						local sendres, senderr = red:zadd("ORGDST:" .. content.org .. content.dst .. ":SELL_END_DATE", content.sellEndDate, fid)
						if not sendres then
							ngx.say("failed to zadd the ORGDST:SELL_END_DATE:" .. content.sellEndDate, senderr);
							return
						end
						-- sort fid by SELL_START_DATE
						local sstartres, sstarterr = red:zadd("ORGDST:" .. content.org .. content.dst .. ":SELL_START_DATE", content.sellStartDate, fid)
						if not sstartres then
							ngx.say("failed to zadd the ORGDST:SELL_START_DATE:" .. content.sellStartDate, sstarterr);
							return
						end
					end
					-- 20130321
					-- farePERIODS information.
					local pcount = 1;
					for idx, value in ipairs(content.ticketPeriods) do
						local ofid = "";
						local startdate = "";
						local enddate = "";
						for key, value1 in pairs(value) do
							if key ~= "goLimitedWeeks" and key ~= "backLimitedWeeks" then
								-- ngx.print(key, ":", value1);
								-- ngx.print("\r\n---------------------\r\n");
								local res, err = red:hmset("fare:" .. fid .. ":PERIODS:" .. pcount, key, value1)
								if not res then
									ngx.say("failed to hmset the hashes data : [fare:" .. fid .. ":PERIODS:" .. pcount .. "]", err);
									return
								end
								-- HASHES FARE_ID
								if key == "fareId" then
									ofid = tonumber(value1);
									local farehkey = string.sub(string.format("%011d", value1), 1, 8);
									local res, err = red:hmset("PERIODS:fid:" .. farehkey, value1, fid)
									if not res then
										ngx.say("failed to hmset the hashes data : [PERIODS:fid:" .. farehkey .. "]", err);
										return
									end
								end
								if key == "startDate" then
									startdate =  tonumber(value1);
								end
								if key == "endDate" then
									enddate =  tonumber(value1);
								end
							end
						end
						-- do it at the ticketPeriods
						-- ngx.print("|" .. ofid .. "|" .. startdate .. "|" .. enddate .. "|");
						-- ngx.print("\r\n----------------ofid&startdate&enddate-----------------\r\n");
						-- sort FARE_ID by startdate
						local stares, staerr = red:zadd("PERIODS:START", startdate, ofid)
						if not stares then
							ngx.say("failed to zadd the PERIODS:START:" .. ofid, staerr);
							return
						end
						-- sort FARE_ID by enddate
						local endres, enderr = red:zadd("PERIODS:END", enddate, ofid)
						if not endres then
							ngx.say("failed to zadd the PERIODS:END:" .. ofid, enderr);
							return
						end
						-- LIMITEDWEEKS SETS
						for key, value1 in pairs(value) do
							if key == "goLimitedWeeks" then
								local lw = value1[1].weeks;
								local idxs = table.getn(lw);
								local idxi = 1;
								while idxi <= idxs do
									-- ngx.print(ofid .. ":" .. lw[idxi]);
									-- ngx.print("\r\n----------------goLimitedWeeks-----------------\r\n");
									local res, err = red:sadd("PERIODS:" .. lw[idxi], ofid)
									if not res then
										ngx.say("failed to SET LIMITEDWEEKS: ", err);
										return
									end
									idxi = idxi + 1;
								end
							end
						end
						pcount = pcount + 1;
						-- ngx.print(pcount);
						-- ngx.print("\r\n+++++++++\r\n");
					end
					-- 20130322
					-- baseSEGMENTS information.
					local scount = 1;
					for idx, value in ipairs(content.ticketSegments) do
						for key, value1 in pairs(value) do
							if (key ~= "backEndTime" and key ~= "backStartTime" and key ~= "goEndTime" and key ~= "goStartTime") then
								-- ngx.print(key, ":", value1);
								-- ngx.print("\r\n---------------------\r\n");
								local res, err = red:hmset("fare:" .. fid .. ":SEGMENTS:" .. scount, key, value1)
								if not res then
									ngx.say("failed to hmset the hashes data : [fare:" .. fid .. ":SEGMENTS:" .. scount .. "]", err);
									return
								end
							end
							if key == "bunkLevel" then
								-- change Caculate structure @20130306
								local res, err = red:sadd("ORGDST:" .. content.org .. content.dst .. ":BUNKLEVEL:" .. value1, fid)
								if not res then
									ngx.say("failed to SET BUNKLEVEL for Caculate: ", err);
									return
								end
							end
						end
						scount = scount + 1;
						-- ngx.print(scount);
						-- ngx.print("\r\n+++++++++\r\n");
					end
					-- sets of FLIGHT by 0 = ALLOW_FLIGHT
					if content.allowFlights ~= nil then
						for idx, value in ipairs(content.allowFlights) do
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
					if content.notAllowFlights ~=nil then
						for idx, value in ipairs(content.notAllowFlights) do
							-- ngx.print(value);
							-- ngx.print("\r\n---------------------\r\n");
							local res, err = red:sadd("fare:" .. fid .. ":FLIGHT:1", value)
							if not res then
								ngx.say("failed to sadd the fare:" .. fid .. ":FLIGHT:1", err);
								return
							end
						end
					end
					-- LT time zsets
					if allcac == 0 then
						if alllen > 1 then
							for idx = 1, alllen-1 do
								if tonumber(alltimeend[idx]) < tonumber(alltimesta[idx+1]) then
									-- ngx.say(alltimeend[idx] .. ":" .. alltimesta[idx+1]);
									local res, err = red:zadd("fare:" .. fid .. ":LT:sta", tonumber(alltimeend[idx]), idx+1)
									if not res then
										ngx.say("failed to sort the LIMITEDTIMEINDEX data : [fare:" .. fid .. ":LT:sta]", err);
										ngx.say("-------------1------------");
										return
									end
									local res, err = red:zadd("fare:" .. fid .. ":LT:end", tonumber(alltimesta[idx+1]), idx+1)
									if not res then
										ngx.say("failed to sort the LIMITEDTIMEDATA data : [fare:" .. fid .. ":LT:end]", err);
										return
									end
								end
							end
						end
						local res, err = red:zadd("fare:" .. fid .. ":LT:sta", 0, 1)
						if not res then
							ngx.say("failed to sort the LIMITEDTIMEINDEX data : [fare:" .. fid .. ":LT:sta]", err);
							ngx.say("-------------2------------");
							return
						end
						local res, err = red:zadd("fare:" .. fid .. ":LT:sta", tonumber(alltimeend[alllen]), alllen+1)
						if not res then
							ngx.say("failed to sort the LIMITEDTIMEINDEX data : [fare:" .. fid .. ":LT:sta]", err);
							ngx.say("-------------3------------");
							return
						end
						local res, err = red:zadd("fare:" .. fid .. ":LT:end", tonumber(alltimesta[1]), 1)
						if not res then
							ngx.say("failed to sort the LIMITEDTIMEDATA data : [fare:" .. fid .. ":LT:end]", err);
							return
						end
						local res, err = red:zadd("fare:" .. fid .. ":LT:end", 2400, alllen+1)
						if not res then
							ngx.say("failed to sort the LIMITEDTIMEDATA data : [fare:" .. fid .. ":LT:end]", err);
							return
						end
					else
						if limcac == 0 then
							if limlen > 1 then
								for idx = 1, limlen-1 do
									-- ngx.say(limtimesta[idx] .. ":" .. limtimeend[idx]);
									local res, err = red:zadd("fare:" .. fid .. ":LT:sta", tonumber(limtimesta[idx]), idx)
									if not res then
										ngx.say("failed to sort the LIMITEDTIMEINDEX data : [fare:" .. fid .. ":LT:sta]", err);
										return
									end
									local res, err = red:zadd("fare:" .. fid .. ":LT:end", tonumber(limtimeend[idx]), idx)
									if not res then
										ngx.say("failed to sort the LIMITEDTIMEDATA data : [fare:" .. fid .. ":LT:end]", err);
										return
									end
								end
								-- ngx.say(limtimesta[limlen] .. ":" .. limtimeend[limlen]);
								local res, err = red:zadd("fare:" .. fid .. ":LT:sta", tonumber(limtimesta[limlen]), limlen)
								if not res then
									ngx.say("failed to sort the LIMITEDTIMEINDEX data : [fare:" .. fid .. ":LT:sta]", err);
									return
								end
								local res, err = red:zadd("fare:" .. fid .. ":LT:end", tonumber(limtimeend[limlen]), limlen)
								if not res then
									ngx.say("failed to sort the LIMITEDTIMEDATA data : [fare:" .. fid .. ":LT:end]", err);
									return
								end
							else
								local res, err = red:zadd("fare:" .. fid .. ":LT:sta", tonumber(limtimesta[1]), 1)
								if not res then
									ngx.say("failed to sort the LIMITEDTIMEINDEX data : [fare:" .. fid .. ":LT:sta]", err);
									return
								end
								local res, err = red:zadd("fare:" .. fid .. ":LT:end", tonumber(limtimeend[1]), 1)
								if not res then
									ngx.say("failed to sort the LIMITEDTIMEDATA data : [fare:" .. fid .. ":LT:end]", err);
									return
								end
								-- ngx.say(limtimesta[1] .. ":" .. limtimeend[1]);
							end
						end
					end
					-- content.policyId and fid
					local plyres, plyerr = red:sadd("POLICY:" .. content.policyId, fid)
					if not plyres then
						ngx.print(error002("failed to SET POLICY: " .. content.policyId, plyerr));
						return
					end
					-- 20130326
					-- ticketPolicyFiles information.0
					for idx, value in pairs(content.ticketPolicyFiles) do
						local res, err = red:hmset("fare:" .. fid .. ":POLICY:file", idx, value)
						if not res then
							ngx.say("failed to hmset the hashes data : [fare:" .. fid .. ":POLICY:file]", err);
							return
						end
					end
					ngx.print(error000);
				else
					ngx.print(error002("The FARE had already been stored!-[fare:" .. farekey .. ":id: " .. getfidres .. "]"));
				end
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
