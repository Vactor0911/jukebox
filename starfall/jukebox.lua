--@name Jukebox
--@author Vactor0911
--@shared
--@model models/bull/various/speaker.mdl

local allowCommands = { "/song", "/volume", "/radius", "/time", "/play", "/pause", "/stop", "/loop", "/next", "/prev" }

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
    local loopState = 0 -- 0: no loop, 1: loop, 2: single loop
    local historyLoopPointer = nil
    local currentTime = 0

    -- functions
    local function sendData(data, target)
        net.start("sv_cl")
        net.writeTable(data)
        net.send(target)
    end

    local function playSong(song)
        currentTime = 0
        
        local data = createData("/play_song")
        data.songUuid = song ~= nil and song.songUuid or nil
        data.title = song ~= nil and song.title or nil
        data.uploader = song ~= nil and song.uploader or nil
        sendData(data)
        
        wire.ports.Title = song ~= nil and song.title or ""
        wire.ports.Uploader = song ~= nil and song.uploader or ""
        wire.ports.AlbumImageUrl = song ~= nil and "https://jukebox.vactor0911.dev/musics/" .. song.songUuid .. ".jpg" or ""
        wire.ports.Time = 0
        wire.ports.Length = 0
        wire.ports.Playing = song ~= nil and 1 or 0
        wire.ports.Paused = 0
        wire.ports.Ended = song ~= nil and 0 or 1
    end
    
    local function resetTime()
        local data = createData("/time")
        data.time = 0
        sendData(data)
    end

    -- wirelinks
    wire.adjustInputs(
        { "SongUrl", "Play", "Pause", "Stop", "Volume", "Time", "Radius", "Loop", "PlayNext", "PlayPrev" },
        { "string", "n", "n", "n", "n", "n", "n", "n", "n", "n" }
    )
    wire.adjustOutputs(
        { "Title", "Uploader", "AlbumImageUrl", "Playing", "Loading", "Paused", "Ended", "Volume", "Radius", "Time",
            "Length", "Loop", "Shuffle", "Queue", "History" },
        { "string", "string", "string", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n", "table", "table" }
    )
    
    -- initialize outputs
    wire.ports.Title = ""
    wire.ports.Uploader = ""
    wire.ports.AlbumImageUrl = ""
    wire.ports.Playing = 0
    wire.ports.Loading = 0
    wire.ports.Paused = 0
    wire.ports.Ended = 0
    wire.ports.Volume = 1
    wire.ports.Radius = 800
    wire.ports.Time = 0
    wire.ports.Loop = 0
    wire.ports.Shuffle = 0
    wire.ports.Queue = {}
    wire.ports.History = {}
    
    -- service layer
    local function song(songUrl)
        local data = createData("/song")
        data.song = songUrl
        sendData(data, owner())
    end
    
    local function play()
        local data = createData("/play")
        sendData(data)
    end
    
    local function pause()
        local data = createData("/pause")
        sendData(data)
    end
    
    local function stop()
        local data = createData("/stop")
        sendData(data)
    end
    
    local function volume(newVolume)
        wire.ports.Volume = newVolume
        
        local data = createData("/volume")
        data.volume = newVolume
        sendData(data)
    end
    
    local function radius(newRadius)
        local radius = math.floor(newRadius)
                
        wire.ports.Radius = radius
        
        local data = createData("/radius")
        data.radius = radius
        sendData(data)
    end
    
    local function time(newTime)
        local data = createData("/time")
        data.time = newTime
        sendData(data)
    end
    
    local function loop(newLoopState)
        local loop = math.floor(newLoopState)
        wire.ports.Loop = loop
        loopState = loop
        
        if loop == 1 then
            historyLoopPointer = #history + 1
        end
    end
    
    local function playNext()
        -- replay if loopState is 2
        if loopState == 2 then
            local currentSong = queue[1]
            playSong(currentSong)
            return
        end
        
        -- move current song to history
        local currentSong = table.remove(queue, 1)
        table.insert(history, currentSong)
        wire.ports.Queue = queue
        wire.ports.History = history
        
        -- get next song
        if loopState == 0 then
            if #queue > 0 then
                local nextSong = queue[1]
                playSong(nextSong)
            else
                print("song ended")
                playSong()
                return
            end
        elseif loopState == 1 then
            if #queue > 0 then
                local nextSong = queue[1]
                playSong(nextSong)
            else
                local nextSong = table.remove(history, historyLoopPointer)
                table.insert(queue, nextSong)
                wire.ports.Queue = queue
                wire.ports.History = history
                playSong(nextSong)
            end
        end
    end
    
    local function playPrev()
        -- return if history & queue is empty
        if #history <= 0 and #queue <= 0 then
            return
        end
        
        -- set time to 0 if currentTime is greater than 5 second
        if currentTime > 5 then
            resetTime()
            return
        end
        
        -- set time to 0 if loop is on
        if (loopState == 1 and #history == 0) or loopState == 2 then
            resetTime()
            return
        end

        -- bring history if loop is off
        if #history <= 0 then
            -- set time to 0 if history is empty
            resetTime()
            return
        end

        local prevSong = table.remove(history)
        table.insert(queue, 1, prevSong)
        wire.ports.Queue = queue
        wire.ports.History = history
        playSong(prevSong)
    end

    -- handle chat commands
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
        if command[1] == "/song" then
            local songUrl = command[2]
            if songUrl == nil then
                printError("song url cannot be empty.")
                return ""
            end
            song(songUrl)
        elseif command[1] == "/play" then
            play()
        elseif command[1] == "/pause" then
            pause()
        elseif command[1] == "/stop" then
            stop()
        elseif command[1] == "/volume" then
            --validate format (number)
            local newVolume = tonumber(command[2])
            if not isnumber(newVolume) then
                printError("volume must be a number.")
                return ""
            end
            volume(newVolume)
        elseif command[1] == "/radius" then
            -- validate format (number)
            local newRadius = tonumber(command[2])
            if not isnumber(newRadius) then
                printError("radius must be a number.")
                return ""
            end
            radius(newRadius)
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
                
                local newTime = minute * 60 + second
                time(newTime)
            else
                -- check is the value is number (second)
                local newTime = tonumber(command[2])
                if not isnumber(newTime) then
                    printError("invalid time format. (mm:ss or s)")
                    return ""
                end
                time(newTime)
            end
        elseif command[1] == "/loop" then
            -- rotate loop state
            loopState = loopState + 1
            if loopState > 2 then
                loopState = loopState - 3
            end
            loop(loopState)
        elseif command[1] == "/next" then
            playNext()
        elseif command[1] == "/prev" then
            playPrev()
        end
        
        return ""
    end)
    
    -- handle wire inputs
    hook.add("Input", "", function(inputName, value)
        if inputName == "SongUrl" then
        elseif inputName == "Play" then
            if value == 1 then
                play()
            end
        elseif inputName == "Pause" then
            if value == 1 then
                pause()
            end
        elseif inputName == "Stop" then
            if value == 1 then
                stop()
            end
        elseif inputName == "Volume" then
            volume(value)
        elseif inputName == "Time" then
            time(value)
        elseif inputName == "Radius" then
            radius(value)
        elseif inputName == "Loop" then
            loop(value)
        elseif inputName == "PlayNext" then
            if value == 1 then
                playNext()
            end
        elseif inputName == "PlayPrev" then
            if value == 1 then
                playPrev()
            end
        end
    end)

    -- receive requests
    net.receive("cl_sv", function()
        local data = net.readTable()

        if data.command == "/add_queue" then
            if #queue <= 0 then
                -- play immediately if queue is empty
                playSong(data)
            end

            -- insert song to queue
            data.command = nil
            table.insert(queue, data)
            wire.ports.Queue = queue
        elseif data.command == "/fetch_status" then
            wire.ports.Playing = data.playing
            wire.ports.Paused = data.paused
            wire.ports.Ended = data.ended
            wire.ports.Time = data.time
            currentTime = data.time
            wire.ports.Length = data.length
            
            if math.floor(data.time) >= math.floor(data.length) then
                playNext()
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
    
    local function calcVolume(radius, volumeBase)
        local distance = chip():getPos():getDistance(player():getPos())
        if distance < radius * 0.75 then
            return volume
        elseif distance > radius then
            return 0
        else
            return (radius - distance) / (radius * 0.25) * volumeBase
        end
    end
    
    -- get api key
    local apikey
    if player() == owner() and file.exists("jukebox.txt") then
        apikey = file.read("jukebox.txt")
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
                ["Content-Type"] = "application/json",
                ["Authorization"] = apikey
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
        elseif command == "/radius" then
            radius = data.radius
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
            bass.loadURL(url, "3d noblock", function(newSound)
                snd = newSound
                
                local newVolume = calcVolume(radius, volume)
                snd:setVolume(newVolume)
            end)
            title = data.title
            uploader = data.uploader
        else
            printError("unknown command from server.")
        end
    end)

    -- sound position interval
    hook.add("Think", "", function()
        -- validate sound object
        if not isValid(snd) then
            return
        end
        
        -- set volume
        local newVolume = calcVolume(radius, volume)
        snd:setVolume(newVolume)
        
        -- doesn't need to update pos if volume is less or equal than 0
        if newVolume <= 0 then
            return
        end
        
        -- set sound pos
        snd:setPos(player():getPos())
    end)

    -- sound data interval
    timer.create("sound_display", 0.5, 0, function()
        -- validate sound object
        if not isValid(snd) then
            return
        end

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
        data.playing = (isValid(snd) and snd:isPlaying()) and 1 or 0
        data.paused = (isValid(snd) and snd:isPaused()) and 1 or 0
        data.ended = not isValid(snd) and 1 or 0
        sendData(data)

        if time >= length then
            snd = nil
        end
    end)
end
