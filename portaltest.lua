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
function cacflt(ckey, fidi, fidj, fv)
	local krs, ker = red:exists("fare:" .. fidi .. ":FLIGHT:0")
	if not krs then
		ngx.say(error003("failed to EXISTS fare:" .. fidi .. ":FLIGHT:0", ker));
	else
		if krs == 0 then
			-- ALLOW_FLIGHT is NOT exist
			local fltres, flterr = red:sinter("fare:" .. fidi .. ":FLIGHT:1", "CACULATE:" .. ckey .. ":" .. fv .. ":flt")
			if not fltres then
				ngx.say(error003("failed to sinter fare:" .. fidi .. ":FLIGHT:1 with & CACULATE:" .. ckey .. ":" .. fv .. ":flt", flterr));
				return
			else
				if table_is_empty(fltres) == nil then
					local bunktable = JSON.decode(fidj);
					local bunkidxs = table.getn(bunktable);
					local bunkidxi = 1;
					local rm = true;
					while bunkidxi <= bunkidxs do
						local tmpscore = "";
						local cwscore, cwerrs = csd:zscore("avh:" .. ckey .. ":" .. fv .. ":" .. bunkidxi .. ":cw", bunktable[bunkidxi][1])
						if not cwscore then
							ngx.say(error004("failed to zscore the cangwei sortdatas:[avh:" .. ckey .. ":" .. fv .. ":" .. bunkidxi .. ":cw]", cwerrs));
							return
						else
							-- ngx.say(cwscore);
							if tonumber(cwscore) == nil then
								tmpscore = 0;
								rm = false;
							else
								tmpscore = tonumber(cwscore);
							end
							local r, e = csd:zadd("cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw", tmpscore, bunkidxi .. bunktable[bunkidxi][1])
							if not r then
								ngx.say(error004("failed to zadd the cangwei sortdatas:[cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw]", e));
								return
							end
						end
						bunkidxi = bunkidxi + 1;
					end
					-- echo the cac:res
					if rm == false then
						local dr, de = csd:del("cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw")
						if not dr then
							ngx.say(error004("failed to del cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw", de));
							return
						end
					end
				end
			end
		else
			-- ALLOW_FLIGHT is exist, used for CACULATE:avhid:flt - which
			local fltres, flterr = red:sdiff("CACULATE:" .. ckey .. ":" .. fv .. ":flt", "fare:" .. fidi .. ":FLIGHT:0")
			if not fltres then
				ngx.say(error003("failed to SDIFF fare:" .. fidi .. ":FLIGHT:0 with & CACULATE:" .. ckey .. ":" .. fv .. ":flt", flterr));
				return
			else
				if table_is_empty(fltres) == nil then
					local bunktable = JSON.decode(fidj);
					local bunkidxs = table.getn(bunktable);
					local bunkidxi = 1;
					local rm = true;
					while bunkidxi <= bunkidxs do
						local tmpscore = "";
						local cwscore, cwerrs = csd:zscore("avh:" .. ckey .. ":" .. fv .. ":" .. bunkidxi .. ":cw", bunktable[bunkidxi][1])
						if not cwscore then
							ngx.say(error004("failed to zscore the cangwei sortdatas:[avh:" .. ckey .. ":" .. fv .. ":" .. bunkidxi .. ":cw]", cwerrs));
							return
						else
							-- ngx.say(cwscore);
							if tonumber(cwscore) == nil then
								tmpscore = 0;
								rm = false;
							else
								tmpscore = tonumber(cwscore);
							end
							local r, e = csd:zadd("cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw", tmpscore, bunkidxi .. bunktable[bunkidxi][1])
							if not r then
								ngx.say(error004("failed to zadd the cangwei sortdatas:[cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw]", e));
								return
							end
						end
						bunkidxi = bunkidxi + 1;
					end
					-- echo the cac:res
					if rm == false then
						local dr, de = csd:del("cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw")
						if not dr then
							ngx.say(error004("failed to del cac:" .. ckey .. ":res:" .. fv .. ":" .. fidi .. ":cw", de));
							return
						end
					end
				end
			end
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
		ngx.say(pcontent);
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
