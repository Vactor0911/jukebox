--@name Spotify UI
--@author Vactor0911
--@client

-- settings
local ALLOW_UI = true
local WIDTH = 75
local HEIGHT = 75

local regularFont = render.createFont("Arial", 64, 500)
local boldFont = render.createFont("Arial", 64, 900)

local img = render.createMaterial("https://jukebox.vactor0911.dev/musics/e1140b51-a05f-4fb5-8f8d-668ee9044d19.jpg",
    function(mat, _, _, _, layout)
        if mat ~= nil then
            layout(0, 0, 1024, 1024)
        end
    end)
local icons = render.createMaterial(
    "https://github.com/Vactor0911/jukebox/releases/download/images-v1/Spotify.Icons.Set.png?v=1.5w",
    function(mat, _, _, _, layout)
        if mat ~= nil then
            layout(0, 0, 1000, 1000)
        end
    end)

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

local iconUv = {}
iconUv.Pause = { 0, 0.586, 0.107, 0.693 }
iconUv.Prev = { 0, 0.489, 0.055, 0.552 }
iconUv.Next = { 0.097, 0.489, 0.153, 0.552 }
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
    render.popMatrix()
end

render.createRenderTarget("main")
render.createRenderTarget("dynamic")
render.createRenderTarget("static")
render.createRenderTarget("background")

local screen
if ALLOW_UI then
    local screenMat = material.create("UnlitGeneric")
    screenMat:setTextureRenderTarget("$basetexture", "main")
    screenMat:setInt("$flags", 0)

    screen = hologram.create(chip():getPos() + Vector(0, 0, HEIGHT * 0.5 + 10), chip():getAngles(),
        "models/starfall/holograms/box.mdl",
        Vector(0, WIDTH, HEIGHT))
    screen:setMaterial("!" .. screenMat:getName())
    screen:setParent(chip())
end

timer.create("interval", 0.05, 0, function()
    if isValid(screen) then
        local angle = (player():getEyePos() - screen:getPos()):getAngle()
        --screen:setAngles(angle)
    end
end)

hook.add("RenderOffscreen", "30hz", function()
    if not ALLOW_UI then
        return
    end

    limitFps()

    render.clear(Color(0, 0, 0, 0))
    render.setColor(Color(255, 255, 255, 255))

    -- draw blurred background image
    selectRenderTarget("background")
    render.setMaterial(img)
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
    local width = 720
    local height = width / 16 * 9
    local padding = (1024 - width) * 0.5
    selectRenderTarget("static")

    -- draw thumbnail
    resetStencil()
    render.setStencilEnable(true)
    render.setStencilCompareFunction(STENCIL.NEVER)
    render.setStencilReferenceValue(1)
    render.setStencilFailOperation(STENCIL.EQUAL)

    drawThumbnailMasking(16, padding, 20, width, height)

    render.setStencilCompareFunction(STENCIL.EQUAL)
    render.setStencilFailOperation(STENCIL.NEVER)

    render.setMaterial(img)
    render.drawTexturedRect(padding, 20, width, height)

    render.setStencilEnable(false)

    -- draw title & uploader
    render.setColor(Color(255, 255, 255))
    render.setFont(boldFont)

    drawText(0, 500, "真夜中のドア", 84)
    render.setColor(Color(255, 255, 255, 200))
    drawText(0, 584, "Miki Matsubara", 64)

    -- progress bar
    render.setColor(Color(255, 255, 255, 120))
    render.drawRoundedBox(5, 0, 713, 1024, 10)

    render.setFont(regularFont)
    render.setColor(Color(255, 255, 255, 200))
    drawText(0, 745, http.urlDecode("0:03"), 52)
    drawText(1024, 745, http.urlDecode("3:09"), 52, TEXT_ALIGN.RIGHT)

    -- draw buttons
    render.setColor(Color(255, 255, 255))
    drawIcon(512 - 100, 1024 - 200, 200, 200, "Pause")

    drawIcon(512 - 100 - 125 - 50, 1024 - 100 - 62.5, 125, 125, "Prev")

    drawIcon(512 + 100 + 50, 1024 - 100 - 62.5, 125, 125, "Next")

    -- main
    selectRenderTarget("main")

    render.setRenderTargetTexture("background")
    render.drawTexturedRect(0, 0, 1024, 1024)

    render.setRenderTargetTexture("static")
    render.drawTexturedRect(60, 60, 904, 904)

    -- progress ball
    render.setColor(Color(255, 255, 255))
    render.drawFilledCircle(60, 682 - 6 - 8 + 26, 12)

    render.selectRenderTarget(nil)
    render.setMaterial(nil)
end)
