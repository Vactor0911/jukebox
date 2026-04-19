--@name Jukebox
--@author Vactor0911
--@shared
--@model models/bull/various/speaker.mdl

local allowCommands = { "/song", "/volume", "/radius", "/time", "/play", "/pause", "/stop",
    "/lock", "/loop", "/next", "/prev" }

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

    -- functions
    local function sendData(data)
        net.start("sv_cl")
        net.writeTable(data)
        net.send()
    end

    local function playSong(song)
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
    end

    local function playNextSong()
        if (loopState == 1 and #history + #queue == 1) or loopState == 2 then
            local song = queue[1]
            playSong(song)
            return
        end

        if #queue > 0 then
            local prevSong = table.remove(queue, 1)
            table.insert(history, prevSong)
            wire.ports.Queue = queue
            wire.ports.History = history
        end

        if #queue <= 0 then
            if loopState == 0 then
                print("song ended")
                wire.ports.Playing = 0
                wire.ports.Paused = 0
                wire.ports.Ended = 1

                playSong()
                return
            elseif #history <= 0 then
                print("history is empty")
                playSong()
                return
            end

            local prevSong = table.remove(history, 1)
            table.insert(queue, prevSong)
            wire.ports.Queue = queue
            wire.ports.History = history
        end

        local song = queue[1]
        playSong(song)
    end

    -- wirelinks
    wire.adjustInputs(
        { "SongUrl", "Play", "Pause", "Stop", "Volume", "Time", "Radius", "Loop", "Lock", "PlayNext", "PlayPrev" },
        { "string", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n" }
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
            wire.ports.Volume = volume
        elseif command[1] == "/radius" then
            -- validate format (number)
            local radius = tonumber(command[2])
            if not isnumber(radius) then
                printError("radius must be a number.")
                return ""
            end
            data.radius = radius
            wire.ports.Radius = radius
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
        elseif command[1] == "/loop" then
            -- rotate loop state
            loopState = loopState + 1
            if loopState > 2 then
                loopState = loopState - 3
            end
            print("loop set to " .. loopState)
            data.loop = loopState
            wire.ports.Loop = loopState
            return ""
        elseif command[1] == "/next" then
            playNextSong()
            return ""
        elseif command[1] == "/prev" then
            -- set time to 0 if loop is on
            if (loopState == 1 and #history + #queue == 1) or loopState == 2 then
                data = createData("/time")
                data.time = 0
                sendData(data)
                return ""
            end

            -- bring history if loop is off
            if #history <= 0 then
                printError("history is empty.")
                return ""
            end

            local prevSong = table.remove(history)
            table.insert(queue, 1, prevSong)
            wire.ports.Queue = queue
            wire.ports.History = history

            playSong(prevSong)
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
            wire.ports.Length = data.length
            
            if math.floor(data.time) >= math.floor(data.length) then
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

    -- sound position interval
    timer.create("sound_pos", 0.1, 0, function()
        -- validate sound object
        if not isValid(snd) then
            return
        end

        -- set sound pos
        snd:setPos(chip():getPos())
    end)

    -- sound data interval
    timer.create("sound_display", 0.2, 0, function()
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
