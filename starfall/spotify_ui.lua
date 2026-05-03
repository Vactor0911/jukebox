--@name Spotify UI
--@author Vactor0911
--@shared

-- settings
local SIZE = 75

if SERVER then
    -- global variables
    local inputs = {}

    -- wirelinks
    wire.adjustInputs(
        { "Title", "Uploader", "AlbumImageUrl", "Playing", "Loading", "Paused", "Ended", "Volume", "Time", "Length", "Loop",
            "Shuffle" },
        { "string", "string", "string", "n", "n", "n", "n", "n", "n", "n", "n", "n" }
    )
    wire.adjustOutputs(
        { "SongUrl", "Play", "Pause", "Stop", "Volume", "Time", "Radius", "Loop", "PlayNext", "PlayPrev" },
        { "string", "n", "n", "n", "n", "n", "n", "n", "n", "n" }
    )

    -- 0.2s delay for client initialize
    timer.create("delay", 0.5, 1, function()
        -- init data
        local inputNames = wire.getInputs(chip())
        for i, inputName in pairs(inputNames) do
            inputs[inputName] = wire.ports[inputName]
        end
        net.start("init")
        net.writeTable(inputs)
        net.send()

        -- transmit wirelink input data
        hook.add("Input", "", function(inputName, value)
            net.start("input")
            local payload = {}

            if inputName == "Title" then
                payload[inputName] = (value == "" and "No Title" or value)
            elseif inputName == "Uploader" then
                payload[inputName] = (value == "" and "Unknown" or value)
            else
                payload[inputName] = value
            end

            net.writeTable(payload)
            net.send()
        end)
        
        -- receive button event
        net.receive("button_event", function()
            local data = net.readTable()
            for port, value in pairs(data) do
                if port == "Lock" then
                    isLocked = not isLocked
                    continue
                end

                wire.ports[port] = value
            end
        end)
        
        -- update lock
        net.receive("cl_lock", function()
            local newLock = net.readBool()
            net.start("sv_lock")
            net.writeBool(newLock)
            net.send()
        end)
    end)
