--根据实际情况配置redis驱动
package.path = "/usr/local/openresty/lualib/resty/redis.lua;"

--配置ip请求频率阀值，锁定时间
local ip_block_ttl = 20 
local ip_freq_limit = 80 
local ip_uri_block_ttl = 20
local ip_uri_freq_limit = 30

local function close_redis(red)
    if not red then
        return
    end
    local pool_max_idle_time = 10000
    local pool_size = 100
    local ok, err = red:set_keepalive(pool_max_idle_time, pool_size)

    if not ok then
        ngx_log(ngx_ERR, "set redis keepalive error : ", err)
    end
end

--测试redis连接
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(1000)
local ip = "127.0.0.1"
local port = "6379"
local ok, err = red:connect(ip,port)
--如果redis 连接失败，直接放行请求
if not ok then
   ngx.exit(ngx.OK)
end
--如果认证失败，直接放行请求
local password = "123456"
local auth_flg, err = red:auth(password)
if not auth_flg then
   ngx.exit(ngx.OK)
end

-- 获取客户端IP
local remote_ip = ngx.req.get_headers()["X-Real-IP"]
if remote_ip == nil then
   remote_ip = ngx.req.get_headers()["x_forwarded_for"]
end
if remote_ip == nil then
   remote_ip = ngx.var.remote_addr
end

--把ip, 用户、手机号写入到redis
local ip_incr = "ip:remote:filter:"..remote_ip..":freq"
local ip_block = "ip:remote:filter:"..remote_ip..":block"
local ip_uri_incr = "ip:remote:filter:"..remote_ip..ngx.var.request_uri..":freq" 
local ip_uri_block = "ip:remote:filter:"..remote_ip..ngx.var.request_uri..":block" 
local ip_count = "ip:remote:count:hash"
local ip_uri_count = "ip:remote:uri_count:hash"
--判断IP是否在黑名单中，如果在，则拒绝访问
local is_ip_block,err = red:get(ip_block)
if (tonumber(is_ip_block) == 1 ) then
   o, err = red:HINCRBY(ip_count, remote_ip, 1)
   ngx.exit(444)
   return close_redis(red)
end
--判断IP+ 接口是否在黑名单中，如果在，则拒绝访问
local is_ip_uri_block,err = red:get(ip_uri_block)
if (tonumber(is_ip_uri_block) == 1 ) then
   o, err = red:HINCRBY(ip_uri_count, remote_ip .. ngx.var.request_uri, 1)
   ngx.exit(444)
   return close_redis(red)
end

--
----逻辑实现----
--
-- 每秒初始化 IP 超时时间 为1 秒
res, err = red:incr(ip_incr)
if res == 1 then
    res, err = red:expire(ip_incr,1)
end
--限制IP+接口每秒讲求频率，设置黑名单时间
if res > tonumber(ip_uri_freq_limit) then
    res, err = red:set(ip_uri_block,1)
    res, err = red:expire(ip_uri_block,tonumber(ip_uri_block_ttl))
end

-- 每秒初始化 IP+接口 超时时间 为1 秒
res, err = red:incr(ip_uri_incr)
if res == 1 then
    res, err = red:expire(ip_uri_incr,1)
end
--限制 IP+接口 每秒讲求频率，设置黑名单时间
if res > tonumber(ip_uri_freq_limit) then
    res, err = red:set(ip_uri_block,1)
    res, err = red:expire(ip_uri_block,tonumber(ip_uri_block_ttl))
end

close_redis(red)
