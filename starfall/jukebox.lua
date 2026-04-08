--@name Jukebox
--@author Vactor0911
--@shared

if SERVER then
    -- send music url to all clients
    net.receive("song_sv", function()
        local url = net.readString()
        
        net.start("song_cl")
        net.writeString(url)
        net.send()
    end)
end

if CLIENT then
    function requestSong(songUrl)
        if player() ~= owner() then
            return
        end
        
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
                local rawSongUrl = "https://jukebox.vactor0911.dev/musics/" .. songUuid .. ".mp3"
                
                -- send music url to server
                net.start("song_sv")
                net.writeString(rawSongUrl)
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
        
        if string.left(text, 6) ~= "!song " then
            return false
        end
        
        local command = string.split(text, " ")
        local songUrl = string.trim(command[2])
        
        if command[1] == "!song" and string.len(songUrl) > 0 then
            print("Requesting song: " .. songUrl)
            requestSong(songUrl)
        end
        
        return false
    end)
    
    -- receive song url request
    net.receive("song_cl", function()
        local url = net.readString()
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
                snd:setVolume(1)
                snd:setFade(1200, 1200)
            end)
        end)
    end)
end