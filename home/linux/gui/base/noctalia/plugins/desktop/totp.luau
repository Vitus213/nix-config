local scripts = "~/.config/noctalia/scripts/totp/"
local refreshArgv = { noctalia.expandPath(scripts .. "totp.sh") }
local copyArgv = { noctalia.expandPath(scripts .. "totp-copy.sh") }
local selectArgv = { noctalia.expandPath(scripts .. "totp-select-copy.sh") }
local switchArgv = { noctalia.expandPath(scripts .. "totp-switch.sh") }
local pending = false
local allowedColors = { primary = true, tertiary = true, error = true }

local function textLimit()
    return if barWidget.isVertical() then 12 else 16
end

-- Count codepoints, not bytes, so Chinese service names remain valid UTF-8.
local function shorten(text, limit)
    local length = utf8.len(text)
    if length == nil then
        return nil
    end
    if length <= limit then
        return text
    end
    return string.sub(text, 1, utf8.offset(text, limit) - 1) .. "…"
end

local function present(text, glyph, tooltip, color)
    barWidget.setText(text)
    barWidget.setGlyph(glyph)
    barWidget.setTooltip(tooltip)
    barWidget.setColor(color)
    barWidget.setGlyphColor(color)
end

local function unavailable(reason)
    present(shorten("TOTP 不可用", textLimit()), "lock", reason, "error")
end

local function applyResult(result)
    if result.exitCode ~= 0 or result.timedOut or result.stdoutTruncated then
        unavailable("TOTP 脚本执行失败、超时或输出不完整")
        return
    end
    if type(result.stdout) ~= "string" then
        unavailable("TOTP 脚本未返回 JSON")
        return
    end

    local data = noctalia.json.decode(result.stdout)
    if type(data) ~= "table"
        or type(data.text) ~= "string"
        or type(data.icon) ~= "string"
        or type(data.tooltip) ~= "string"
        or type(data.color) ~= "string"
        or not allowedColors[data.color]
    then
        unavailable("TOTP 脚本返回的数据格式无效")
        return
    end

    -- The legacy script deliberately emits literal \\n inside JSON strings.
    local tooltip = string.gsub(data.tooltip, "\\n", "\n")
    local service, code = string.match(data.text, "^(.+) (%d%d%d%d%d%d)$")
    if service ~= nil then
        -- Always retain the separating space and all six code digits.
        local name = shorten(service, textLimit() - 7)
        if name == nil then
            unavailable("TOTP 服务名称不是有效 UTF-8")
            return
        end
        present(name .. " " .. code, data.icon, tooltip, data.color)
    elseif data.color == "error" then
        -- Script-level errors (missing/empty/invalid config) replace any old code.
        local text = shorten(data.text, textLimit())
        if text == nil or text == "" then
            unavailable("TOTP 脚本返回的错误信息无效")
            return
        end
        present(text, "lock", tooltip, "error")
    else
        unavailable("TOTP 脚本未返回完整六位验证码")
    end
end

function update()
    if pending then
        return
    end
    pending = true
    local started = noctalia.runAsync(refreshArgv, function(result)
        pending = false
        applyResult(result)
    end)
    if not started then
        pending = false
        unavailable("无法启动 TOTP 脚本")
    end
end

local function runAction(argv)
    -- No callback: detached, no output capture or 5-second capture timeout.
    -- In particular, the selection menu must survive until chosen/cancelled.
    if not noctalia.runAsync(argv) then
        unavailable("无法启动 TOTP 操作脚本")
    end
end

function onClick()
    runAction(copyArgv)
end

function onMiddleClick()
    runAction(selectArgv)
end

function onRightClick()
    runAction(switchArgv)
end

function onIpc(event, _payload)
    if event == "refresh" then
        update()
    elseif event == "copy" then
        onClick()
    elseif event == "select-copy" then
        onMiddleClick()
    elseif event == "switch" then
        onRightClick()
    end
end

noctalia.setUpdateInterval(1000)
barWidget.setFont("Maple Mono NF CN")
unavailable("正在读取 TOTP")
update()
