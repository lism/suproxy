local cjson=require("cjson")
local logger=require("suproxy.utils.compatibleLog")
---------------required method for implements----------------------
-- options {ip=ip,port=port,sock=sock,timeout=timeout,expire=expire,extend=true}
function _M.new(self,options)
	local o=setmetatable({},{__index=self})
    local red = redis:new()
    local ip=options.ip or "127.0.0.1"
    local port=options.port or 6379
	local timeout=options.timeout or 5000
	o.expire=options.expire or 3600
	o.extend=(options.extend==nil) and true or options.extend
	local sock=options.sock
    red:set_timeout(timeout)
    local ok, err
	if sock then
		ok,err=red:connect("unix:/path/to/redis.sock")
	else
		ok, err = red:connect(ip, port)
	end
    if not ok then
        logger.log(logger.ERR,"failed to connect: ", err)
        return
    end
    o.redis=red
	return o
end
	local k=getKey(session.sid)
    local ok,err=sessions:set(k,cjson.encode(session))
	if ok and self.expire>=0 then ok,err=sessions:expire(k,self.expire) end
end
	local args={...}
	assert(#args%2==0,"key value count should be even")
	local s=self:get(sid)
	local result=0
	for i=1,#args,2 do
		if ok then
			result=result+1
		else
			logger.log(logger.ERR,"failed to update ", args[i]," to" ,args[i+1]," with error message: ",err)
		end
	return result,err
	local k=getKey(sid)
	if ok then 
		if self.extend then ok,err=sessions:expire(k,self.expire) 
		elseif(self.expire>=0) then
			local currentTime=ngx.time()
			local createTime=session.ctime
			local elapsedTime=currentTime-createTime
			ok,err=sessions:expire(k,self.expire-elapsedTime)
			if not ok then sessions:expire(k,0) end
		end
	end

function _M:get(sid)
    local sessions=self.redis--ngx.shared.sessions
    local result,err=sessions:get(getKey(sid))
    if err or not result or result==ngx.null then
        return nil,err
    end
    return cjson.decode(result),nil
end

function _M:kill(sid)
    local sessions=self.redis--ngx.shared.sessions
    return sessions:del(getKey(sid))
end
---------------------manage method-----------------------
function _M:getSessionOfUser(uid)
    assert(uid,"uid can not be null")
    local sessions=self.redis--ngx.shared.sessions
    local keys,err=sessions:keys("gateway_session_*")--sessions:get_keys()
    if err then return nil,err end
    local result={}
    for i=1,#keys,1 do
        if cjson.decode(sessions:get(keys[i])).ctx.uid==uid then
            result[keys[i]]=sessions:get(keys[i])
        end
    end
    return result,nil
end

function _M:killSessionOfUser(uid)
    local keys,err=sessions:keys("gateway_session_*")--sessions:get_keys()
    local result=0
    for i=1,#keys,1 do
        if cjson.decode(sessions:get(keys[i])).ctx.uid==uid then
            sessions:del(keys[i])
            result=result+1
        end
    end
    return result,nil
end

function _M:getAll()
	local sessions=self.redis--ngx.shared.sessions
    local keys,err=sessions:keys("gateway_session_*")--sessions:get_keys()
    for i=1,#keys,1 do
        result[keys[i]]=cjson.decode(sessions:get(keys[i]))
    end
    return result,count,nil
end

return _M