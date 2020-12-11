local strfmt = string.format
local tinsert = table.insert
local tconcat = table.concat
local strrep = string.rep
local type = type
local tonumber = tonumber
local tostring = tostring
local minser
local minser_number
local minser_string
local minser_table
local minser_reference
local minser_boolean
local minser_function
local minser_thread
local minser_userdata
local minser_nil
local minser_need_meta
local repr_indent
local repr_tab_value
local repr_tab_key
local repr_table

-- if you need to see metatable, set `need_meta` to `true`
local need_meta = false

--
-- @method repr_indent
-- @desc 序列化缩进
-- @param level number 缩进级数
-- @return string
--
function repr_indent(level)
    return strrep("  ", level)
end

--
-- @method repr_tab_value
-- @desc 序列化表元素
-- @param level number 缩进级数
-- @param key number/string 键名
-- @param value any 表元素
-- @return string
--
function repr_tab_value(level, key, value)
    return strfmt("\n%s%s = %s", repr_indent(level), key, value)
end

--
-- @method repr_tab_key
-- @desc 序列化表键名
-- @param key number/string 键名
-- @return string
--
function repr_tab_key(key)
    if type(key) == "number" then
        key = strfmt("[%s]", key)
    elseif tonumber(key) then
        key = strfmt('["%s"]', key)
    end
    return key
end

--
-- @method repr_table
-- @desc 序列化表
-- @param t table 表
-- @param level number 缩进级数
-- @return string
--
function repr_table(t, l)
    return strfmt("{%s\n%s}", tconcat(t, ","), repr_indent(l - 1))
end

--
-- @method minser_number
-- @desc 简化数值
-- @param v number 数值
-- @return string
--
function minser_number(v)
    return v
end

--
-- @method minser_boolean
-- @desc 简化布尔值
-- @param v boolean 布尔值
-- @return string
--
function minser_boolean(v)
    return tostring(v)
end

--
-- @method minser_string
-- @desc 简化字符串
-- @param v string 字符串
-- @return string
--
function minser_string(v)
    return strfmt([["%s"]], v)
end

--
-- @method minser_reference
-- @desc 简化重复引用
-- @return string
--
function minser_reference()
    return "@R"
end

--
-- @method minser_function
-- @desc 简化方法
-- @return string
--
function minser_function()
    return "@F"
end

--
-- @method minser_thread
-- @desc 简化协程
-- @return string
--
function minser_thread()
    return "@T"
end

--
-- @method minser_userdata
-- @desc 简化C数据结构
-- @return string
--
function minser_userdata()
    return "@U"
end

--
-- @method minser_nil
-- @desc 简化空值
-- @return string
--
function minser_nil()
    return "@NULL"
end

--
-- @method minser_table
-- @desc 简化Lua表
-- @param v table Lua表
-- @param lookup table 已经引用的表
-- @param level number 缩进级数
-- @return string
--
function minser_table(v, lookup, level)
    local t = {}
    lookup = lookup or {}
    level = level or 1

    -- 添加表到重复引用字典
    local function __add_lookup_dict(tab)
        lookup[tostring(tab)] = true
    end

    -- 检查表是否已经存在于重复字典中
    local function __exist_in_dict(tab)
        return lookup[tostring(tab)]
    end

    -- 添加数据到最终返回结果列表中
    local function __add_result_list(l, k, r)
        tinsert(t, repr_tab_value(l, k, r))
    end

    -- 处理需要元表的情况
    if need_meta then
        -- 元表需要添加到重复字典中，以免造成堆栈溢出
        local m = getmetatable(v)
        if m and m ~= v and type(m) == "table" and not __exist_in_dict(m) then
            __add_result_list(level, "@M", minser_table(m, lookup, level + 1))
            __add_lookup_dict(m)
        end
    end

    -- 添加当前表到重复字典中
    __add_lookup_dict(v)

    -- 处理表元素
    for k, j in pairs(v) do
        k = repr_tab_key(k)
        if type(j) == "table" then
            -- 当表元素是表时
            if __exist_in_dict(j) then
                -- 当元素已存在于重复字典时，返回重复索引
                __add_result_list(level, k, minser_reference(j))
            else
                -- 当元素不存在重复字典时，再入简化表
                __add_lookup_dict(j)
                __add_result_list(level, k, minser_table(j, lookup, level + 1))
            end
        else
            -- 当表元素不是表时
            __add_result_list(level, k, minser(j))
        end
    end
    return repr_table(t, level)
end

--
-- @method minser
-- @desc 简化Lua数据
-- @param v any Lua数据
-- @param minify boolean 是否需要最简化
-- @return string
--
function minser(v, minify)
    local t = type(v)
    minify = not (not minify)
    if t == "table" then
        v = minser_table(v)
        if minify then
            v = v:gsub("%s", "")
        end
    elseif t == "number" then
        v = minser_number(v)
    elseif t == "string" then
        v = minser_string(v)
    elseif t == "boolean" then
        v = minser_boolean(v)
    elseif t == "thread" then
        v = minser_thread(v)
    elseif t == "userdata" then
        v = minser_userdata(v)
    elseif t == "nil" then
        v = minser_nil()
    elseif t == "function" then
        v = minser_function(v)
    end
    return v
end

return minser
