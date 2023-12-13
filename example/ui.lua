local M = {}

local ZERO_V = vmath.vector3(0)

local function init(tree, actions, name, el_data, parent)
    if name == "type" then
        return
    end
    local el = {}
    tree[name] = el
    el.name = name
    el.parent = parent
    if M.is_button(el, actions) then
        name = name.."/".."larrybutton"
        el.type = "button"
    else
        el.type = el_data.type
    end
    el.node = gui.get_node(name)
    el.enabled = true
    if el.type == "page" then
        M.enable(el, false)
        gui.set_position(el.node, ZERO_V)
    end
end

function M.is_button(el, actions)
    return actions and actions[el.name] or el.type == "button"
end

function M.enable(el, enabled)
    el.enabled = enabled
    gui.set_enabled(el.node, enabled)
end

function M.disable_all(tree, type)
    for _, el in pairs(tree) do
        if el.type == type then
            M.enable(el, false)
        end
    end
end

function M.is_enabled(el)
    if el.parent then 
        return el.enabled and M.is_enabled(el.parent) 
    end
    return el.enabled
end

function M.fill_tree(data, actions)
    local tree = {}
    for pk, page in pairs(data) do -- pk = "main_page", page = { type = "page", ["mediation_debugger"] = {}, ["interstitial"] = {} }
        init(tree, actions, pk, page)
        for ek, element in pairs(page) do 
            init(tree, actions, ek, element, tree[pk])
        end
    end
    return tree
end

return M
