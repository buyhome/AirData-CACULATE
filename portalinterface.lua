-- buyhome <huangqi@rhomobi.com> 20130321 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file
-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/114
-- Portal interface
-- load redis library
local redis = require "resty.redis"
-- load cjson library
local JSON = require("cjson");
-- originality
local error001 = JSON.encode({ ["errorcode"] = 001, ["description"] = "NO RESULT"});
local error002 = JSON.encode({ ["errorcode"] = 002, ["description"] = "Your request time is NOT behind yesterday."});
-- Faredata server error Function
function error003(des)
	local res = JSON.encode({ ["errorcode"] = 003, ["description"] = des});
	return res
end
-- Caculate server error Function
function error004(des)
	local res = JSON.encode({ ["errorcode"] = 004, ["description"] = des});
	return res
end
-- Function
function table_is_empty(t)
	return next(t)
end
function cwexchange(d)
	if tonumber(d) ~= nil then
		return d
	else
		if tostring(d) == "A" then
			return "10"
		else
			return "0"
		end
	end
end
-- ready to connect to Faredata server.
local red, err = redis:new()
if not red then
	ngx.say(error003("failed to instantiate Faredata server: ", err))
	return
end
-- Sets the timeout (in ms) protection for subsequent operations, including the connect method.
red:set_timeout(600)
local ok, err = red:connect("127.0.0.1", 6366)
if not ok then
	ngx.say(error003("failed to connect Faredata server: ", err))
	return
end
-- ready to connect to Caculate server.
local csd, csderr = redis:new()
if not csd then
	ngx.say(error004("failed to instantiate Caculate server: ", csderr))
	return
end
-- Sets the timeout (in ms) protection for subsequent operations, including the connect method.
csd:set_timeout(600)
local csdok, csderr = csd:connect("127.0.0.1", 63286)
if not csdok then
	ngx.say(error004("failed to connect Caculate server: ", csderr))
	return
end
if ngx.var.request_method == "GET" then
	ngx.exit(ngx.HTTP_FORBIDDEN);
