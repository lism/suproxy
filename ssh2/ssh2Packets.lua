--ssh2.0 protocol parser and encoder

    local paddingLength=16-(#data+5)%16
    if paddingLength<4 then paddingLength=paddingLength+16 end
    local padding=padding or string.random(paddingLength)
    return string.pack(">I4B",#data+1+#padding,#padding)..data..padding
end


-- byte      SSH_MSG_KEXDH_INIT 0x1e
-- mpint     e
_M.DHKeyXInit={
    code=_M.PktType.DHKeyXInit,
    parsePayload=function(self,payload,pos)
        self.e=string.unpack(">s4",payload,pos) 
        return self
    end,
    packPayload=function(self)
        return string.pack(">s4",paddingInt(self.e))
    end
}

-- byte      SSH_MSG_KEXDH_REPLY 0x1f
-- string    server public host key and certificates (K_S)
-- mpint     f
-- string    signature of H
_M.DHKeyXReply={
    code=_M.PktType.DHKeyXReply,
    parsePayload=function(self,payload,pos)
        self.K_S,
        self.f,
        hh=string.unpack(">s4s4s4",payload,pos) 
        self.key_alg,
        self.signH=string.unpack(">s4s4",hh)
        return self
    end,
    packPayload=function(self)
        return string.pack(">s4s4s4",self.K_S,paddingInt(self.f),string.pack(">s4s4",self.key_alg,self.signH))
    end
}
--process user authenticate, request format in rfc4252 section 8
-- byte      SSH_MSG_USERAUTH_REQUEST 0x32
-- string    user name
-- string    service name
-- string    method
-- below are optional, if method is "none" ,following field woundn't appear
-- boolean   FALSE
-- string    plaintext password in ISO-10646 UTF-8 encoding [RFC3629]
_M.AuthReq={
    code=_M.PktType.AuthReq,
    parsePayload=function(self,payload,pos)
        local passStartPos
        self.username,
        self.serviceName,
        self.method,passStartPos=string.unpack(">s4s4s4",payload,pos)
        if self.method=="password" then
            self.password=string.unpack(">s1",payload,passStartPos+4)
        end
        return self
    end,
    packPayload=function(self)
        local req=string.pack(">s4s4s4",self.username,self.serviceName,self.method)
        if self.method=="password" then
            req=req..string.pack(">s4s1","",self.password)
        end
        return req
    end
}

_M.AuthFail={
-- byte      SSH_MSG_CHANNEL_DATA 0x5e
-- uint32    recipient channel
-- string    data
_M.ChannelData={
    code=_M.PktType.ChannelData,
    parsePayload=function(self,payload,pos)
        self.channel,self.data=string.unpack(">I4s4",payload,pos) 
        return self
    end,
    packPayload=function(self)
        return string.pack(">I4s4",self.channel,self.data)
    end
}
-- byte      SSH_MSG_DISCONNECT 0x01
-- uint32    reason code
-- string    description in ISO-10646 UTF-8 encoding [RFC3629]
-- string    language tag [RFC3066]
_M.Disconnect={
    code=_M.PktType.Disconnect,
    parsePayload=function(self,payload,pos)
        self.reasonCode,self.message=string.unpack(">I4s4",payload,pos) 
        return self
    end,
    packPayload=function(self)
        return string.pack(">I4s4",self.reasonCode,self.message)
    end
}
return _M