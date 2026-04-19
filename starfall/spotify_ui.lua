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
        { "Title", "Uploader", "AlbumImageUrl", "Playing", "Loading", "Paused", "Ended", "Time", "Length", "Loop",
            "Shuffle" },
        { "string", "string", "string", "n", "n", "n", "n", "n", "n", "n", "n" }
    )

    -- 0.2s delay for client initialize
    timer.create("delay", 0.2, 1, function()
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
    data.Time = 0
    data.Length = 0
    data.Loop = 0
    data.Shuffle = 0
    local screen

    -- album images
    local albumPlaceholder = render.createMaterial("https://jukebox.vactor0911.dev/musics/Image.png",
        function(mat, _, _, _, layout)
            if mat ~= nil then
                layout(0, 0, 1024, 1024)
            end
        end)
    local albumImage = albumPlaceholder

    -- theme color
    local THEME = Color(30, 215, 96)

    -- functions
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
            end)
        return image
    end

    local function updateData(payload)
        local keys = table.getKeys(payload)
        for i, key in pairs(keys) do
            if key == "AlbumImageUrl" then
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

    -- fonts
    local regularFont = render.createFont("Arial", 64, 500)
    local boldFont = render.createFont("Arial", 64, 900)

    -- icons
    local icons = render.createMaterial(
        "https://github.com/Vactor0911/jukebox/releases/download/images-v1/Spotify.Icons.Set.png?v=1.6w",
        function(mat, _, _, _, layout)
            if mat ~= nil then
                layout(0, 0, 1000, 1000)
            end
        end)

    -- title scroll animation
    local TITLE_SCROLL_SPEED = 100         -- pixels per second
    local TITLE_SCROLL_PAUSE = 3           -- seconds before and after scrolling
    local titleScrollOffset = 0
    local titleScrollPhase = "pause_start" -- "pause_start", "scrolling", "pause_end"
    local titleScrollPhaseTime = timer.systime()
    local titleScrollOverflow = 0
    local titlePrev = ""

    -- limiting fps
    local nf_center = timer.systime()
    local nf_center_fps_delta = 1 / 30
    local function limitFps()
        local now = timer.systime()
        if nf_center > now then return end
        nf_center = now + nf_center_fps_delta
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

    local function selectRenderTarget(name)
        render.selectRenderTarget(name)
        render.clear(Color(0, 0, 0, 0))
        render.setColor(Color(255, 255, 255, 255))
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

    local iconUv = {}
    iconUv.Pause = { 0, 0.586, 0.107, 0.693 }
    iconUv.Prev = { 0, 0.489, 0.055, 0.552 }
    iconUv.Next = { 0.097, 0.489, 0.153, 0.552 }
    iconUv.Loop = { 0, 0.194, 0.065, 0.257 }
    iconUv.LoopSingle = { 0.0975, 0.194, 0.165, 0.257 }
    iconUv.Shuffle = { 0.194, 0, 0.265, 0.065 }
    iconUv.Volume = { 0.295, 0.49, 0.355, 0.55 }
    iconUv.Mute = { 0.197, 0.49, 0.257, 0.55 }
    iconUv.Lock = { 0.39, 0, 0.45, 0.06 }
    local function drawIcon(x, y, w, h, icon)
        local uS, vS, uE, vE = unpack(iconUv[icon])
        local ratio = ((uE - uS) / (vE - vS))

        render.setMaterial(icons)
        render.drawTexturedRectUVFast(x, y, w * ratio, h, uS, vS, uE, vE, true)
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

    render.createRenderTarget("main")
    render.createRenderTarget("dynamic")
    render.createRenderTarget("static")
    render.createRenderTarget("background")

    local screenMat = material.create("UnlitGeneric")
    screenMat:setTextureRenderTarget("$basetexture", "main")
    screenMat:setInt("$flags", 0)

    screen = hologram.create(chip():getPos() + Vector(0, 0, SIZE * 0.5 + 10), chip():getAngles(),
        "models/starfall/holograms/box.mdl",
        Vector(0, SIZE, SIZE))
    screen:setMaterial("!" .. screenMat:getName())
    screen:setParent(chip())

    hook.add("RenderOffscreen", "30hz", function()
        limitFps()

        -- rotate screen
        if isValid(screen) then
            local angle = (player():getEyePos() - screen:getPos()):getAngle() + Angle(0, 180, 0)
            angle = angle:setP(0)
            screen:setAngles(angle)
        end

        -- get cursor pos
        cursorX, cursorY = getCursorOnScreen()

        -- reset screen & color
        render.clear(Color(0, 0, 0, 0))
        render.setColor(Color(255, 255, 255, 255))

        -- draw blurred background image
        selectRenderTarget("background")
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
        selectRenderTarget("static")

        -- draw thumbnail
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

        -- title scroll animation
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
        render.setColor(Color(255, 255, 255, 120))
        render.drawRoundedBox(10, 60, 690, 904, 10)

        local playPercentage = data.Length ~= 0 and data.Time / data.Length or 0
        local progressBarWidth = 904 * playPercentage
        render.setColor(Color(255, 255, 255, 255))
        render.drawRoundedBox(10, 60, 690, progressBarWidth, 10)

        render.setFont(regularFont)
        render.setColor(Color(255, 255, 255, 200))
        drawText(60, 722, string.formattedTime(data.Time, "%02d:%02d"), 45)
        drawText(964, 722, string.formattedTime(data.Length, "%02d:%02d"), 45, TEXT_ALIGN.RIGHT)

        -- progress ball
        render.setColor(Color(255, 255, 255))
        local progressBallX = playPercentage * 904 + 60
        render.drawFilledCircle(progressBallX, 687 + 8, 12)

        -- draw buttons
        render.setColor(Color(255, 255, 255))
        drawIcon(512 - 88, 1024 - 176 - 60, 176, 176, "Pause")

        drawIcon(512 - 88 - 110 - 44, 1024 - 88 - 55 - 60, 110, 110, "Prev")

        drawIcon(512 + 88 + 44, 1024 - 88 - 55 - 60, 110, 110, "Next")

        render.setColor(data.Loop == 0 and Color(255, 255, 255) or THEME)
        local loopIcon = data.Loop == 2 and "LoopSingle" or "Loop"
        drawIcon(512 + 88 + 44 + 44 + 110, 1024 - 88 - 55 - 60, 110, 110, loopIcon)

        render.setColor(Color(255, 255, 255))
        drawIcon(512 - 88 - 110 - 44 - 44 - 110, 1024 - 88 - 55 - 60, 110, 110, "Shuffle")

        drawIcon(1024 - 80 - 60, 580 - 40, 80, 80, "Volume")

        drawIcon(60, 80, 80, 80, "Lock")

        -- main
        selectRenderTarget("main")

        render.setRenderTargetTexture("background")
        render.drawTexturedRect(0, 0, 1024, 1024)

        render.setRenderTargetTexture("static")
        render.drawTexturedRect(0, 0, 1024, 1024)

        if cursorX then
            render.setColor(THEME)
            render.drawFilledCircle(cursorX, cursorY, 7)
        end

        render.selectRenderTarget(nil)
        render.setMaterial(nil)
    end)
end
