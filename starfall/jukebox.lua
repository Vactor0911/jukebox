--@name Jukebox
--@author Vactor0911
--@shared
--@model models/bull/various/speaker.mdl

local allowCommands = {"/song", "/volume", "/radius", "/time", "/play", "/pause", "/stop",
    "/lock", "/loop", "/next", "/prev"}

local function createData(command)
    local data = {}
    data.command = command
    return data
end

local function printError(error)
    print("[Jukebox] Error:", error)
end

if SERVER then
    -- global variables
    local queue = {}
    local history = {}
    local isPlaying = false
    local isPaused = false
    
    -- functions
    local function sendData(data)
        net.start("sv_cl")
        net.writeTable(data)
        net.send()
    end
    
    local function playNextSong()
        if #queue > 0 then
            local prevSong = table.remove(queue, 1)
            table.insert(history, prevSong)
            printTable(history)
        end
        
        if #queue <= 0 then
            print("song ended")
            local newData = createData("/play_song")
            sendData(newData)
            return
        end
            
        local song = queue[1]
        print("new song")
        printTable(song)
        local newData = createData("/play_song")
        newData.songUuid = song.songUuid
        newData.title = song.title
        newData.uploader = song.uploader
        sendData(newData)
    end
    
    -- wirelinks
    wire.adjustInputs(
        {"SongUrl", "Play", "Pause", "Stop", "Volume", "Time", "Radius", "Loop", "Lock", "PlayNext", "PlayPrev"},
        {"string", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n"}
    )
    wire.adjustOutputs(
        {"Title", "Uploader", "AlbumImageUrl", "Playing", "Loading", "Paused", "Ended", "Volume", "Radius", "Time", "Loop", "Shuffle", "Queue"},
        {"string", "string", "string", "n", "n", "n", "n", "n", "n", "n", "n", "n", "array"}
    )
    
    -- process chat commands
    hook.add("PlayerSay", "", function(player, text)
        -- accept command for only owner
        if player ~= owner() then
            return
        end
        
        -- filter regular chats
        local command = string.explode(" ", text)
        if not table.hasValue(allowCommands, command[1]) then
            return
        end
        
        -- chat commands
        local data = createData(command[1])
        
        if command[1] == "/song" then
            if command[2] == nil then
                printError("song url cannot be empty.")
                return ""
            end
            data.song = command[2]
            
            -- request only for owner
            net.start("sv_cl")
            net.writeTable(data)
            net.send(owner())
            return ""
        elseif command[1] == "/volume" then
            --validate format (number)
            local volume = tonumber(command[2])
            if not isnumber(volume) then
                printError("volume must be a number.")
                return ""
            end
            data.volume = volume
        elseif command[1] == "/radius" then
            -- validate format (number)
            local radius = tonumber(command[2])
            if not isnumber(radius) then
                printError("radius must be a number.")
                return ""
            end
            data.radius = radius
        elseif command[1] == "/time" then
            -- check if the format is mm:ss
            local param = table.concat(command, "", 2)
            local strTime = string.explode(":", param)
            if #strTime == 2 then
                local minute = tonumber(strTime[1])
                local second = tonumber(strTime[2])
                if not isnumber(minute) or not isnumber(second) then
                    printError("invalid time format. (mm:ss or s)")
                    return ""
                end
                data.time = minute * 60 + second
            else
                -- check is the value is number (second)
                local time = tonumber(command[2])
                if not isnumber(time) then
                    printError("invalid time format. (mm:ss or s)")
                    return ""
                end
                data.time = time
            end
        elseif command[1] == "/next" then
            playNextSong()                
            return ""
        elseif command[1] == "/prev" then
            if #history <= 0 then
                printError("history is empty.")
                return ""
            end
            
            local prevSong = table.remove(history)
            table.insert(queue, 1, prevSong)
            
            local data = createData("/play_song")
            data.songUuid = prevSong.songUuid
            data.title = prevSong.title
            data.uploader = prevSong.uploader
            sendData(data)
            return ""
        end
        
        sendData(data)
        return ""
    end)
    
    -- receive requests    
    net.receive("cl_sv", function()
        local data = net.readTable()
        
        if data.command == "/add_queue" then
            if #queue <= 0 then
                -- play immediately if queue is empty
                data.command = "/play_song"
                sendData(data)
            end
            
            -- insert song to queue
            data.command = nil
            table.insert(queue, data)
        elseif data.command == "/fetch_status" then
            if data.time >= data.length then
                playNextSong()
            end
        end
    end)
elseif CLIENT then
    -- global variables
    local snd = nil
    local title = ""
    local uploader = ""
    local volume = 1
    local radius = 800
    
    -- functions
    local function sendData(data)
        net.start("cl_sv")
        net.writeTable(data)
        net.send()
    end
    
    local function getFade(radius)
        local fade = radius * 0.75
        return fade
    end
    
    -- receive requests
    net.receive("sv_cl", function()
        local data = net.readTable()
        local command = data.command
        
        -- process command
        if command == "/song" then
            -- request youtube music to jukebox web server
            local payload = '{"url":"' .. data.song .. '"}'
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
                    printError("song request error..\n" .. jsonBody.error)
                    return
                end
                
                local songUuid = jsonBody.data.song.uuid
                print(songUuid)
                if string.len(songUuid) > 0 then
                    -- send music url to server
                    local title = jsonBody.data.song.title
                    local uploader = jsonBody.data.song.uploader
                    
                    local data = createData("/add_queue")
                    data.songUuid = songUuid
                    data.title = title
                    data.uploader = uploader
                    sendData(data)
                end
            end,
            function(error)
                -- error handling
                printError("song request error..\n" .. error)
            end,
            headers)
        elseif command == "/volume" then
            volume = data.volume
            if isValid(snd) then
                snd:setVolume(data.volume)
            end
        elseif command == "/radius" then
            radius = data.radius
            if isValid(snd) then
                local fade = getFade(radius)
                snd:setFade(fade, radius)
            end
        elseif command == "/time" then
            if isValid(snd) then
                snd:setTime(data.time)
            end
        elseif command == "/play" then
            if isValid(snd) then
                snd:play()
            end
        elseif command == "/pause" then
            if isValid(snd) then
                snd:pause()
            end
        elseif command == "/stop" then
            if isValid(snd) then
                snd:pause()
                snd:setTime(0)
            end
        elseif command == "/lock" then
        elseif command == "/loop" then
            if isValid(snd) then
                snd:setLooping(false)
            end
        elseif command == "/play_song" then
            -- clear sound object if songUuid is nil
            if data.songUuid == nil then
                if isValid(snd) then
                    snd:stop()
                end
                title = ""
                uploader = ""
                local newName = "Jukebox"
                setName(newName)
                return
            end
            
            -- clear prev sound object
            if isValid(snd) then
                snd:stop()
            end
            
            -- fetch mp3 file & metadata
            local url = "https://jukebox.vactor0911.dev/musics/" .. data.songUuid .. ".mp3"
            bass.loadURL(url,"3d noblock",function(newSound)
                snd = newSound
                snd:setVolume(volume)
                
                local fade = getFade(radius)
                snd:setFade(fade, radius)
            end)
            title = data.title
            uploader = data.uploader
        else
            printError("unknown command from server.")
        end
    end)
    
    -- sound interval
    timer.create("interval", 0.2, 0, function()
        -- validate sound object
        if not isValid(snd) then
            return
        end
        
        -- set sound pos
        snd:setPos(chip():getPos())
        
        -- update display data
        local time = snd:getTime()
        local length = snd:getLength()
        local formattedTime = string.formattedTime(time, "%02d:%02d")
        local formattedLength = string.formattedTime(length, "%02d:%02d")
        local newName = "Jukebox ]\n" .. title .. "\n" .. uploader .. "\n" ..
            "[ " .. formattedTime .. " / " .. formattedLength
        setName(newName)
        
        -- send sound data to server
        if player() ~= owner() then
            return
        end
        
        local data = createData("/fetch_status")
        data.time = time
        data.length = length
        sendData(data)
        
        if time >= length then
            snd = nil
        end
    end)
end
