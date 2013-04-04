local sock = ngx.socket.tcp()
local ok, err = sock:connect("10.124.20.49", 8161)
if not ok then
	ngx.say("failed to connect to MQ: ", err)
	return
end
ngx.say("successfully connected to MQ!")
local req = "GET /demo/message/rhomobile?type=queue&clientId=ngx136";
local bytes, err = sock:send(req)
if not bytes then
	ngx.say("failed to send request: ", err)
	return
end
ngx.say("request sent: ", bytes)
while true do
	local line, err, part = sock:receive()
	if line then
		ngx.say("received: ", line)
	else
		ngx.say("failed to receive a line: ", err, " [", part, "]")
		break
	end
end
sock:close()
ngx.say("closed")
