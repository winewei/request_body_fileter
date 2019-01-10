function str_decode_base64(_str)
        if _str == nil or _str == "" then
                return
        end
        local s_str = _str
        local s_len = string.len(s_str) % 4
        local s_re = string.gsub(s_str,"-_","+/")
        local s_add_right = string.rep("=",s_len)
        return ngx.decode_base64(s_re..s_add_right)
end

local req = require "req"
local args = req.getArgs()
local s_token
local s_roomid
if type(args["token"]) == "table" then
        s_token = args["token"][1]
else
        s_token = args["token"]
end
if type(args["roomnum"]) == "table" then
        s_roomid= args["roomnum"][1]
else
        s_roomid= args["roomnum"]
end

ngx.log(ngx.ALERT, "api: ",ngx.var.request_uri," ---> token: ",s_token," ---> decode_token: ",str_decode_base64(s_token)," ----> roomnum: ",s_roomid)
