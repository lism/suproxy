local sub = string.sub
local event=require "suproxy.utils.event"

_M._VERSION = '0.01'


function _M:new(upstreams,processor,options)
    local c2pSock, err = ngx.req.socket()
    if not c2pSock then
        return nil, err
    end
    c2pSock:settimeouts(options.c2pConnTimeout , options.c2pSendTimeout , options.c2pReadTimeout)
    local standalone=false
    if(not upstreams) then
        logger.log(logger.ERR, format("[SuProxy] no upstream specified, Proxy will run in standalone mode"))
        standalone=true
    end
    local p2sSock=nil
    if(not standalone) then
        p2sSock, err = tcp()
        if not p2sSock then
            return nil, err
        end
        p2sSock:settimeouts(options.p2sConnTimeout , options.p2sSendTimeout , options.p2sReadTimeout )
    end
    --add default receive-then-forward processor
    if(not processor and not standalone) then
        processor={}
        processor.processUpRequest=function(self)
            local data, err, partial =self.channel:c2pRead(1024*10)
            if(data and not err) then 
                return data 
            else 
                return partial
            end
        end
        processor.processDownRequest=function(self)
            local data, err, partial = self.channel:p2sRead(1024*10)
            if(data and not err) then 
                return data 
            else 
                return partial
            end
        end
    end
    --add default echo processor if proxy in standalone mode
    if(not processor and standalone) then
        processor={}
        processor.processUpRequest=function(self)
            local data, err, partial =self.channel:c2pRead(1024*10)
            --real error happend or timeout
            local echodata=""
            if(data and not err) then 
                echodata=data
            else      
                echodata=partial
            end
            logger.log(logger.INFO,echodata)
            local _,err=self.channel:c2pSend(echodata)
            logger.log(logger.ERR,partial)
        end
    end
    local upForwarder=function(self,data)
        if data then return self.channel:p2sSend(data) end
    end
    local downForwarder=function(self,data)
        if data then return self.channel:c2pSend(data) end
    end
    --add default upforwarder
    processor.sendUp=processor.sendUp or upForwarder
    --add default downforwarder
    processor.sendDown=processor.sendDown or downForwarder
    
end

    logger.log(logger.DEBUG, format("[SuProxy] clean up executed"))
    -- make sure buffers are clean
    ngx.flush(true)
    local p2sSock = self.p2sSock
    local c2pSock = self.c2pSock
    if p2sSock ~= nil then
        if p2sSock.shutdown then
            p2sSock:shutdown("send")
        end
        if p2sSock.close ~= nil then
            local ok, err = p2sSock:setkeepalive()
            if not ok then
                --
            end
        end
    end
    
    if c2pSock ~= nil then
        if c2pSock.shutdown then
            c2pSock:shutdown("send")
        end
        if c2pSock.close ~= nil then
            local ok, err = c2pSock:close()
            if not ok then
                --
            end
        end
    end
    
end

    -- proxy client request to server
    local buf, err, partial
    while true do
        buf, err, partial = self.processor:processUpRequest(self.standalone)
        if err  then
            logger.log(logger.ERR, format("[SuProxy] processUpRequest fail: %s:%s, err:%s", upstream.ip, upstream.port, err))
            break
        end
        --if in standalone mode, don't forward
        if not self.standalone and buf then 
            local _, err = self.processor:sendUp(buf)
            if err then
            logger.log(logger.ERR, format("[SuProxy] forward to upstream fail: %s:%s, err:%s", upstream.ip, upstream.port, err))
                break
            end
        end
    end
end

    -- proxy response to client
    local buf, err, partial
    while true do
        buf, err, partial = self.processor:processDownRequest(self.standalone) 
        if err then
        logger.log(logger.ERR, format("[SuProxy] processDownRequest fail: %s:%s, err:%s", upstream.ip, upstream.port, err))
            break
        end
        if buf then
            local _, err = self.processor:sendDown(buf)
            if err then
            logger.log(logger.ERR, format("[SuProxy] forward to downstream fail: %s:%s, err:%s", upstream.ip, upstream.port, err))
                break
            end
        end
    end
end
function _M:run()
    while true do
        if(not self.standalone) then
				local ok, err = self.p2sSock:connect(upstream.ip, upstream.port)
				if not ok then
					logger.log(logger.ERR, format("[SuProxy] failed to connect to proxy upstream: %s:%s, err:%s", upstream.ip, upstream.port, err))
					self.balancer:blame(upstream)
				else
        end
        local co_upl = spawn(_upl,self)
        if(not self.standalone) then
            local co_dwn = spawn(_dwn,self) 
            wait(co_dwn)
        end
        wait(co_upl)
        break
    end
    _cleanup(self)
end

return _M