--@name Jukebox
--@author Vactor0911
--@shared
--@model models/props/cs_office/radio.mdl

if SERVER then
    wire.adjustInputs(
        {"SongUrl", "Play", "Pause", "Volume", "Time", "PlayNext", "PlayPrev", "Loop", "Shuffle"},
        {"string", "n", "n", "n", "n", "n", "n", "n", "n"}
    )
    wire.adjustOutputs(
        {"Title", "Uploader", "AlbumImageUrl", "Playing", "Loading", "Paused", "Ended", "Volume", "Radius", "Time", "Loop", "Shuffle", "Queue"},
        {"string", "string", "string", "n", "n", "n", "n", "n", "n", "n", "n", "n", "array"}
    )
    
    -- send music url to all clients
    net.receive("song_sv", function()
        local uuid = net.readString()
        local title = net.readString()
        local uploader = net.readString()
        
        net.start("song_cl")
        net.writeString(uuid)
        net.writeString(title)
        net.writeString(uploader)
        net.send()
    end)
    
    -- send volume to all clients
    net.receive("volume_sv", function()
        local volume = net.readFloat()
        
        net.start("volume_cl")
        net.writeFloat(volume)
        net.send()
    end)
    
    -- send status to all clients
    net.receive("status_sv", function()
        local status = net.readString()
        
        net.start("status_cl")
        net.writeString(status)
        net.send()
    end)
end

if CLIENT then
    local status = "Idle"
    local volume = 1.0
    setName("Jukebox - " .. status)
    
    function requestSong(songUrl)
        if player() ~= owner() then
            return
        end
        
        net.start("status_sv")
        net.writeString("Loading")
        net.send()
        
        -- request youtube music to jukebox server
        local payload = '{"url":"' .. songUrl .. '"}'
        local headers = {
            ["Content-Type"] = "application/json"
        }
        
        -- send http post request
        http.post("https://jukebox.vactor0911.dev/song/add",
        payload,
        function(body)
            local jsonBody = json.decode(body)
            
            -- validate response body
            if not jsonBody.success then
                print("Song request error: ", jsonBody.message)
            end
            
            local songUuid = jsonBody.data.song.uuid
            if string.len(songUuid) > 0 then
                -- send music url to server
                local title = jsonBody.data.song.title
                local uploader = jsonBody.data.song.uploader
                
                net.start("song_sv")
                net.writeString(songUuid)
                net.writeString(title)
                net.writeString(uploader)
                net.send()
            end
        end,
        function(error)
            -- error handling
            print("Song request error: ", error)
        end,
        headers)
    end
    
    -- recieve chat command from owner
    hook.add("PlayerChat", "", function(player, text, isTeam, isdead)
        if player ~= owner() then
            return false
        end
        
        local command = string.split(text, " ")
        
        if #command ~= 2 then
            return false
        end
        
        if command[1] == "!song" then
            local songUrl = string.trim(command[2])
            
            if command[1] == "!song" and string.len(songUrl) > 0 then
                print("Requesting song: " .. songUrl)
                requestSong(songUrl)
            end
            return true
        elseif command[1] == "!volume" then
            local volume = tonumber(command[2])
            
            if not isnumber(volume) then
                print("Volume request error!")
                return true
            end
            
            net.start("volume_sv")
            net.writeFloat(volume)
            net.send()
            return true
        end
        
        return false
    end)
    
    -- receive song request
    net.receive("song_cl", function()
        local songUuid = net.readString()
        local title = net.readString()
        local uploader = net.readString()
        status = "Playing"
        
        -- play song
        local url = "https://jukebox.vactor0911.dev/musics/" .. songUuid .. ".mp3"
        bass.loadURL(url,"3d noblock",function(snd)
            timer.create("", 3, 1, function()
                --print("setTime to 10")
                --snd:setTime(10)
            end)
            
            -- config sound object
            hook.add("think","bass",function()
                if not isValid(snd) then
                    return
                end
                                
                snd:setPos(chip():getPos())
                snd:setVolume(volume)
                snd:setFade(600, 800)
                
                -- update song metadata
                local time = string.formattedTime(snd:getTime(), "%02d:%02d")
                local length = string.formattedTime(snd:getLength(), "%02d:%02d")
                local newName = "Jukebox - " .. status .. " ]\n" .. title .. "\n" .. uploader .. "\n" ..
                    "[ " .. time .. " / " .. length
                setName(newName)
            end)
        end)
    end)
    
    -- receive volume request
    net.receive("volume_cl", function()
        volume = net.readFloat()
    end)
    
    -- receive status
    net.receive("status_cl", function()
        status = net.readString()
    end)
end
