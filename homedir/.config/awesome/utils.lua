local utils = {}

utils.format_bar_entry = 
function ( label, value, color, font )
    color = color or '#46AEDE'
    font = font or ''
    
    local markup = string.format(" <span font_desc=%q color=%q>%s</span> %s ", font, color, label, value)
    return markup
end

utils.get_key = 
function ( table, ivalue )
    wanted = nil
    for key, val in pairs(table)
    do
        if val == ivalue 
        then 
            wanted = key 
        end
    end
    return wanted
end

return utils