elseif CLIENT then
    -- global variables
    local data = {}
    data.Title = "No Song Playing"
    data.Uploader = "/song {youtube url}"
    data.AlbumImageUrl = ""
    data.Playing = 0
    data.Loading = 0
    data.Paused = 0
    data.Ended = 0
    data.Volume = 0
    data.Time = 0
    data.Length = 0
    data.Loop = 0
    data.Shuffle = 0
    
    local cursorX, cursorY
    local isVolumeBarVisible = false
    local isLocked = false
    
    -- create screen & render targets
    render.createRenderTarget("main")
    render.createRenderTarget("dynamic")
    render.createRenderTarget("static")
    render.createRenderTarget("background")
    render.createRenderTarget("cursor")

    local screenMat = material.create("UnlitGeneric")
    screenMat:setTextureRenderTarget("$basetexture", "main")
    screenMat:setInt("$flags", 0)

    local screen = hologram.create(chip():getPos() + Vector(0, 0, SIZE * 0.5 + 10), chip():getAngles(),
        "models/starfall/holograms/box.mdl",
        Vector(0, SIZE, SIZE))
    screen:setMaterial("!" .. screenMat:getName())
    screen:setParent(chip())
    
    -- title scroll animation
    local TITLE_SCROLL_SPEED = 100         -- pixels per second
    local TITLE_SCROLL_PAUSE = 3           -- seconds before and after scrolling
    local titleScrollOffset = 0
    local titleScrollPhase = "pause_start" -- "pause_start", "scrolling", "pause_end"
    local titleScrollPhaseTime = timer.systime()
    local titleScrollOverflow = 0
    local titlePrev = ""

    -- theme color
    local THEME = Color(30, 215, 96)

    -- fetch album image
    local isStale = true
    local function getAlbumImage(url)
        if url == nil or url == "" then
            print("placeholder")
            return albumPlaceholder
        end

        local image = render.createMaterial(url,
            function(mat, _, _, _, layout)
                if mat ~= nil then
                    layout(0, 0, 1024, 1024)
                end
            end,
            function()
                isStale = true
            end)
        return image
    end
    
    -- select render target
    local function selectRenderTarget(name)
        render.selectRenderTarget(name)
        render.clear(Color(0, 0, 0, 0))
        render.setColor(Color(255, 255, 255, 255))
    end
    
    -- fonts
    local regularFont = render.createFont("Arial", 64, 500)
    local boldFont = render.createFont("Arial", 64, 900)
    
    -- album images
    local albumPlaceholder = render.createMaterial("https://github.com/Vactor0911/jukebox/releases/download/images-v1/AlbumSample.png?v=1.0w",
        function(mat, _, _, _, layout)
            if mat ~= nil then
                layout(0, 0, 1024, 1024)
            end
        end,
        function()
            isStale = true
        end)
    local albumImage = albumPlaceholder
    
    local function isHovered(x1, y1, x2, y2)
        -- return if cursor is not in screen
        if not cursorX or not cursorY then
            return
        end
        
        -- block hover check if button is locked
        if isLocked and player() ~= owner() then
            return false
        end
        
        -- check if hovered
        if cursorX < x1 or cursorY < y1 or cursorX > x2 or cursorY > y2 then
            return false
        end
        return true
    end

    -- icons
    local icons = render.createMaterial(
        "https://github.com/Vactor0911/jukebox/releases/download/images-v1/Spotify.Icons.Set.png?v=1.7w",
        function(mat, _, _, _, layout)
            if mat ~= nil then
                layout(0, 0, 1000, 1000)
            end
        end)
        
    local iconUv = {}
    iconUv.Pause = { 0, 0.586, 0.107, 0.693 }
    iconUv.Play = { 0.195, 0.586, 0.302, 0.693 }
    iconUv.Prev = { 0, 0.489, 0.055, 0.552 }
    iconUv.Next = { 0.097, 0.489, 0.153, 0.552 }
    iconUv.Loop = { 0, 0.194, 0.065, 0.257 }
    iconUv.LoopSingle = { 0.0975, 0.194, 0.165, 0.257 }
    iconUv.Shuffle = { 0.194, 0, 0.265, 0.065 }
    iconUv.VolumeMute = { 0.198, 0.49, 0.258, 0.55 }
    iconUv.VolumeSmall = { 0.295, 0.49, 0.355, 0.55 }
    iconUv.VolumeMedium = { 0.391, 0.49, 0.451, 0.55 }
    iconUv.VolumeLarge = { 0.489, 0.49, 0.549, 0.55 }
    iconUv.Mute = { 0.197, 0.49, 0.257, 0.55 }
    iconUv.Lock = { 0.39, 0, 0.45, 0.06 }
    
    local function drawIcon(x, y, w, h, icon, color)
        -- calc color
        if color ~= nil then
            render.setColor(color)
        else
            if isHovered(x, y, x + w, y + h) then
                render.setColor(Color(255, 255, 255, 75))
            else
                render.setColor(Color(255, 255, 255, 255))
            end
        end
        
        -- get icon uv pos
        local uS, vS, uE, vE = unpack(iconUv[icon])
        local ratio = ((uE - uS) / (vE - vS))

        -- draw icon
        render.setMaterial(icons)
        render.drawTexturedRectUVFast(x, y, w * ratio, h, uS, vS, uE, vE, true)
    end

    -- updating data
    local function updateData(payload)
        local keys = table.getKeys(payload)
        for i, key in pairs(keys) do
            if key == "AlbumImageUrl" then
                -- process only id album image have to be changed
                if data.AlbumImageUrl == payload[key] then
                    continue
                end
                isStale = true
                
                -- destroy previous album cover image
                if isValid(albumImage) then
                    albumImage:destroy()
                end
                
                -- get new album cover image
                if payload[key] ~= "" then
                    local newAlbumImage = getAlbumImage(payload[key])
                    albumImage = newAlbumImage
                else
                    albumImage = albumPlaceholder
                end
            elseif key == "Ended" and payload[key] == 1 then
                albumImage = albumPlaceholder
            end

            data[key] = payload[key]
        end
    end

    -- check game ended
    local function isSongEnded()
        if data.Ended == 1 then
            return true
        elseif data.Playing == 0 and data.Paused == 0 and data.Ended == 0 then
            return true
        end

        return false
    end

    -- init data
    net.receive("init", function()
        local payload = net.readTable()
        updateData(payload)
    end)

    -- receive wirelink inputs
    net.receive("input", function()
        local payload = net.readTable()
        updateData(payload)
    end)
    
    -- receive update lock
    net.receive("sv_lock", function()
        if player() == owner() then
            return
        end
        
        local newLock = net.readBool()
        isLocked = newLock
    end)

    -- limiting fps
    local nf_center = timer.systime()
    local nf_center_fps_delta = 1 / 30
    local function limitFps()
        local now = timer.systime()
        if nf_center > now then
            return true
        end
        nf_center = now + nf_center_fps_delta
        return false
    end

    -- resetting stencil
    local function resetStencil()
        render.setStencilWriteMask(0xFF)
        render.setStencilTestMask(0xFF)
        render.setStencilReferenceValue(0)
        render.setStencilCompareFunction(STENCIL.ALWAYS)
        render.setStencilPassOperation(STENCIL.KEEP)
        render.setStencilFailOperation(STENCIL.KEEP)
        render.setStencilZFailOperation(STENCIL.KEEP)
        render.clearStencil()
    end

    -- draw rounded rect masking
    local function drawThumbnailMasking(r, x, y, w, h)
        render.drawRect(x + r, y, w - r * 2, h)
        render.drawRect(x, y + r, w, h - r * 2)
        render.drawFilledCircle(x + r, y + r, r)
        render.drawFilledCircle(x + w - r, y + r, r)
        render.drawFilledCircle(x + r, y + h - r, r)
        render.drawFilledCircle(x + w - r, y + h - r, r)
    end

    -- get cursor pos on screen
    local function getCursorOnScreen()
        if not isValid(screen) then
            return nil
        end

        local eyePos = player():getEyePos()
        local eyeDir = player():getEyeAngles():getForward()

        -- Ray-plane intersection (trace.trace is unreliable for flat holograms with X scale = 0)
        local normal = screen:getForward()
        local denom = normal:dot(eyeDir)
        if math.abs(denom) < 1e-6 then
            return nil
        end -- eye ray is parallel to screen

        local t = normal:dot(screen:getPos() - eyePos) / denom
        if t < 0 or t > 200 then
            return nil
        end -- screen is behind player or beyond 200 units

        local hitPos = eyePos + eyeDir * t

        -- world coordinates -> screen entity local coordinates
        local localPos = screen:worldToLocal(hitPos)

        -- local Y = horizontal, Z = vertical (range: -37.5 ~ 37.5 for SIZE = 75)
        local x = (0.5 - localPos.y / SIZE) * 1024
        local y = (0.5 - localPos.z / SIZE) * 1024

        -- out of screen bounds
        if x < 0 or x > 1024 or y < 0 or y > 1024 then
            return nil
        end

        return x, y
    end

    -- draw resizable text
    local function drawText(x, y, text, size, textAlign)
        local scale = size / 64
        local m = Matrix()
        m:translate(Vector(x, y))
        m:scale(Vector(scale, scale))

        render.pushMatrix(m)
        render.drawText(0, 0, text, textAlign)
        local textSize = render.getTextSize(text)
        render.popMatrix()

        return textSize * scale
    end
    
    -- draw screens
    local function drawStatic()
        -- draw blurred background image
        selectRenderTarget("static")
        render.setMaterial(albumImage)
        render.drawTexturedRect(-398.2, 0, 1820.4, 1024)

        -- draw gradient
        for i = 0, 9 do
            local t = 0.85 * (i / 9)
            local curved = t ^ (1 / 2)
            local alpha = math.floor(math.min(curved * 255, 255))
            local y = 1024 / 10 * i
            render.setColor(Color(0, 0, 0, alpha))
            render.drawRect(0, y, 1024, 1024 / 10)
        end

        render.drawBlurEffect(7, 7, 1)

        -- static components
        local width = 633
        local height = width / 16 * 9
        local padding = (1024 - width) * 0.5

        -- draw thumbnail
        selectRenderTarget("background")
        resetStencil()
        render.setStencilEnable(true)
        render.setStencilCompareFunction(STENCIL.NEVER)
        render.setStencilReferenceValue(1)
        render.setStencilFailOperation(STENCIL.EQUAL)

        drawThumbnailMasking(16, padding, 80, width, height)

        render.setStencilCompareFunction(STENCIL.EQUAL)
        render.setStencilFailOperation(STENCIL.NEVER)

        render.setMaterial(albumImage)
        render.drawTexturedRect(padding, 80, width, height)

        render.setStencilEnable(false)
        
        isStale = false
    end
    
    hook.add("RenderOffscreen", "", function()
        -- rotate screen
        if isValid(screen) then
            local angle = (player():getEyePos() - screen:getPos()):getAngle() + Angle(0, 180, 0)
            angle = angle:setP(0)
            screen:setAngles(angle)
        end
        
        -- get cursor pos
        cursorX, cursorY = getCursorOnScreen()
        
        selectRenderTarget("cursor")
        if cursorX then
            render.setColor(THEME)
            render.drawFilledCircle(cursorX, cursorY, 7)
        end
    end)

    hook.add("RenderOffscreen", "30hz", function()
        -- limit fps
        if limitFps() then
            return
        end
        
        -- rerender static & background
        if isStale then
            drawStatic()
        end
        
        -- draw ui
        selectRenderTarget("main")

        render.setRenderTargetTexture("static")
        render.drawTexturedRect(0, 0, 1024, 1024)
        
        render.setRenderTargetTexture("background")
        render.drawTexturedRect(0, 0, 1024, 1024)

        -- draw title & uploader
        render.setColor(Color(255, 255, 255))
        render.setFont(boldFont)

        resetStencil()
        render.setStencilEnable(true)
        render.setStencilCompareFunction(STENCIL.NEVER)
        render.setStencilReferenceValue(1)
        render.setStencilFailOperation(STENCIL.EQUAL)

        render.drawRect(60, 500, 768.5, 200)

        render.setStencilCompareFunction(STENCIL.EQUAL)
        render.setStencilFailOperation(STENCIL.NEVER)
        
        local currentTitle = isSongEnded() and "No Song Playing" or data.Title
        if currentTitle ~= titlePrev then
            titlePrev = currentTitle
            titleScrollOffset = 0
            titleScrollPhase = "pause_start"
            titleScrollPhaseTime = timer.systime()
            titleScrollOverflow = 0
        end

        local now = timer.systime()
        local elapsed = now - titleScrollPhaseTime

        if titleScrollOverflow > 0 then
            if titleScrollPhase == "pause_start" then
                if elapsed >= TITLE_SCROLL_PAUSE then
                    titleScrollPhase = "scrolling"
                    titleScrollPhaseTime = now
                end
            elseif titleScrollPhase == "scrolling" then
                titleScrollOffset = math.min(elapsed * TITLE_SCROLL_SPEED, titleScrollOverflow)
                if titleScrollOffset >= titleScrollOverflow then
                    titleScrollPhase = "pause_end"
                    titleScrollPhaseTime = now
                end
            elseif titleScrollPhase == "pause_end" then
                titleScrollOffset = titleScrollOverflow
                if elapsed >= TITLE_SCROLL_PAUSE then
                    titleScrollPhase = "pause_start"
                    titleScrollPhaseTime = now
                    titleScrollOffset = 0
                end
            end
        else
            titleScrollOffset = 0
        end

        local titleSize = drawText(60 - titleScrollOffset, 500, currentTitle, 74)
        if titleSize > 768.5 then
            titleScrollOverflow = titleSize - 768.5
        else
            titleScrollOverflow = 0
            titleScrollOffset = 0
        end
        render.setColor(Color(255, 255, 255, 200))
        local uploaderSize = drawText(60, 580, isSongEnded() and "/song {youtube url}" or data.Uploader, 56)

        render.setStencilEnable(false)

        -- progress bar
        render.setColor(Color(255, 255, 255, 100))
        render.drawRoundedBox(10, 60, 690, 904, 10)
        
        local isProgressBarHovered = isHovered(60, 670, 964, 720)

        if isProgressBarHovered and cursorX then
            -- progress bar preview
            render.setColor(Color(255, 255, 255, 255))
            render.drawRoundedBox(10, 60, 690, cursorX - 60, 10)
            
            -- time tooltip
            render.setColor(Color(40, 40, 40))
            render.drawRoundedBox(10, cursorX - 50, 630, 100, 50)
            
            render.setFont(regularFont)
            render.setColor(Color(255, 255, 255))
            local newTime = data.Length * ((cursorX - 60) / 904)
            drawText(cursorX - 44, 634, string.formattedTime(newTime, "%02d:%02d"), 40)
        end
        
        local playPercentage = data.Length ~= 0 and data.Time / data.Length or 0
        local progressBarWidth = 904 * playPercentage
        if isProgressBarHovered then
            render.setColor(THEME)
        else
            render.setColor(Color(255, 255, 255, 255))
        end
        render.drawRoundedBox(10, 60, 690, progressBarWidth, 10)

        render.setFont(regularFont)
        render.setColor(Color(255, 255, 255, 200))
        drawText(60, 722, string.formattedTime(data.Time, "%02d:%02d"), 45)
        drawText(964, 722, string.formattedTime(data.Length, "%02d:%02d"), 45, TEXT_ALIGN.RIGHT)

        -- progress ball
        if isProgressBarHovered then
            render.setColor(Color(255, 255, 255))
            local progressBallX = playPercentage * 904 + 60
            render.drawFilledCircle(progressBallX, 687 + 8, 12)
        end

        -- draw buttons
        -- play & pause
        local playIcon = data.Playing == 1 and "Pause" or "Play"
        drawIcon(424, 788, 176, 176, playIcon)

        -- prev song
        drawIcon(270, 821, 110, 110, "Prev")

        -- next song
        drawIcon(644, 821, 110, 110, "Next")

        -- loop
        local loopIcon = data.Loop == 2 and "LoopSingle" or "Loop"
        if data.Loop == 0 then
            drawIcon(798, 821, 110, 110, loopIcon)
        else
            drawIcon(798, 821, 110, 110, loopIcon, THEME)
        end

        -- shuffle
        drawIcon(116, 821, 110, 110, "Shuffle")

        -- volume
        if data.Volume <= 0 then
            drawIcon(884, 540, 80, 80, "VolumeMute")
        elseif data.Volume <= 0.33 then
            drawIcon(884, 540, 80, 80, "VolumeSmall")
        elseif data.Volume <= 0.66 then
            drawIcon(884, 540, 80, 80, "VolumeMedium")
        else
            drawIcon(884, 540, 80, 80, "VolumeLarge")            
        end
        
        -- volume bar
        if isHovered(884, 540, 964, 620) then
            isVolumeBarVisible = true
        elseif not isHovered(864, 200, 984, 620) then
            isVolumeBarVisible = false
        end
        
        if isVolumeBarVisible then
            render.setColor(Color(40, 40, 40))
            render.drawRoundedBox(20, 889, 250, 70, 260)
            
            render.setColor(Color(255, 255, 255, 100))
            render.drawRoundedBox(10, 919, 280, 10, 200)
            
            if cursorY then
                local clampedY = math.clamp(cursorY, 280, 480)
                render.setColor(Color(255, 255, 255))
                render.drawRoundedBox(10, 919, clampedY, 10, math.abs(clampedY - 480))
            end
            
            local clampedVolume = math.clamp(data.Volume, 0, 1)
            render.setColor(THEME)
            render.drawRoundedBox(10, 919, 480 - 200 * clampedVolume, 10, 200 * clampedVolume)
            
            render.setColor(Color(255, 255, 255))
            render.drawFilledCircle(924, 480 - 200 * clampedVolume, 12)
        end

        -- lock
        local lockColor = isLocked and THEME or nil
        drawIcon(60, 80, 80, 80, "Lock", lockColor)
        
        -- draw cursor
        render.setRenderTargetTexture("cursor")
        render.drawTexturedRect(0, 0, 1024, 1024)
        
        render.selectRenderTarget(nil)
        render.setMaterial(nil)
    end)
    
    local function sendButtonEvent(payload)
        net.start("button_event")
        net.writeTable(payload)
        net.send()
    end
    
    local lastPressTime = timer.systime()
    hook.add("KeyPress", "key_press", function(player, key)
        -- filter only E press event
        if key ~= IN_KEY.USE then
            return
        end
        
        -- validation cursor pos
        if not cursorX then
            return
        elseif cursorX < 0 or cursorX > 1024 then
            return
        end
        
        -- return if button locked
        if isLocked and player ~= owner() then
            return
        end
        
        -- return if player pressed key too fast
        if timer.systime() < lastPressTime + 0.1 then
            return
        end
        
        lastPressTime = timer.systime()
        
        -- play & pause
        if isHovered(424, 788, 424 + 176, 788 + 176) then
            if data.Playing == 1 then
                sendButtonEvent({Pause = 1})
                timer.create("cleaner", 0.1, 1, function()
                    sendButtonEvent({Pause = 0})
                end)
            else
                sendButtonEvent({Play = 1})
                timer.create("cleaner", 0.1, 1, function()
                    sendButtonEvent({Play = 0})
                end)
            end
        -- prev song
        elseif isHovered(270, 821, 270 + 110, 821 + 110) then
            sendButtonEvent({PlayPrev = 1})
            timer.create("cleaner", 0.1, 1, function()
                sendButtonEvent({PlayPrev = 0})
            end)
        -- next song
        elseif isHovered(644, 821, 644 + 110, 821 + 110) then
            sendButtonEvent({PlayNext = 1})
            timer.create("cleaner", 0.1, 1, function()
                sendButtonEvent({PlayNext = 0})
            end)
        -- change loop state
        elseif isHovered(798, 821, 798 + 110, 821 + 110) then
            local newLoopState = data.Loop + 1
            if newLoopState > 2 then
                newLoopState = newLoopState - 3
            end
            sendButtonEvent({Loop = newLoopState})
        -- change time
        elseif isHovered(60, 670, 964, 720) then
            local newTime = data.Length * ((cursorX - 60) / 904)
            sendButtonEvent({Time = newTime})
        -- change volume
        elseif isVolumeBarVisible and isHovered(889, 250, 889 + 70, 250 + 260) then
            local clampedY = math.clamp(cursorY, 280, 480)
            local newVolume = math.abs(clampedY - 480) / 200
            sendButtonEvent({Volume = newVolume})
        -- mute
        elseif isHovered(884, 540, 884 + 80, 540 + 80) then
            if data.Volume == 0 then
                sendButtonEvent({Volume = 0.2})
            else
                sendButtonEvent({Volume = 0})
            end
        -- lock
        elseif isHovered(60, 80, 60 + 80, 80 + 80) and player == owner() then
            isLocked = not isLocked
            net.start("cl_lock")
            net.writeBool(isLocked)
            net.send()
        end
    end)
end
