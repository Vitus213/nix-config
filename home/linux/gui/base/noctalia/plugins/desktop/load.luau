function update()
    local stats = noctalia.systemStats()
    local averages = if stats ~= nil then stats.loadAvg else nil
    if stats == nil or stats.sampledAtMs == nil or type(averages) ~= "table"
        or type(averages[1]) ~= "number"
        or type(averages[2]) ~= "number"
        or type(averages[3]) ~= "number"
    then
        barWidget.setText("—")
        barWidget.setTooltip("系统负载暂无样本")
        return
    end

    barWidget.setText(string.format("%.1f", averages[1]))
    barWidget.setTooltip(string.format(
        "系统负载\n1 分钟: %.2f\n5 分钟: %.2f\n15 分钟: %.2f",
        averages[1], averages[2], averages[3]
    ))
end

noctalia.setUpdateInterval(2000)
barWidget.setFont("Maple Mono NF CN")
barWidget.setGlyph("cpu")
update()
