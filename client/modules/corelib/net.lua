function translateNetworkError(errcode, connecting, errdesc)
    local text
    if errdesc == 'CLIENT_PROTOCOL_MISMATCH' then
        local manager = modules.client_profiles
        text = (manager and manager.takeCatalogError and manager.takeCatalogError()) or
            tr('The client could not read the server data.\nThe server message format did not match this profile.\nDetails are available in packet.log.')
    elseif errcode == 111 or errcode == 61 then
        text = tr('Connection refused, the server might be offline or restarting.\nPlease try again later.')
    elseif errcode == 110 then
        text = tr('Connection timed out. Either your network is failing or the server is offline.')
    elseif errcode == 1 then
        text = tr('Connection failed, the server address does not exist.')
    elseif connecting then
        text = tr('Connection failed.')
    else
        text = tr('Your connection has been lost.\nEither your network or the server went down.')
    end
    text = text .. ' ' .. tr('(ERROR %d)', errcode)
    return text
end