end
if ngx.var.request_method == "POST" then
	ngx.req.read_body();
	local pcontent = ngx.req.get_body_data();
	if pcontent then
		-- Maybe 1000000 process POST faredata
		local tmprandom = math.random(1,1000000);
		local timestamp = ngx.now();
		local reqdate = os.date("%Y%m%d", timestamp);
		local content = JSON.decode(pcontent);
		ngx.print(content.ORG);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.DST);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.AIRLINE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.DEPARTUREDATE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.PASSENGERTYPE);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.BUNKLEVEL);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.PASSENGERNUMBER);
		ngx.print("\r\n---------------------\r\n");
		ngx.print(content.DIRECT);
		ngx.print("\r\n---------------------\r\n");
		if content.DEPARTUREDATE < tonumber(reqdate) then
			ngx.print(error002);
		else
			-- DEPARTUREDATE to WEEK
			local tyear = tonumber(string.sub(content.DEPARTUREDATE, 1, 4));
			local tmonth = tonumber(string.sub(content.DEPARTUREDATE, 5, 6));
			local tday = tonumber(string.sub(content.DEPARTUREDATE, 7, -1));
			local tweek = os.date("%w", os.time{year=tyear, month=tmonth, day=tday});
			-- Genurate ckey for CACULATION.
			local ckey = ngx.md5(tmprandom .. timestamp .. content.ORG .. content.DST .. content.DEPARTUREDATE);
			-- fare:SELL_START_DATE <= reqdate
			local selsres, selserr = red:zrangebyscore("fare:SELL_START_DATE", "-inf", reqdate)
			if not selsres then
				ngx.say("failed to zrangebyscore the fare:SELL_START_DATE:" .. reqdate, selserr);
				return
			else
				ngx.print(selsres);
				ngx.print("\r\n+++++++++\r\n");
				for skey, svalue in ipairs(selsres) do
					local tmpres, tmperr = red:sadd("CACULATE:" .. ckey .. ":SSTART", svalue)
					if not tmpres then
						ngx.say("failed to SET CACULATE:" .. ckey .. ":SSTART", tmperr);
						return
					end
				end
			end
			-- fare:SELL_END_DATE >= reqdate
			local selsres, selserr = red:zrangebyscore("fare:SELL_END_DATE", reqdate, "+inf")
			if not selsres then
				ngx.say("failed to zrangebyscore the fare:SELL_END_DATE:" .. reqdate, selserr);
				return
			else
				ngx.print(selsres);
				ngx.print("\r\n---------------------\r\n");
				for skey, svalue in ipairs(selsres) do
					local tmpres, tmperr = red:sadd("CACULATE:" .. ckey .. ":SEND", svalue)
					if not tmpres then
						ngx.say("failed to SET CACULATE:" .. ckey .. ":SEND", tmperr);
						return
					end
				end
			end
			-- fare:MIN_TRAVELER_COUNT <= PASSENGERNUMBER
			local mtcres, mtcerr = red:zrangebyscore("fare:MIN_TRAVELER_COUNT", "-inf", content.PASSENGERNUMBER)
			if not mtcres then
				ngx.say("failed to zrangebyscore the fare:MIN_TRAVELER_COUNT:" .. content.PASSENGERNUMBER, mtcerr);
				return
			else
				ngx.print(mtcres);
				ngx.print("\r\n+++++++++\r\n");
				for mkey, mvalue in ipairs(mtcres) do
					-- MTC = MIN_TRAVELER_COUNT
					local tmpres, tmperr = red:sadd("CACULATE:" .. ckey .. ":MTC", mvalue)
					if not tmpres then
						ngx.say("failed to SET CACULATE:" .. ckey .. ":MTC", tmperr);
						return
					end
				end
			end
			-- PERIODS:START <= DEPARTUREDATE
			local stares, staerr = red:zrangebyscore("PERIODS:START", "-inf", content.DEPARTUREDATE)
			if not stares then
				ngx.say("failed to zrangebyscore the PERIODS:START:" .. content.DEPARTUREDATE, staerr);
				return
			else
				-- local hashstares = red:array_to_hash(stares);//FAILED TO PRINT
				ngx.print(stares);
				ngx.print("\r\n+++++++++\r\n");
				for wkey, wvalue in ipairs(stares) do
					local tmpres, tmperr = red:sadd("CACULATE:" .. ckey .. ":PSTART", wvalue)
					if not tmpres then
						ngx.say("failed to SET CACULATE:" .. ckey .. ":PSTART", tmperr);
						return
					end
				end
			end
			-- PERIODS:END >= DEPARTUREDATE
			local endres, enderr = red:zrangebyscore("PERIODS:END", content.DEPARTUREDATE, "+inf")
			if not endres then
				ngx.say("failed to zrangebyscore the PERIODS:END:" .. content.DEPARTUREDATE, enderr);
				return
			else
				ngx.print(endres);
				ngx.print("\r\n+++++++++\r\n");
				for wkey, wvalue in ipairs(endres) do
					local tmpres, tmperr = red:sadd("CACULATE:" .. ckey .. ":PEND", wvalue)
					if not tmpres then
						ngx.say("failed to SET CACULATE:" .. ckey .. ":PEND", tmperr);
						return
					end
				end
			end
			-- CACULATE Psinter...
			local sinterstoreres, sinterstoreerr = red:sinterstore("CACULATE:" .. ckey .. ":Psinter", "CACULATE:" .. ckey .. ":PEND", "CACULATE:" .. ckey .. ":PSTART")
			if not sinterstoreres then
				ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":Psinter", sinterstoreerr);
				return
			else
				-- CACULATE sdiffstore...
				local sdiffstoreres, sdiffstoreerr = red:sdiffstore("CACULATE:" .. ckey .. ":diffFAIR", "CACULATE:" .. ckey .. ":Psinter", "PERIODS:" .. tweek)
				if not sdiffstoreres then
					ngx.say("failed to sdiffstore CACULATE:" .. ckey .. ":diffFAIR", sdiffstoreerr);
					return
				else
					-- ngx.print(sdiffstoreres);//number of members
					ngx.print("\r\n++++diffFAIROK++++\r\n");
					-- Get the fid base the FAREID.
					local smemres, smemerr = red:smembers("CACULATE:" .. ckey .. ":diffFAIR")
					if not smemres then
						ngx.say("failed to smembers CACULATE:" .. ckey .. ":diffFAIR", smemerr);
						return
					else
						-- following Check if the pairs can be treated as a table
						for k, v in pairs(smemres) do
							local farehkey = string.sub(string.format("%011d", v), 1, 8);
							local res, err = red:hget("PERIODS:fid:" .. farehkey, v)
							if not res then
								ngx.say("failed to HGET PERIODS:fid: " .. farehkey, err);
								return
							else
								local resc, errc = red:sadd("CACULATE:" .. ckey .. ":PERIODS", res)
								if not resc then
									ngx.say("failed to SET CACULATE:" .. ckey .. ":PERIODS", errc);
									return
								end
							end
						end
					end
				end
			end
			-- Check content.AIRLINE if it is null
			if content.AIRLINE ~= JSON.null then
				local cavhcmd = string.upper(content.ORG .. content.DST .. content.AIRLINE);
				local city = string.upper(content.ORG .. content.DST);
				local fareresult = "";
				-- SINTER key [key ...]
				if content.DIRECT == 1 then
					ngx.print("\r\n----------content.DIRECT is 1 == all-----------\r\n");
					if content.BUNKLEVEL == JSON.null then
						ngx.print("\r\n----------content.BUNKLEVEL is not needed-----------\r\n");
						local sinterok, sintererr = red:sinter("AVHCMD:" .. cavhcmd, "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					else
						ngx.print("\r\n----------content.BUNKLEVEL is needed-----------\r\n");
						local sinterok, sintererr = red:sinter("AVHCMD:" .. cavhcmd, "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "ORGDST:" .. city .. ":BUNKLEVEL:" .. content.BUNKLEVEL, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					end
				else
					ngx.print("\r\n----------content.DIRECT is 0 == DIRECT-----------\r\n");
					if content.BUNKLEVEL == JSON.null then
						ngx.print("\r\n----------content.BUNKLEVEL is not needed-----------\r\n");
						local sinterok, sintererr = red:sinter("AVHCMD:" .. cavhcmd, "ORGDST:" .. city .. ":S_NUMBER:1", "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					else
						ngx.print("\r\n----------content.BUNKLEVEL is needed-----------\r\n");
						local sinterok, sintererr = red:sinter("AVHCMD:" .. cavhcmd, "ORGDST:" .. city .. ":S_NUMBER:1", "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "ORGDST:" .. city .. ":BUNKLEVEL:" .. content.BUNKLEVEL, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					end
				end
				-- Check the RESULT of sinterok
				-- ngx.say(table_is_empty(fareresult))
				-- if fareresult == "" then
				if table_is_empty(fareresult) == nil then
					-- NO RESULT echo before delete the ckey's data
					ngx.print(error001);
					-- delete CACULATE's data
					local mkeyres, mkeyerr = red:keys("*" .. ckey .. "*")
					if not mkeyres then
						ngx.say("failed to keys *:" .. ckey .. "*", mkeyerr);
						return
					else
						ngx.print(mkeyres);
						ngx.print("\r\n---------------------\r\n");
						-- DEL CACULATE cKEYS.
						for k, v in pairs(mkeyres) do
							local dkeyres, dkeyerr = red:del(v)
							if not dkeyres then
								ngx.say("failed to del *:" .. ckey .. "*", dkeyerr);
								return
							end
							ngx.print(dkeyres);
							ngx.print("\r\n----------DELOK-----------\r\n");
						end
					end
				else
					-- foreach fid to start pharsing the result fid
					for k, v in pairs(fareresult) do
						-- Init the tmpfres for ready to insert CARRIERS of every SEGMENTS and BASE_AIRLINE&CITY_PATH
						-- tmpfres means the temp fare res
						local tmpfres = {}
						-- Get the fid's S_NUMBER
						local resnum, errnum = red:get("fare:" .. v .. ":S_NUMBER")
						if not resnum then
							ngx.say("failed to get the :" .. v .. "'s S_NUMBER", errnum);
							return
						else
							-- ngx.say(resnum);
							local segid = 1;
							-- foreach hashes fare:$fid:SEGMENTS:$segid
							while segid <= tonumber(resnum) do
								-- Get the hashes data of the keys == fare:1:SEGMENTS:1
								local res, err = red:hget("fare:" .. v .. ":SEGMENTS:" .. segid, "CARRIER")
								if not res then
									ngx.say("failed to HGET SEGMENTS:CARRIER's fid is:" .. v, err);
									return
								else
									-- ngx.say(res);
									table.insert(tmpfres, { string.upper(res) })
									segid = segid + 1;
								end
							end
							-- CITY_PATH==airport_path
							local res, err = red:get("fare:" .. v .. ":CITY_PATH")
							if not res then
								ngx.say("failed to get the :" .. v .. "'s CITY_PATH", err);
								return
							else
								-- ngx.say(res);
								table.insert(tmpfres, { string.upper(content.AIRLINE) })
								table.insert(tmpfres, { string.upper(res) })
								ngx.say(tmpfres);
								-- ngx.say(ckey);
								-- ngx.say(ngx.md5(JSON.encode(tmpfres)));
								-- ngx.print(ngx.md5(ckey .. "_" .. JSON.encode(tmpfres)));
								-- ngx.print("\r\n----------ready togo-----------\r\n");
								local md5fres = ngx.md5(JSON.encode(tmpfres));
								-- change the fresmd5 NOT encode_base64.
								local fresmd5 = ngx.md5(ckey .. "_" .. md5fres);
								local fresid = "";
								-- Get the ID of the fresmd5
								local getfidres, getfiderr = csd:get("fres:" .. fresmd5 .. ":id")
								if not getfidres then
									ngx.say("failed to get " .. "fres:" .. fresmd5 .. ":id: ", getfiderr)
									return
								else
									-- Get failure
									if tonumber(getfidres) == nil then
										-- fres:id INCR fresid
										local frescount, ferror = csd:incr("fres:id")
										if not frescount then
											ngx.say("failed to INCR fres: ", ferror);
											return
										else
											ngx.say("INCR fres result: ", frescount);
											ngx.print("\r\n---------------------\r\n");
											local resultsetnx, fiderror = csd:setnx("fres:" .. fresmd5 .. ":id", frescount)
											if not resultsetnx then
												ngx.say("failed to SETNX fresid: ", fiderror);
												return
											else
												ngx.say("SETNX fresid result: ", resultsetnx);
												ngx.print("\r\n---------------------\r\n");
												-- if resultsetnx ~= 1 that is SETNX is NOT sucess.
												if resultsetnx == 1 then
													fresid = frescount;
												else
													fresid = csd:get("fres:" .. fresmd5 .. ":id");
												end
												-- Get the fid = fare:[farekey]:id
											end
										end
									else
									-- Get sucess
										ngx.print("The fres had already been stored!");
										ngx.print("\r\n---------------------\r\n");
										ngx.print("fres:" .. fresmd5 .. ":id: ", getfidres);
										ngx.print("\r\n---------------------\r\n");
										fresid = tonumber(getfidres);
									end
									ngx.print("The real fres.id is : ", fresid);
									ngx.print("\r\n---------------------\r\n");
									local res, err = csd:set("fres:" .. fresid .. ":fresmd5", fresmd5)
									if not res then
										ngx.say(error004("failed to set the data : [fres:" .. fresid .. ":fresmd5]", err));
										return
									end
									--[[
									-- fare result contain several fids that it's s_number is NOT important
									local res, err = csd:set("fres:" .. fresid .. ":s_number", resnum)
									if not res then
										ngx.say(error004("failed to set the data : [fres:" .. fresid .. ":s_number]", err));
										return
									end
									--]]
									local tmpBUNK = {}
									-- ngx.say(resnum);
									local segbunk = 1;
									-- foreach hashes fare:$fid:SEGMENTS:$BUNK
									while segbunk <= tonumber(resnum) do
										-- Get the hashes data of the keys == fare:1:SEGMENTS:1
										local res, err = red:hget("fare:" .. v .. ":SEGMENTS:" .. segbunk, "BUNK")
										if not res then
											ngx.say("failed to HGET SEGMENTS:BUNK's fid is:" .. v, err);
											return
										else
											table.insert(tmpBUNK, { res })
											segbunk = segbunk + 1;
										end
									end
									ngx.print(JSON.encode(tmpBUNK));
									ngx.print("\r\n-----------tmpBUNK----------\r\n");
									local res, err = csd:hset("fres:" .. fresid .. ":fid", v, JSON.encode(tmpBUNK))
									if not res then
										ngx.say(error004("failed to hset the hashes data : [fres:" .. fresid .. ":fid" .. "_" .. v .."]", err));
										return
									end
									local res, err = csd:sadd("cac:" .. ckey .. ":freskey", md5fres)
									if not res then
										ngx.say(error004("failed to set the cac:" .. ckey .. ":freskey[" .. md5fres .. "]", err));
										return
									end
								end
							end
						end
					end
					-- transparent non-blocking I/O in Lua via subrequests.
					-- string.lower @20130308
					local res = ngx.location.capture("/data-avh/" .. string.lower(content.ORG) .. "/" .. string.lower(content.DST) .. "/" .. string.lower(content.AIRLINE) .. "/" .. content.DEPARTUREDATE .. "/");
					ngx.say(res.status);
					-- ngx.say(fresid);
					if res.status == 200 then
						ngx.print("\r\n+++++fresid++++\r\n");
						-- ngx.say(res.body);
						local avcontent = JSON.decode(res.body);
						ngx.print(avcontent.org);
						ngx.print("\r\n---------------------\r\n");
						ngx.print(avcontent.dst);
						ngx.print("\r\n---------------------\r\n");
						ngx.print(avcontent.itemsCount);
						ngx.print("\r\n---------------------\r\n");
						-- avItems information.
						local itemcount = 1;
						for idx, value in ipairs(avcontent.avItems) do
							-- ngx.print(value.s_number);
							-- ngx.print("\r\n+++++++++\r\n");
							local scount = 1;
							-- tmpavhres means the temp avh res
							local tmpavhres = {};
							local airportpath = "";
							local airport1 = "";
							local airport2 = "";
							for key, value1 in ipairs(value.segments) do
								if value1.carrier == JSON.null then
									table.insert(tmpavhres, { string.upper(content.AIRLINE) })
								else
									table.insert(tmpavhres, { string.sub(string.upper(value1.carrier), 1, 2) })
								end
								if airport2 == value1.orgcity then
									airport1 = "";
								else
									if scount == 1 then
										airport1 = value1.orgcity;
									else
										-- dstcity is null
										airport1 = "//" .. value1.orgcity;
									end
								end
								airport2 = value1.dstcity;
								for skey, value2 in pairs(value1) do
									if ( skey ~= "cangwei_index" and skey ~= "cangwei_data" and skey ~= "cangwei_subclass_index" and skey ~= "cangwei_subclass_data" and skey ~= "selectedClass" and skey ~= "class" and skey ~= "cangwei_index_sort" and skey ~= "cangwei_data_sort" ) then
										-- ngx.print("(fres:" .. itemcount .. ":segments:" .. scount .. ") -- " .. skey, ":", value2);
										-- ngx.print("\r\n---------------------\r\n");
										local val = "";
										-- exchange the null value2 to ""
										if value2 ~= JSON.null then
											val = value2;
										end
										local res, err = csd:hset("avh:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":seg", skey, val)
										if not res then
											ngx.say(error004("failed to hset the hashes data:[avhs:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":seg]", err));
											return
										end
									end
									--[[
									-- if ( skey == "cangwei_index" and skey == "cangwei_data" ) then
									if skey == "cangwei_index" then
										for kc, vc in pairs(value2) do
											ngx.print(kc, vc);
											ngx.print("\r\n----------cangwei_index-----------\r\n");
										end
										ngx.print(value2[1]);
										ngx.print("\r\n----------cangwei_index-----------\r\n");
									end
									--]]
								end
								-- ngx.say("+++++++++++++++++++++++");
								-- ngx.say("avh:" .. ckey .. ":" .. itemcount .. ":segid:" .. scount, value1.cangwei_data[1], value1.cangwei_index[1]);
								local cwindexs = table.getn(value1.cangwei_index);
								local cwindexi = 1;
								while cwindexi <= cwindexs do
									-- ngx.say("avh:" .. ckey .. ":" .. itemcount .. ":segid:" .. scount, value1.cangwei_data[cwindexi], value1.cangwei_index[cwindexi]);
									-- sort cangwei_index by cangwei_data
									local cangweiscore = tonumber(cwexchange(value1.cangwei_data[cwindexi]));
									-- ngx.say(cangweiscore);
									if cangweiscore ~= 0 then
									-- close the Check of cangweiscore 0
										local cwres, cwerr = csd:zadd("avh:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":cw", cangweiscore, value1.cangwei_index[cwindexi])
										if not cwres then
											ngx.say("failed to zadd the cangwei sortdatas:[avhs:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":cw]", cwerr);
											return
										--[[
										-- Not do following code by cangweiscore
										else
											-- with the fare Oracle dataset is biger more so all of avhids will be used for next caculation.
											-- but it'll use much more memory, I suppose to caculate data-avh before Portal.lua in the further development
											-- cangwei_data >= 1
											local kcwres, kcwerr = csd:zrangebyscore("avh:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":cw", 1, "+inf")
											if not kcwres then
												ngx.say("failed to get the available cangwei_index", kcwerr);
												return
											else
												-- ngx.print(kcwres);
												-- ngx.print("\r\n---------------------\r\n");
												for kcw, vcw in ipairs(kcwres) do
													local res, err = csd:sadd("avh:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":kcw", vcw)
													if not res then
														ngx.say("failed to SET avh:" .. ckey .. ":" .. itemcount .. ":" .. scount .. ":kcw", err);
														return
													end
												end
											end
										--]]
										end
									end
									cwindexi = cwindexi + 1;
								end
								airportpath = airportpath .. airport1 .. "-" .. airport2;
								local res, err = csd:set("avh:" .. ckey .. ":" .. itemcount .. ":s_number", scount)
								if not res then
									ngx.say(error004("failed to hset the s_number data : [avhs:" .. ckey .. ":" .. itemcount .. ":s_number]", err));
									return
								else
									scount = scount + 1;
								end
								-- ngx.print(scount);
								-- ngx.print("\r\n++++scount+++++\r\n");
							end
							-- ngx.say(airportpath);
							-- ngx.say(string.len(airportpath));
							table.insert(tmpavhres, { string.upper(content.AIRLINE) })
							table.insert(tmpavhres, { string.upper(airportpath) })
							-- ngx.say(tmpavhres);
							-- ngx.say(itemcount);
							-- avh result caculate for avhkey.
							local res, err = csd:sadd("cac:" .. ckey .. ":" .. ngx.md5(JSON.encode(tmpavhres)) .. ":avhid", itemcount)
							if not res then
								ngx.say(error004("failed to set the data : [cac:" .. ckey .. ":" .. ngx.md5(JSON.encode(tmpavhres)) .. ":avhid]", err));
								return
							else
								-- store the avhkey.
								local res, err = csd:sadd("cac:" .. ckey .. ":avhkey", ngx.md5(JSON.encode(tmpavhres)))
								if not res then
									ngx.say(error004("failed to set the cac:" .. ckey .. ":avhkey[" .. ngx.md5(JSON.encode(tmpavhres)) .. "]", err));
									return
								end
							end
							itemcount = itemcount + 1;
							-- ngx.print(itemcount);
							-- ngx.print("\r\n++++itemcount+++++\r\n");
						end
						-- CACULATE sinter the freskey[] and avhkey[]...
						local keyres, keyerr = csd:sinter("cac:" .. ckey .. ":avhkey", "cac:" .. ckey .. ":freskey")
						if not keyres then
							ngx.say("failed to sinter cac:" .. ckey .. ":avhkey&freskey", keyerr);
							return
						else
							if table_is_empty(keyres) == nil then
								-- NO RESULT echo before delete the ckey's data
								ngx.print(error001);
							else
								-- ngx.print(keyres);
								-- ngx.print("\r\n++++sintercacOK++++\r\n");
								-- foreach fid to start pharsing the result fid
								for k, v in pairs(keyres) do
									local smemres, smemerr = csd:smembers("cac:" .. ckey .. ":" .. v .. ":avhid")
									if not smemres then
										ngx.say("failed to smembers cac:" .. ckey .. v .. ":avhid", smemerr);
										return
									else
										-- foreach avhid
										for fk, fv in pairs(smemres) do
											-- ngx.print(fv);
											-- ngx.print("\r\n++++avhid++++\r\n");
											local res, err = csd:get("fres:" .. ngx.md5(ckey .. "_" .. v) .. ":id")
											if not res then
												ngx.say("failed to get fres:" .. ngx.md5(ckey .. "_" .. v) .. ":id", err);
												return
											else
												local fid, frr = csd:hvals("fres:" .. res .. ":fid")
												if not fid then
													ngx.say("failed to hvals fres:" .. res .. ":fid", frr);
													return
												else
													local fididxs = table.getn(fid);
													local fididxi = 1;
													while fididxi <= fididxs do
														local bunktable = JSON.decode(fid[fididxi]);
														local bunkidxs = table.getn(bunktable);
														local bunkidxi = 1;
														local rm = true;
														while bunkidxi <= bunkidxs do
															-- ngx.print(bunktable[bunkidxi][1]);
															-- ngx.print("\r\n++++cangwei_index++++\r\n");
															local tmpscore = "";
															local cwscore, cwerrs = csd:zscore("avh:" .. ckey .. ":" .. fv .. ":" .. bunkidxi .. ":cw", bunktable[bunkidxi][1])
															if not cwscore then
																ngx.say("failed to zscore the cangwei sortdatas:[avh:" .. ckey .. ":" .. fv .. ":" .. bunkidxi .. ":cw]", cwerrs);
																return
															else
																-- ngx.say(cwscore);
																if tonumber(cwscore) == nil then
																	tmpscore = 0;
																	rm = false;
																else
																	tmpscore = tonumber(cwscore);
																end
																local r, e = csd:zadd("cac:" .. ckey .. ":res:" .. fv .. ":" .. fididxi .. ":cw", tmpscore, bunktable[bunkidxi][1])
																if not r then
																	ngx.say("failed to zadd the cangwei sortdatas:[cac:" .. ckey .. ":res:" .. fv .. ":" .. fididxi .. ":cw]", e);
																	return
																end
															end
															bunkidxi = bunkidxi + 1;
														end
														-- echo the cac:res
														if rm == false then
															ngx.print("cac:" .. ckey .. ":res:" .. fv .. ":" .. fididxi .. ":cw");
															ngx.print("\r\n----------ready to rm-----------\r\n");
														end
														fididxi = fididxi + 1;
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			else
				ngx.print("\r\n----------content.AIRLINE is null-----------\r\n");
				local city = content.ORG .. content.DST;
				-- SINTER key [key ...]
				if content.DIRECT == 1 then
					ngx.print("\r\n----------content.DIRECT is 1 == all-----------\r\n");
					if content.BUNKLEVEL == JSON.null then
						ngx.print("\r\n----------content.BUNKLEVEL is not needed-----------\r\n");
						local sinterok, sintererr = red:sinter("ORGDST:" .. city .. ":FID", "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					else
						ngx.print("\r\n----------content.BUNKLEVEL is needed-----------\r\n");
						local sinterok, sintererr = red:sinter("ORGDST:" .. city .. ":FID", "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "ORGDST:" .. city .. ":BUNKLEVEL:" .. content.BUNKLEVEL, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					end
				else
					ngx.print("\r\n----------content.DIRECT is 0 == DIRECT-----------\r\n");
					if content.BUNKLEVEL == JSON.null then
						ngx.print("\r\n----------content.BUNKLEVEL is not needed-----------\r\n");
						local sinterok, sintererr = red:sinter("ORGDST:" .. city .. ":FID", "ORGDST:" .. city .. ":S_NUMBER:1", "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					else
						ngx.print("\r\n----------content.BUNKLEVEL is needed-----------\r\n");
						local sinterok, sintererr = red:sinter("ORGDST:" .. city .. ":FID", "ORGDST:" .. city .. ":S_NUMBER:1", "ORGDST:" .. city .. ":TRAVELER:" .. content.PASSENGERTYPE, "ORGDST:" .. city .. ":BUNKLEVEL:" .. content.BUNKLEVEL, "CACULATE:" .. ckey .. ":PERIODS", "CACULATE:" .. ckey .. ":SEND", "CACULATE:" .. ckey .. ":SSTART", "CACULATE:" .. ckey .. ":MTC")
						if not sinterok then
							ngx.say("failed to sinterstore CACULATE:" .. ckey .. ":sinter", sintererr);
							return
						else
							fareresult = sinterok;
							ngx.print(JSON.encode(sinterok));
							ngx.print("\r\n---------echo sinterOK------------\r\n");
						end
					end
				end
				-- Check the RESULT of sinterok
				-- ngx.say(table_is_empty(fareresult))
				-- if fareresult == "" then
				if table_is_empty(fareresult) == nil then
					-- NO RESULT echo before delete the ckey's data
					ngx.print(error001);
					-- delete CACULATE's data
					local mkeyres, mkeyerr = red:keys("*" .. ckey .. "*")
					if not mkeyres then
						ngx.say("failed to keys *:" .. ckey .. "*", mkeyerr);
						return
					else
						ngx.print(mkeyres);
						ngx.print("\r\n---------------------\r\n");
						-- DEL CACULATE cKEYS.
						for k, v in pairs(mkeyres) do
							local dkeyres, dkeyerr = red:del(v)
							if not dkeyres then
								ngx.say("failed to del *:" .. ckey .. "*", dkeyerr);
								return
							end
							ngx.print(dkeyres);
							ngx.print("\r\n----------DELOK-----------\r\n");
						end
					end
				else
					-- construct the requests table
					local reqs = {}
					-- foreach fid
					for k, v in pairs(fareresult) do
						local res, err = red:get("fare:" .. v .. ":AVHCMD")
						if not res then
							ngx.say("failed to get the :" .. v .. "'s AVHCMD", err);
							return
						end
						-- ngx.say(res);
						table.insert(reqs, { "/data-avh/" .. string.lower(res) .. content.DEPARTUREDATE .. "/" })
						ngx.say(reqs);
					end
					-- issue all the requests at once and wait until they all return
					local resps = { ngx.location.capture_multi(reqs) }
					-- loop over the responses table
					for i, resp in ipairs(resps) do
						-- process the response table "resp"
						-- ngx.say(resp.status)
						-- ngx.say(resp.body)
						if resp.status == 200 then
							ngx.print("\r\n+++++++++\r\n");
							-- ngx.print(resp.body);
							local avcontent = JSON.decode(resp.body);
							ngx.print(avcontent.org);
							ngx.print("\r\n---------------------\r\n");
							ngx.print(avcontent.dst);
							ngx.print("\r\n---------------------\r\n");
							ngx.print(avcontent.itemsCount);
							ngx.print("\r\n---------------------\r\n");
							-- avItems information.
							local itemcount = 1;
							for idx, value in ipairs(avcontent.avItems) do
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
					end
				end
			end
		end
	end
	-- put it into the connection pool of size 512,
	-- with 0 idle timeout
	local ok, err = red:set_keepalive(0, 512)
	if not ok then
		ngx.say("failed to set keepalive with Faredata server: ", err)
		return
	end
	local ok, err = csd:set_keepalive(0, 512)
	if not ok then
		ngx.say("failed to set keepalive with Caculate server: ", err)
		return
	end
	-- or just close the connection right away:
	-- local ok, err = red:close()
	-- if not ok then
		-- ngx.say("failed to close: ", err)
		-- return
	-- end
end
