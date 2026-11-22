-- 保存前的 Lua 静态审计。
-- 负责词法扫描、当前文件符号分析、工程级定义索引和可注册的库清单。
-- 只对高置信问题给出自动补全，未知全局变量只提示，不擅自修改代码。

local M = {}

local KEYWORDS = {
  ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
  ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
  ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
  ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
  ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
  ["until"] = true, ["while"] = true,
}

-- 引擎注入、Lua 标准库和 LuaJava import 后常见的名字。
-- 这些名字不能当成“缺少 require”，否则审计会产生大量误报。
local ENGINE_GLOBALS = {
  ["_G"] = true, ["_VERSION"] = true, ["_ENV"] = true,
  ["assert"] = true, ["collectgarbage"] = true, ["dofile"] = true,
  ["error"] = true, ["getmetatable"] = true, ["ipairs"] = true,
  ["load"] = true, ["loadfile"] = true, ["next"] = true, ["pairs"] = true,
  ["pcall"] = true, ["print"] = true, ["rawequal"] = true, ["rawget"] = true,
  ["rawlen"] = true, ["rawset"] = true, ["require"] = true, ["select"] = true,
  ["setmetatable"] = true, ["tonumber"] = true, ["tostring"] = true,
  ["type"] = true, ["unpack"] = true, ["xpcall"] = true, ["module"] = true,
  ["string"] = true, ["table"] = true, ["math"] = true, ["io"] = true,
  ["os"] = true, ["coroutine"] = true, ["debug"] = true, ["utf8"] = true,
  ["package"] = true, ["arg"] = true, ["self"] = true, ["this"] = true,
  ["activity"] = true, ["context"] = true, ["R"] = true, ["import"] = true,
  ["luajava"] = true, ["LuaActivity"] = true, ["LuaEditor"] = true,
  ["LuaUtil"] = true, ["LuaError"] = true, ["File"] = true,
  ["FileInputStream"] = true, ["FileOutputStream"] = true,
  ["Environment"] = true, ["Build"] = true, ["Toast"] = true,
  ["View"] = true, ["ViewGroup"] = true, ["LinearLayout"] = true,
  ["FrameLayout"] = true, ["RelativeLayout"] = true, ["TextView"] = true,
  ["EditText"] = true, ["Button"] = true, ["ImageView"] = true,
  ["ImageButton"] = true, ["ScrollView"] = true, ["ListView"] = true,
  ["RecyclerView"] = true, ["Adapter"] = true, ["Intent"] = true,
  ["Bundle"] = true, ["Handler"] = true, ["Looper"] = true,
  ["Runnable"] = true, ["Color"] = true, ["ColorFilter"] = true,
  ["PorterDuff"] = true, ["PorterDuffColorFilter"] = true,
  ["GradientDrawable"] = true, ["Drawable"] = true, ["Bitmap"] = true,
  ["BitmapFactory"] = true, ["Canvas"] = true, ["Paint"] = true,
  ["Typeface"] = true, ["Gravity"] = true, ["MotionEvent"] = true,
  ["KeyEvent"] = true, ["AlertDialog"] = true,
  ["TextUtils"] = true, ["TextUtil"] = true, ["HorizontalScrollView"] = true,
  ["TextWatcher"] = true, ["InputType"] = true, ["CompoundButton"] = true,
  ["VerticalScrollBar"] = true, ["Scroller"] = true, ["Rect"] = true,
  ["Path"] = true, ["Shader"] = true, ["LinearGradient"] = true,
  ["RadialGradient"] = true, ["ColorDrawable"] = true,
  ["BitmapDrawable"] = true, ["StateListDrawable"] = true,
  ["LayerDrawable"] = true, ["Animation"] = true, ["ObjectAnimator"] = true,
  ["ValueAnimator"] = true, ["Window"] = true, ["WindowManager"] = true,
  ["Dialog"] = true, ["DialogInterface"] = true, ["PopupWindow"] = true,
  ["Menu"] = true, ["MenuItem"] = true, ["Context"] = true,
  ["Application"] = true, ["Activity"] = true, ["Fragment"] = true,
  ["LayoutInflater"] = true, ["Editor"] = true, ["Message"] = true,
  ["Thread"] = true, ["StringBuilder"] = true, ["String"] = true,
  ["Integer"] = true, ["Long"] = true, ["Float"] = true, ["Double"] = true,
  ["Boolean"] = true, ["Object"] = true, ["System"] = true, ["Math"] = true,
  ["Arrays"] = true, ["Collections"] = true, ["ArrayList"] = true,
  ["HashMap"] = true, ["List"] = true, ["Map"] = true, ["Set"] = true,
  ["MaterialAlertDialogBuilder"] = true, ["SharedPreferences"] = true,
  ["Settings"] = true, ["Uri"] = true, ["MediaStore"] = true,
  ["DisplayMetrics"] = true, ["LayoutParams"] = true,
  ["android"] = true, ["java"] = true, ["javax"] = true, ["dalvik"] = true,
  ["org"] = true, ["com"] = true, ["kotlin"] = true,
}

local DEFAULT_LIBRARIES = {
  { name = "ui", module = "luaxplus.ui", description = "LuaX-UI 组件库" },
  { name = "theme", module = "luaxplus.theme", description = "主题与配色" },
  { name = "icons", module = "luaxplus.icons", description = "图标与着色" },
  { name = "pkgname", module = "luaxplus.pkgname", description = "包名生成" },
  { name = "lint", module = "luaxplus.lint", description = "保存前审计" },
}

local libraries = {}
local libraryOrder = {}
local loadedManifests = {}
local currentProjectRoot = nil

local function normalizePath(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function basename(path)
  return normalizePath(path):match("([^/]+)$") or tostring(path or "")
end

local function shellQuote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function readFile(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function listLuaFiles(root)
  root = normalizePath(root)
  if root == "" then
    return {}
  end

  local result = {}
  local FileClass = rawget(_G, "File")
  if FileClass then
    local ok = pcall(function()
      local directory = FileClass(root)
      if not directory or not directory.isDirectory() then
        return
      end
      local function walk(path)
        local children = FileClass(path).listFiles()
        if not children then
          return
        end
        for index = 0, #children - 1 do
          local item = children[index]
          if item.isDirectory() then
            local name = item.getName()
            if name ~= ".git" and name ~= "build" and name ~= ".gradle" then
              walk(item.getAbsolutePath())
            end
          elseif item.getName():lower():match("%.lua$") then
            result[#result + 1] = item.getAbsolutePath()
          end
        end
      end
      walk(root)
    end)
    if ok then
      return result
    end
  end

  local pipe = io.popen("find " .. shellQuote(root) .. " -type f -name '*.lua' -print 2>/dev/null")
  if pipe then
    for path in pipe:lines() do
      result[#result + 1] = path
    end
    pipe:close()
  end
  return result
end

local function addLibrary(spec, source)
  if type(spec) ~= "table" or type(spec.name) ~= "string" or spec.name == "" then
    return false
  end
  if type(spec.module) ~= "string" or spec.module == "" then
    return false
  end
  local name = spec.name
  local existing = libraries[name]
  if existing and existing.explicit and not spec.explicit then
    return false
  end
  local record = {
    name = name,
    module = spec.module,
    description = spec.description or "",
    aliases = spec.aliases,
    exports = spec.exports,
    explicit = spec.explicit == true,
    source = source,
    ambiguous = spec.ambiguous == true,
  }
  libraries[name] = record
  if not libraryOrder[name] then
    libraryOrder[#libraryOrder + 1] = name
  end
  return true
end

function M.resetLibraries()
  libraries = {}
  libraryOrder = {}
  loadedManifests = {}
  currentProjectRoot = nil
  for _, spec in ipairs(DEFAULT_LIBRARIES) do
    local copy = {
      name = spec.name,
      module = spec.module,
      description = spec.description,
      explicit = true,
    }
    addLibrary(copy, "builtin")
  end
end

function M.registerLibrary(spec)
  if type(spec) ~= "table" then
    return false
  end
  local copy = {
    name = spec.name,
    module = spec.module,
    description = spec.description,
    aliases = spec.aliases,
    exports = spec.exports,
    explicit = spec.explicit ~= false,
  }
  return addLibrary(copy, "api")
end

function M.lookupLibrary(name)
  local library = libraries[name]
  if library and not library.ambiguous then
    return library
  end
  return nil
end

function M.libraryList()
  local result = {}
  for _, name in ipairs(libraryOrder) do
    result[#result + 1] = libraries[name]
  end
  return result
end

local function loadManifest(path)
  path = normalizePath(path)
  if loadedManifests[path] then
    return 0
  end
  loadedManifests[path] = true
  local chunk = loadfile(path)
  if not chunk then
    return 0
  end
  local ok, value = pcall(chunk)
  if not ok then
    return 0
  end
  local list = value
  if type(list) == "table" and type(list.libraries) == "table" then
    list = list.libraries
  end
  if type(list) ~= "table" then
    return 0
  end
  local count = 0
  for _, spec in ipairs(list) do
    local copy = {
      name = spec.name,
      module = spec.module,
      description = spec.description,
      aliases = spec.aliases,
      exports = spec.exports,
      explicit = true,
    }
    if addLibrary(copy, path) then
      count = count + 1
    end
  end
  return count
end

local function moduleAlias(modulePath)
  local name = tostring(modulePath or ""):match("([^%.]+)$") or ""
  if name == "init" then
    local parent = tostring(modulePath or ""):match("([^%.]+)%.init$")
    if parent then
      name = parent
    end
  end
  return name
end

local function discoverLibraries(root)
  root = normalizePath(root)
  local candidates = {}
  local aliases = {}

  for _, directory in ipairs({ root .. "/lua", root .. "/lib" }) do
    for _, path in ipairs(listLuaFiles(directory)) do
      local relative = normalizePath(path):sub(#directory + 2)
      local modulePath = relative:gsub("/", "."):gsub("%.lua$", "")
      modulePath = modulePath:gsub("%.init$", "")
      if modulePath ~= "lint-libs" and modulePath ~= "lint" then
        local alias = moduleAlias(modulePath)
        if alias ~= "" then
          candidates[#candidates + 1] = {
            name = alias,
            module = modulePath,
            explicit = false,
          }
          aliases[alias] = (aliases[alias] or 0) + 1
        end
      end
    end
  end

  for _, spec in ipairs(candidates) do
    if aliases[spec.name] == 1 and not libraries[spec.name] then
      addLibrary(spec, "discover")
    end
  end
end

-- 自研库接入点：
-- 1. 在项目 lua/lint-libs.lua 返回库清单；
-- 2. 或把库文件放在项目 lua/ 或 lib/ 下，审计会按文件名自动发现；
-- 3. 也可以直接调用 Lint.registerLibrary({ name=..., module=... })。
local function clearProjectLibraries()
  local nextOrder = {}
  for _, name in ipairs(libraryOrder) do
    local library = libraries[name]
    if library and (library.source == "builtin" or library.source == "api") then
      nextOrder[#nextOrder + 1] = name
    else
      libraries[name] = nil
    end
  end
  libraryOrder = nextOrder
  loadedManifests = {}
end

function M.loadProjectLibraries(root)
  root = normalizePath(root)
  if root == "" then
    return 0
  end
  if currentProjectRoot and currentProjectRoot ~= root then
    clearProjectLibraries()
  end
  currentProjectRoot = root
  local count = 0
  for _, path in ipairs({ root .. "/lua/lint-libs.lua", root .. "/lint-libs.lua" }) do
    count = count + loadManifest(path)
  end
  discoverLibraries(root)
  return count
end

local function isNameStart(ch)
  return ch:match("[A-Za-z_]") ~= nil
end

local function isNameChar(ch)
  return ch:match("[A-Za-z0-9_]") ~= nil
end

local function longBracketAt(source, index)
  if source:sub(index, index) ~= "[" then
    return nil
  end
  local cursor = index + 1
  while source:sub(cursor, cursor) == "=" do
    cursor = cursor + 1
  end
  if source:sub(cursor, cursor) ~= "[" then
    return nil
  end
  return cursor - index - 1, cursor + 1
end

local function findLongBracketEnd(source, contentStart, level)
  local closing = "]" .. string.rep("=", level) .. "]"
  local first, last = source:find(closing, contentStart, true)
  if not first then
    return #source + 1, source:sub(contentStart)
  end
  return last + 1, source:sub(contentStart, first - 1)
end

local function tokenize(source)
  local tokens = {}
  local index = 1
  local line = 1
  local column = 1
  local length = #source

  local function advanceTo(target)
    while index < target do
      local ch = source:sub(index, index)
      if ch == "\r" then
        if source:sub(index + 1, index + 1) == "\n" then
          index = index + 1
        end
        line = line + 1
        column = 1
      elseif ch == "\n" then
        line = line + 1
        column = 1
      else
        column = column + 1
      end
      index = index + 1
    end
  end

  local function add(kind, value, startOffset, startLine, startColumn, endOffset)
    tokens[#tokens + 1] = {
      type = kind,
      value = value,
      offset = startOffset,
      endOffset = endOffset,
      line = startLine,
      column = startColumn,
    }
  end

  while index <= length do
    local ch = source:sub(index, index)

    if ch == "\r" or ch == "\n" then
      advanceTo(index + 1)
    elseif ch == " " or ch == "\t" or ch == "\f" or ch == "\v" then
      advanceTo(index + 1)
    elseif ch == "-" and source:sub(index + 1, index + 1) == "-" then
      local after = index + 2
      local level, contentStart = longBracketAt(source, after)
      if level then
        local target = findLongBracketEnd(source, contentStart, level)
        advanceTo(target)
      else
        local target = source:find("[\r\n]", index + 2)
        advanceTo(target or (length + 1))
      end
    elseif ch == "'" or ch == "\"" then
      local quote = ch
      local startOffset, startLine, startColumn = index, line, column
      local cursor = index + 1
      local content = {}
      while cursor <= length do
        local current = source:sub(cursor, cursor)
        if current == "\\" then
          content[#content + 1] = source:sub(cursor, cursor + 1)
          cursor = cursor + 2
        elseif current == quote then
          cursor = cursor + 1
          break
        else
          content[#content + 1] = current
          cursor = cursor + 1
        end
      end
      add("string", table.concat(content), startOffset, startLine, startColumn, cursor - 1)
      advanceTo(cursor)
    elseif ch == "[" then
      local level, contentStart = longBracketAt(source, index)
      if level then
        local startOffset, startLine, startColumn = index, line, column
        local target, content = findLongBracketEnd(source, contentStart, level)
        add("string", content, startOffset, startLine, startColumn, target - 1)
        advanceTo(target)
      else
        add("symbol", ch, index, line, column, index)
        advanceTo(index + 1)
      end
    elseif isNameStart(ch) then
      local startOffset, startLine, startColumn = index, line, column
      local cursor = index + 1
      while cursor <= length and isNameChar(source:sub(cursor, cursor)) do
        cursor = cursor + 1
      end
      local value = source:sub(index, cursor - 1)
      add(KEYWORDS[value] and "keyword" or "name", value, startOffset, startLine, startColumn, cursor - 1)
      advanceTo(cursor)
    elseif ch:match("%d") then
      local startOffset, startLine, startColumn = index, line, column
      local cursor = index + 1
      while cursor <= length and source:sub(cursor, cursor):match("[%w_%.]") do
        cursor = cursor + 1
      end
      add("number", source:sub(index, cursor - 1), startOffset, startLine, startColumn, cursor - 1)
      advanceTo(cursor)
    else
      local startOffset, startLine, startColumn = index, line, column
      local three = source:sub(index, index + 2)
      local two = source:sub(index, index + 1)
      if three == "..." then
        add("symbol", three, startOffset, startLine, startColumn, index + 2)
        advanceTo(index + 3)
      elseif two == ".." or two == "==" or two == "~=" or two == "<="
          or two == ">=" or two == "::" or two == "//" or two == "<<" or two == ">>" then
        add("symbol", two, startOffset, startLine, startColumn, index + 1)
        advanceTo(index + 2)
      else
        add("symbol", ch, startOffset, startLine, startColumn, index)
        advanceTo(index + 1)
      end
    end
  end

  return tokens
end

local function tokenValue(tokens, index)
  local token = tokens[index]
  return token and token.value or nil
end

local function isProperty(tokens, index)
  local previous = tokenValue(tokens, index - 1)
  return previous == "." or previous == ":"
end

local function isTableKey(tokens, index)
  local nextValue = tokenValue(tokens, index + 1)
  local previous = tokenValue(tokens, index - 1)
  return nextValue == "=" and (previous == "{" or previous == "," or previous == ";")
end

local function isLabel(tokens, index)
  return tokenValue(tokens, index - 1) == "::" and tokenValue(tokens, index + 1) == "::"
end

local function isGotoTarget(tokens, index)
  return tokenValue(tokens, index - 1) == "goto"
end

local function isMember(tokens, index)
  local nextValue = tokenValue(tokens, index + 1)
  return nextValue == "." or nextValue == ":"
end

local function newScope(parent, kind)
  return {
    parent = parent,
    kind = kind,
    depth = parent and (parent.depth + 1) or 0,
    names = {},
  }
end

local function lookupLocal(scope, name, offset)
  local cursor = scope
  while cursor do
    local declaration = cursor.names[name]
    if declaration and declaration.offset <= offset then
      return declaration
    end
    cursor = cursor.parent
  end
  return nil
end

local function addLocal(facts, scope, token, kind, offset, requireModule)
  local declaration = {
    name = token.value,
    line = token.line,
    column = token.column,
    offset = offset or token.offset,
    tokenOffset = token.offset,
    tokenEndOffset = token.endOffset,
    kind = kind or "local",
    uses = 0,
    requireModule = requireModule,
  }
  scope.names[token.value] = declaration
  facts.locals[#facts.locals + 1] = declaration
  facts.hasLocal[token.value] = true

  local outer = lookupLocal(scope.parent, token.value, declaration.offset - 1)
  if outer then
    facts.shadows[#facts.shadows + 1] = {
      name = token.value,
      line = token.line,
      column = token.column,
      message = "局部变量 " .. token.value .. " 遮蔽了外层同名变量",
    }
  elseif scope.depth > 0 and (ENGINE_GLOBALS[token.value] or M.lookupLibrary(token.value)) then
    local sameRequire = requireModule and moduleAlias(requireModule) == token.value
    if not sameRequire then
      facts.shadows[#facts.shadows + 1] = {
        name = token.value,
        line = token.line,
        column = token.column,
        message = "局部变量 " .. token.value .. " 遮蔽了全局名字",
      }
    end
  end
  return declaration
end

local function functionCallString(tokens, requireIndex)
  local nextToken = tokens[requireIndex + 1]
  if nextToken and nextToken.type == "string" then
    return nextToken.value
  end
  if nextToken and nextToken.value == "(" then
    local valueToken = tokens[requireIndex + 2]
    if valueToken and valueToken.type == "string" then
      return valueToken.value
    end
  end
  return nil
end

local function analyze(tokens, source)
  local root = newScope(nil, "root")
  local facts = {
    uses = {},
    locals = {},
    shadows = {},
    hasLocal = {},
    globalDefs = {},
    requireBindings = {},
    importedGlobals = {},
    hasDynamicImport = false,
    hasDynamicGlobal = false,
    firstCodeOffset = 0,
  }
  local scope = root
  local blocks = {
    { kind = "root", scope = root, awaitingDo = false },
  }
  local skip = {}

  local function pushScope(kind)
    local nextScope = newScope(scope, kind)
    scope = nextScope
    blocks[#blocks + 1] = {
      kind = kind,
      scope = nextScope,
      awaitingDo = kind == "for" or kind == "while",
    }
  end

  local function popScope()
    if #blocks > 1 then
      blocks[#blocks] = nil
      scope = blocks[#blocks].scope
    end
  end

  if tokens[1] then
    facts.firstCodeOffset = tokens[1].offset - 1
  end

  local index = 1
  while index <= #tokens do
    local token = tokens[index]
    local value = token.value

    if value == "import" then
      local moduleName = functionCallString(tokens, index)
      if moduleName then
        if moduleName:match("%*$") then
          facts.hasDynamicImport = true
        else
          local imported = moduleName:match("([^%.]+)$")
          if imported and imported ~= "" then
            facts.importedGlobals[imported] = true
          end
        end
      end
      skip[index] = true
    elseif token.type == "name" then
      if not skip[index]
          and not isProperty(tokens, index)
          and not isTableKey(tokens, index)
          and not isLabel(tokens, index)
          and not isGotoTarget(tokens, index) then
        local following = tokenValue(tokens, index + 1)
        local memberName = nil
        local memberOperator = nil
        local memberCall = false
        if following == "." or following == ":" then
          local memberToken = tokens[index + 2]
          if memberToken and memberToken.type == "name" then
            memberName = memberToken.value
            memberOperator = following
            local afterMember = tokenValue(tokens, index + 3)
            memberCall = following == ":" and afterMember == "("
          end
        end
        local call = following == "("
          or (tokens[index + 1] and tokens[index + 1].type == "string")
          or following == "{"
          or memberCall
        facts.uses[#facts.uses + 1] = {
          name = value,
          token = token,
          scope = scope,
          member = isMember(tokens, index),
          memberName = memberName,
          memberOperator = memberOperator,
          memberCall = memberCall,
          call = call,
        }

        if scope.depth == 0 and tokenValue(tokens, index + 1) == "=" then
          facts.globalDefs[value] = token.line
        end
      end

      if value == "_G" then
        if tokenValue(tokens, index + 1) == "[" then
          facts.hasDynamicGlobal = true
        end
      elseif value == "loadstring" or value == "load" then
        facts.hasDynamicGlobal = true
      end
    elseif value == "local" then
      local cursor = index + 1
      if tokenValue(tokens, cursor) == "function" then
        local nameToken = tokens[cursor + 1]
        if nameToken and nameToken.type == "name" then
          addLocal(facts, scope, nameToken, "local", nameToken.offset)
          skip[cursor + 1] = true
          index = cursor - 1
        end
      else
        local declarationTokens = {}
        while tokens[cursor] do
          local current = tokens[cursor]
          if current.type == "name" then
            declarationTokens[#declarationTokens + 1] = current
            skip[cursor] = true
            cursor = cursor + 1
            if tokenValue(tokens, cursor) == "," then
              cursor = cursor + 1
            else
              break
            end
          else
            break
          end
        end

        local requireModule = nil
        local requireEndOffset = nil
        if #declarationTokens > 0 and tokenValue(tokens, cursor) == "=" then
          local afterEquals = cursor + 1
          if tokenValue(tokens, afterEquals) == "require" then
            requireModule = functionCallString(tokens, afterEquals)
            local argument = tokens[afterEquals + 1]
            if argument and argument.type == "string" then
              requireEndOffset = argument.endOffset
            elseif argument and argument.value == "(" then
              local close = tokens[afterEquals + 3]
              if close and close.value == ")" then
                requireEndOffset = close.endOffset
              end
            end
          end
        end

        local declarationOffset = nil
        local lastDeclaration = declarationTokens[#declarationTokens]
        if source and lastDeclaration then
          local newline = source:find("[\r\n]", lastDeclaration.offset)
          declarationOffset = newline or (#source + 1)
        end

        for _, nameToken in ipairs(declarationTokens) do
          local offset = declarationOffset
          if requireModule and nameToken == declarationTokens[1] and requireEndOffset then
            offset = requireEndOffset
          end
          local declaration = addLocal(facts, scope, nameToken, "local",
            offset or (nameToken.offset + #nameToken.value), requireModule)
          if requireModule and nameToken == declarationTokens[1] then
            facts.requireBindings[nameToken.value] = requireModule
          end
        end
      end
    elseif value == "function" then
      local previous = tokenValue(tokens, index - 1)
      local nameToken = tokens[index + 1]
      local afterName = tokens[index + 2]
      if previous == "local" then
        -- local function 的名字已经在 local 分支处理。
      elseif nameToken and nameToken.type == "name" then
        if afterName and afterName.value == "(" then
          skip[index + 1] = true
          if scope.depth == 0 then
            facts.globalDefs[nameToken.value] = nameToken.line
          end
        end
      end

      pushScope("function")
      local cursor = index + 1
      if nameToken and (afterName and (afterName.value == "(" or afterName.value == "." or afterName.value == ":")) then
        cursor = index + 2
        if afterName.value == "." or afterName.value == ":" then
          cursor = index + 3
          if tokens[cursor] and tokens[cursor].value == "(" then
            -- 方法定义从括号开始。
          else
            cursor = index + 1
          end
        end
      end
      while tokens[cursor] and tokens[cursor].value ~= "(" do
        cursor = cursor + 1
      end
      if tokens[cursor] and tokens[cursor].value == "(" then
        cursor = cursor + 1
        local first = true
        while tokens[cursor] and tokens[cursor].value ~= ")" do
          local current = tokens[cursor]
          if current.value == "," then
            first = true
          elseif current.type == "name" and first then
            addLocal(facts, scope, current, "param", token.offset)
            skip[cursor] = true
            first = false
          elseif current.value == "..." then
            first = false
          else
            first = false
          end
          cursor = cursor + 1
        end
      end
    elseif value == "for" then
      pushScope("for")
      local cursor = index + 1
      while tokens[cursor] and tokens[cursor].value ~= "=" and tokens[cursor].value ~= "in" do
        local current = tokens[cursor]
        if current.type == "name" then
          addLocal(facts, scope, current, "loop", token.offset)
          skip[cursor] = true
        end
        cursor = cursor + 1
      end
    elseif value == "while" then
      pushScope("while")
    elseif value == "do" then
      local top = blocks[#blocks]
      if top and top.awaitingDo then
        top.awaitingDo = false
      else
        pushScope("do")
      end
    elseif value == "if" then
      pushScope("if")
    elseif value == "elseif" or value == "else" then
      popScope()
      pushScope(value)
    elseif value == "repeat" then
      pushScope("repeat")
    elseif value == "end" then
      popScope()
    elseif value == "until" then
      popScope()
    end

    index = index + 1
  end

  return facts
end

local function findUIPageBindings(tokens)
  local result = {}
  for index, token in ipairs(tokens) do
    if token.value == "local" then
      local nameToken = tokens[index + 1]
      local equalsToken = tokens[index + 2]
      local baseToken = tokens[index + 3]
      local dotToken = tokens[index + 4]
      local pageToken = tokens[index + 5]
      if nameToken and nameToken.type == "name"
          and equalsToken and equalsToken.value == "="
          and baseToken and baseToken.value == "ui"
          and dotToken and dotToken.value == "."
          and pageToken and pageToken.value == "page" then
        result[#result + 1] = {
          name = nameToken.value,
          line = nameToken.line,
          column = nameToken.column,
          offset = nameToken.offset,
        }
      end
    end
  end
  return result
end

local function scanDefinitions(tokens)
  local definitions = {}
  local blocks = {
    { kind = "root", awaitingDo = false },
  }
  local depth = 0
  local skip = {}

  local function push(kind)
    depth = depth + 1
    blocks[#blocks + 1] = {
      kind = kind,
      awaitingDo = kind == "for" or kind == "while",
    }
  end

  local function pop()
    if #blocks > 1 then
      blocks[#blocks] = nil
      depth = depth - 1
    end
  end

  local index = 1
  while index <= #tokens do
    local token = tokens[index]
    local value = token.value

    if value == "local" then
      local cursor = index + 1
      if tokenValue(tokens, cursor) == "function" then
        skip[cursor] = true
        skip[cursor + 1] = true
      else
        while tokens[cursor] do
          if tokens[cursor].type == "name" then
            skip[cursor] = true
            cursor = cursor + 1
            if tokenValue(tokens, cursor) == "," then
              cursor = cursor + 1
            else
              break
            end
          else
            break
          end
        end
      end
    elseif value == "for" then
      local cursor = index + 1
      while tokens[cursor] and tokens[cursor].value ~= "=" and tokens[cursor].value ~= "in" do
        if tokens[cursor].type == "name" then
          skip[cursor] = true
        end
        cursor = cursor + 1
      end
      push("for")
    elseif value == "function" then
      local previous = tokenValue(tokens, index - 1)
      local nameToken = tokens[index + 1]
      local afterName = tokens[index + 2]
      if previous ~= "local" and depth == 0 and nameToken and nameToken.type == "name"
          and afterName and afterName.value == "(" then
        definitions[nameToken.value] = nameToken.line
        skip[index + 1] = true
      end
      push("function")
    elseif value == "if" then
      push("if")
    elseif value == "while" then
      push("while")
    elseif value == "do" then
      local top = blocks[#blocks]
      if top and top.awaitingDo then
        top.awaitingDo = false
      else
        push("do")
      end
    elseif value == "repeat" then
      push("repeat")
    elseif value == "end" then
      pop()
    elseif value == "until" then
      pop()
    elseif token.type == "name" and depth == 0 and not skip[index] then
      if tokenValue(tokens, index + 1) == "=" and not isProperty(tokens, index)
          and not isTableKey(tokens, index) then
        definitions[value] = token.line
      end
    end
    index = index + 1
  end

  return definitions
end

function M.indexProject(root)
  local definitions = {}
  for _, path in ipairs(listLuaFiles(root)) do
    local source = readFile(path)
    if source then
      local localDefinitions = scanDefinitions(tokenize(source))
      for name, line in pairs(localDefinitions) do
        local entries = definitions[name]
        if not entries then
          entries = {}
          definitions[name] = entries
        end
        entries[#entries + 1] = {
          file = path,
          line = line,
        }
      end
    end
  end
  return definitions
end

local function editDistance(left, right)
  left = tostring(left)
  right = tostring(right)
  if left == right then
    return 0
  end
  if #left > 32 or #right > 32 then
    return 99
  end
  local previous = {}
  for column = 0, #right do
    previous[column] = column
  end
  for row = 1, #left do
    local current = { [0] = row }
    for column = 1, #right do
      local cost = left:sub(row, row) == right:sub(column, column) and 0 or 1
      local deletion = previous[column] + 1
      local insertion = current[column - 1] + 1
      local substitution = previous[column - 1] + cost
      local best = deletion
      if insertion < best then
        best = insertion
      end
      if substitution < best then
        best = substitution
      end
      current[column] = best
    end
    previous = current
  end
  return previous[#right]
end

local function closestName(name, facts, definitions)
  local best
  local bestDistance = 3
  local function check(candidate)
    if candidate == name or #candidate < 2 then
      return
    end
    if math.abs(#candidate - #name) > 2 then
      return
    end
    local distance = editDistance(name, candidate)
    if distance < bestDistance then
      bestDistance = distance
      best = candidate
    end
  end
  for candidate in pairs(facts.hasLocal) do
    check(candidate)
  end
  for candidate in pairs(facts.globalDefs) do
    check(candidate)
  end
  for candidate in pairs(definitions or {}) do
    check(candidate)
  end
  for candidate in pairs(libraries) do
    check(candidate)
  end
  for candidate in pairs(ENGINE_GLOBALS) do
    check(candidate)
  end
  return best, bestDistance
end

local function insertOffset(source, facts)
  local firstOffset = tonumber(facts.firstCodeOffset) or 0
  if firstOffset <= 0 then
    return 0
  end
  local prefix = source:sub(1, firstOffset)
  local newline = prefix:match(".*()\n")
  return newline or 0
end

local ISSUE_CODES = {
  missing_require = "LX1001",
  undefined_global = "LX1002",
  unused_local = "LX1003",
  shadow = "LX1004",
  possible_typo = "LX1005",
  late_local = "LX1006",
  page_object = "LX1007",
  undefined_function = "LX1008",
  page_not_shown = "LX1009",
}

local function addIssue(report, issue)
  if not issue.code then
    issue.code = ISSUE_CODES[issue.kind] or "LX0000"
  end
  report.issues[#report.issues + 1] = issue
end

local function lineStartOffset(source, token)
  local before = source:sub(1, math.max(0, (tonumber(token.offset) or 1) - 1))
  local newline = before:match(".*()\n")
  if newline then
    return newline, before:sub(newline + 1)
  end
  return 0, before
end

local function actionPreview(action)
  local parts = {}
  for _, edit in ipairs(action.edits or {}) do
    local start = tonumber(edit.startOffset) or 0
    local stop = tonumber(edit.endOffset) or start
    local text = tostring(edit.text or ""):gsub("\r", ""):gsub("\n", " ")
    if stop == start then
      parts[#parts + 1] = "插入 " .. text
    else
      parts[#parts + 1] = "替换 " .. (stop - start) .. " 个字符为 " .. text
    end
  end
  return table.concat(parts, "；")
end

local function addAction(report, seen, action)
  local key = table.concat({
    action.code or "",
    action.name or "",
    action.title or "",
    action.confidence or "",
  }, "\0")
  if seen[key] then
    return
  end
  seen[key] = true
  action.edits = action.edits or {}
  action.preview = action.preview or actionPreview(action)
  report.actions[#report.actions + 1] = action
end

local function dedupeAndSort(report)
  local seen = {}
  local result = {}
  for _, issue in ipairs(report.issues) do
    local key = table.concat({
      issue.kind or "",
      issue.name or "",
      tostring(issue.line or 0),
      issue.message or "",
    }, "\0")
    if not seen[key] then
      seen[key] = true
      result[#result + 1] = issue
    end
  end
  local rank = { error = 1, warning = 2, info = 3 }
  table.sort(result, function(left, right)
    local leftRank = rank[left.severity] or 4
    local rightRank = rank[right.severity] or 4
    if leftRank ~= rightRank then
      return leftRank < rightRank
    end
    if (left.line or 0) ~= (right.line or 0) then
      return (left.line or 0) < (right.line or 0)
    end
    return (left.column or 0) < (right.column or 0)
  end)
  report.issues = result
end

function M.audit(source, options)
  options = options or {}
  source = tostring(source or "")
  local tokens = tokenize(source)
  local facts = analyze(tokens, source)
  local pageBindings = findUIPageBindings(tokens)

  local definitions = options.projectDefinitions
  if not definitions and options.projectRoot then
    M.loadProjectLibraries(options.projectRoot)
    definitions = M.indexProject(options.projectRoot)
  end
  definitions = definitions or {}

  for name, line in pairs(facts.globalDefs) do
    local entries = definitions[name]
    if not entries then
      entries = {}
      definitions[name] = entries
    end
    local exists = false
    for _, entry in ipairs(entries) do
      if entry.file == options.file then
        exists = true
        break
      end
    end
    if not exists then
      entries[#entries + 1] = {
        file = options.file or "",
        line = line,
      }
    end
  end

  local report = {
    issues = {},
    fixes = {},
    actions = {},
    source = source,
    file = options.file,
    projectRoot = options.projectRoot,
    fixable = 0,
  }
  local fixableNames = {}
  local seenActions = {}
  local insertAt = insertOffset(source, facts)

  local function appendFix(name, library)
    if fixableNames[name] then
      return
    end
    fixableNames[name] = true
    local line = 'local ' .. name .. ' = require "' .. library.module .. '"'
    report.fixes[#report.fixes + 1] = {
      name = name,
      module = library.module,
      offset = insertAt,
      text = line,
      line = 1,
    }
    addAction(report, seenActions, {
      code = ISSUE_CODES.missing_require,
      kind = "quickfix",
      confidence = "safe",
      priority = 0,
      name = name,
      title = "补全 " .. name .. " 引用",
      edits = {
        { startOffset = insertAt, endOffset = insertAt, text = line .. "\n", priority = 0 },
      },
      preview = "在文件头插入 " .. line,
    })
  end

  local pageLikeUses = {}
  local pageHasShow = false
  for _, use in ipairs(facts.uses) do
    if use.name == "page" and use.memberCall
        and (use.memberName == "add" or use.memberName == "show") then
      pageLikeUses[#pageLikeUses + 1] = use
      if use.memberName == "show" then
        pageHasShow = true
      end
    end
  end
  local pageCanUseUI = facts.requireBindings.ui == "luaxplus.ui"
    or facts.globalDefs.ui ~= nil
  if not pageCanUseUI and not facts.hasLocal.ui then
    for _, use in ipairs(facts.uses) do
      if use.name == "ui" then
        pageCanUseUI = true
        break
      end
    end
  end

  local function maybePageAction(use)
    if not pageCanUseUI or #pageLikeUses == 0 then
      return
    end
    local first = pageLikeUses[1]
    local start, indent = lineStartOffset(source, first.token)
    if not indent:match("^%s*$") then
      indent = ""
    end
    local edits = {
      {
        startOffset = start,
        endOffset = start,
        text = indent .. "local page = ui.page{}\n",
      },
    }
    local suffix = ""
    if not pageHasShow then
      local prefix = source:sub(-1) == "\n" and "" or "\n"
      edits[#edits + 1] = {
        startOffset = #source,
        endOffset = #source,
        text = prefix .. "page:show()\n",
      }
      suffix = "；文件末尾补 page:show()"
    end
    addAction(report, seenActions, {
      code = ISSUE_CODES.page_object,
      kind = "quickfix",
      confidence = "guided",
      priority = 1,
      name = "page",
      title = "插入页面骨架",
      edits = edits,
      preview = "在第 " .. tostring(first.token.line or 1)
        .. " 行前插入 local page = ui.page{}" .. suffix,
    })
  end

  for _, use in ipairs(facts.uses) do
    local name = use.name
    local declaration = lookupLocal(use.scope, name, use.token.offset)
    if declaration then
      declaration.uses = declaration.uses + 1
    elseif facts.globalDefs[name] or definitions[name] then
      -- 当前文件或其他文件已经定义，不报未定义。
    elseif ENGINE_GLOBALS[name] or facts.importedGlobals[name] then
      -- 引擎或 import 提供的名字，直接放行。
    elseif facts.hasDynamicImport and name:match("^%u") then
      -- import "android.widget.*" 这类通配符可能带进任意类名，不能当成缺失引用。
    elseif M.lookupLibrary(name) then
      local library = M.lookupLibrary(name)
      if facts.hasLocal[name] then
        addIssue(report, {
          severity = "warning",
          kind = "late_local",
          name = name,
          line = use.token.line,
          column = use.token.column,
          offset = use.token.offset,
          endOffset = use.token.endOffset,
          message = "使用了 " .. name .. "，但它在本文件后面的作用域才声明",
        })
      else
        addIssue(report, {
          severity = "error",
          kind = "missing_require",
          name = name,
          line = use.token.line,
          column = use.token.column,
          offset = use.token.offset,
          endOffset = use.token.endOffset,
          fixable = true,
          message = "使用了 " .. name .. "，但当前文件没有引用模块 " .. library.module,
        })
        appendFix(name, library)
      end
    elseif facts.hasLocal[name] then
      addIssue(report, {
        severity = "info",
        kind = "late_local",
        name = name,
        line = use.token.line,
        column = use.token.column,
        offset = use.token.offset,
        endOffset = use.token.endOffset,
        message = "使用了 " .. name .. "，但它在本文件后面的作用域才声明",
      })
    else
      local suggestion, distance = closestName(name, facts, definitions)
      local maxDistance = #name <= 4 and 1 or 2
      local isTypo = suggestion and distance <= maxDistance
      local isPage = name == "page" and use.memberCall
        and (use.memberName == "add" or use.memberName == "show")
        and pageCanUseUI
      local isFunction = use.call and not use.member and not isPage and not isTypo
      local kind = "undefined_global"
      local message
      if isTypo then
        kind = "possible_typo"
        message = "未定义的全局变量 " .. name .. "，是否想写 " .. suggestion .. "？"
      elseif isPage then
        kind = "page_object"
        message = "未定义的页面对象 page，无法执行 :" .. tostring(use.memberName) .. "()"
      elseif isFunction then
        kind = "undefined_function"
        message = "未定义的全局函数 " .. name
      elseif facts.hasDynamicImport or facts.hasDynamicGlobal then
        message = "未定义的全局变量 " .. name .. "，也可能来自 import 或动态赋值"
      else
        message = "未定义的全局变量 " .. name
      end
      addIssue(report, {
        severity = "warning",
        kind = kind,
        name = name,
        line = use.token.line,
        column = use.token.column,
        offset = use.token.offset,
        endOffset = use.token.endOffset,
        suggestion = suggestion,
        message = message,
      })

      if isPage then
        maybePageAction(use)
      elseif isTypo then
        local edits = {}
        for _, other in ipairs(facts.uses) do
          if other.name == name and not other.member
              and not lookupLocal(other.scope, name, other.token.offset) then
            edits[#edits + 1] = {
              startOffset = other.token.offset - 1,
              endOffset = other.token.endOffset,
              text = suggestion,
            }
          end
        end
        addAction(report, seenActions, {
          code = ISSUE_CODES.possible_typo,
          kind = "quickfix",
          confidence = "guided",
          name = name,
          title = "重命名为 " .. suggestion,
          edits = edits,
          preview = "把 " .. name .. " 的引用改为 " .. suggestion,
        })
      elseif isFunction and not facts.hasDynamicGlobal then
        local start, indent = lineStartOffset(source, use.token)
        if not indent:match("^%s*$") then
          indent = ""
        end
        local stub = indent .. "local function " .. name .. "(...)\n"
          .. indent .. "end\n"
        addAction(report, seenActions, {
          code = ISSUE_CODES.undefined_function,
          kind = "quickfix",
          confidence = "guided",
          name = name,
          title = "创建 " .. name .. " 空函数占位",
          edits = {
            { startOffset = start, endOffset = start, text = stub },
          },
          preview = "在第 " .. tostring(use.token.line or 1)
            .. " 行前插入 local function " .. name .. "(...)",
        })
      end
    end
  end

  for _, binding in ipairs(pageBindings) do
    local shown = false
    for _, use in ipairs(facts.uses) do
      if use.name == binding.name and use.memberCall and use.memberName == "show" then
        shown = true
        break
      end
    end
    if not shown then
      addIssue(report, {
        severity = "warning",
        kind = "page_not_shown",
        name = binding.name,
        line = binding.line,
        column = binding.column,
        offset = binding.offset,
        message = "页面对象 " .. binding.name .. " 已创建，但没有调用 "
          .. binding.name .. ":show()，运行后不会显示",
      })
      local prefix = source:sub(-1) == "\n" and "" or "\n"
      addAction(report, seenActions, {
        code = ISSUE_CODES.page_not_shown,
        kind = "quickfix",
        confidence = "guided",
        name = binding.name,
        title = "补页面显示 " .. binding.name .. ":show()",
        edits = {
          {
            startOffset = #source,
            endOffset = #source,
            text = prefix .. binding.name .. ":show()\n",
          },
        },
        preview = "在文件末尾补 " .. binding.name .. ":show()",
      })
    end
  end

  for _, declaration in ipairs(facts.locals) do
    if declaration.kind == "local" and declaration.uses == 0
        and not declaration.name:match("^_")
        and declaration.name ~= "self" then
      addIssue(report, {
        severity = "info",
        kind = "unused_local",
        name = declaration.name,
        line = declaration.line,
        column = declaration.column,
        offset = declaration.tokenOffset,
        endOffset = declaration.tokenEndOffset,
        message = "局部变量 " .. declaration.name .. " 已声明但未使用",
      })
    end
  end

  for _, shadow in ipairs(facts.shadows) do
    addIssue(report, {
      severity = "info",
      kind = "shadow",
      name = shadow.name,
      line = shadow.line,
      column = shadow.column,
      message = shadow.message,
    })
  end

  dedupeAndSort(report)
  report.fixable = #report.fixes
  report.safeCount = 0
  report.guidedCount = 0
  for _, action in ipairs(report.actions) do
    if action.confidence == "safe" then
      report.safeCount = report.safeCount + 1
    else
      report.guidedCount = report.guidedCount + 1
    end
  end
  report.actionCount = #report.actions
  report.hasErrors = false
  report.hasWarnings = false
  report.infoCount = 0
  for _, issue in ipairs(report.issues) do
    if issue.severity == "error" then
      report.hasErrors = true
    elseif issue.severity == "warning" then
      report.hasWarnings = true
    else
      report.infoCount = report.infoCount + 1
    end
  end
  return report
end

function M.applyFixes(source, report)
  source = tostring(source or "")
  report = report or {}
  local fixes = report.fixes or {}
  if #fixes == 0 then
    return source, 0
  end

  local groups = {}
  local offsets = {}
  for _, fix in ipairs(fixes) do
    local offset = math.max(0, math.min(#source, tonumber(fix.offset) or 0))
    if not groups[offset] then
      groups[offset] = {}
      offsets[#offsets + 1] = offset
    end
    groups[offset][#groups[offset] + 1] = fix
  end

  table.sort(offsets, function(left, right)
    return left > right
  end)

  local result = source
  local applied = 0
  for _, offset in ipairs(offsets) do
    local lines = {}
    for _, fix in ipairs(groups[offset]) do
      lines[#lines + 1] = fix.text
      applied = applied + 1
    end
    table.sort(lines)
    local block = table.concat(lines, "\n") .. "\n"
    result = result:sub(1, offset) .. block .. result:sub(offset + 1)
  end
  return result, applied
end

local function compileSource(source)
  local loader = rawget(_G, "loadstring") or rawget(_G, "load")
  if not loader then
    return true
  end
  local ok, result, message = pcall(loader, source)
  if not ok then
    return false, tostring(result)
  end
  if type(result) == "function" then
    return true
  end
  return false, tostring(message or result or "Lua 语法错误")
end

function M.applyActions(source, actions)
  source = tostring(source or "")
  actions = actions or {}
  local edits = {}
  for actionIndex, action in ipairs(actions) do
    if type(action) == "table" then
      for _, edit in ipairs(action.edits or {}) do
        local startOffset = tonumber(edit.startOffset)
        local endOffset = tonumber(edit.endOffset)
        if not startOffset or not endOffset then
          return nil, 0, "第 " .. actionIndex .. " 项修复缺少编辑位置"
        end
        startOffset = math.floor(startOffset)
        endOffset = math.floor(endOffset)
        if startOffset < 0 or endOffset < startOffset or endOffset > #source then
          return nil, 0, "第 " .. actionIndex .. " 项修复位置越界"
        end
        edits[#edits + 1] = {
          startOffset = startOffset,
          endOffset = endOffset,
          text = tostring(edit.text or ""),
          priority = tonumber(edit.priority) or tonumber(action.priority) or 2,
          order = #edits + 1,
        }
      end
    end
  end
  if #edits == 0 then
    return source, 0
  end

  for left = 1, #edits do
    for right = left + 1, #edits do
      local first = edits[left]
      local second = edits[right]
      local overlaps = first.startOffset < second.endOffset
        and second.startOffset < first.endOffset
      if not overlaps then
        local firstInsert = first.startOffset == first.endOffset
        local secondInsert = second.startOffset == second.endOffset
        if firstInsert and not secondInsert
            and first.startOffset >= second.startOffset
            and first.startOffset <= second.endOffset then
          overlaps = true
        elseif secondInsert and not firstInsert
            and second.startOffset >= first.startOffset
            and second.startOffset <= first.endOffset then
          overlaps = true
        end
      end
      if overlaps then
        return nil, 0, "修复项存在重叠编辑，请逐项应用"
      end
    end
  end

  local insertGroups = {}
  local insertOffsets = {}
  local replacements = {}
  for _, edit in ipairs(edits) do
    if edit.startOffset == edit.endOffset then
      local offset = edit.startOffset
      if not insertGroups[offset] then
        insertGroups[offset] = {}
        insertOffsets[#insertOffsets + 1] = offset
      end
      insertGroups[offset][#insertGroups[offset] + 1] = edit
    else
      replacements[#replacements + 1] = edit
    end
  end

  table.sort(insertOffsets, function(left, right)
    return left > right
  end)
  table.sort(replacements, function(left, right)
    if left.startOffset ~= right.startOffset then
      return left.startOffset > right.startOffset
    end
    return left.order > right.order
  end)

  local result = source
  for _, offset in ipairs(insertOffsets) do
    local group = insertGroups[offset]
    table.sort(group, function(left, right)
      if left.priority ~= right.priority then
        return left.priority < right.priority
      end
      if left.text ~= right.text then
        return left.text < right.text
      end
      return left.order < right.order
    end)
    local texts = {}
    for _, edit in ipairs(group) do
      texts[#texts + 1] = edit.text
    end
    local block = table.concat(texts)
    result = result:sub(1, offset) .. block .. result:sub(offset + 1)
  end
  for _, edit in ipairs(replacements) do
    result = result:sub(1, edit.startOffset)
      .. edit.text .. result:sub(edit.endOffset + 1)
  end
  return result, #edits
end

function M.verify(source, options)
  source = tostring(source or "")
  options = options or {}
  local syntaxOk, syntaxMessage = compileSource(source)
  if not syntaxOk then
    return false, syntaxMessage, nil
  end
  local report = M.audit(source, options)
  if report.hasErrors then
    return false, "仍有未解决的错误", report
  end
  return true, nil, report
end

function M.applyRepair(source, report, options)
  source = tostring(source or "")
  report = report or {}
  options = options or {}
  local actions = options.actions or report.actions or {}
  if #actions == 0 then
    return {
      ok = false,
      text = source,
      applied = 0,
      reason = "empty",
      message = "没有可自动应用的修复项",
      report = report,
    }
  end

  local fixed, applied, editError = M.applyActions(source, actions)
  if not fixed then
    return {
      ok = false,
      text = source,
      applied = 0,
      reason = "edit",
      message = tostring(editError or "修复写入失败"),
      report = report,
    }
  end

  local syntaxOk, syntaxMessage = compileSource(fixed)
  if not syntaxOk then
    return {
      ok = false,
      text = source,
      applied = 0,
      reason = "syntax",
      message = "修复后语法检查失败：" .. tostring(syntaxMessage),
      report = report,
    }
  end

  local auditOptions = {
    file = report.file,
    projectRoot = report.projectRoot,
    projectDefinitions = options.projectDefinitions,
  }
  local after = M.audit(fixed, auditOptions)
  local selectedKeys = {}
  for _, action in ipairs(actions) do
    selectedKeys[(action.code or "") .. "\0" .. (action.name or "")] = true
  end
  local unresolved = false
  local runtimeBlocking = {
    page_object = true,
    undefined_function = true,
    page_not_shown = true,
  }
  for _, issue in ipairs(after.issues) do
    if selectedKeys[(issue.code or "") .. "\0" .. (issue.name or "")]
        or runtimeBlocking[issue.kind] then
      unresolved = true
      break
    end
  end
  if after.hasErrors or unresolved then
    return {
      ok = false,
      text = fixed,
      applied = applied,
      reason = "lint",
      message = unresolved and "修复后仍有同类问题，未写入文件" or "修复后仍有错误，未写入文件",
      report = after,
    }
  end
  return {
    ok = true,
    text = fixed,
    applied = applied,
    report = after,
  }
end

M.tokenize = tokenize
M.engineGlobals = ENGINE_GLOBALS

M.resetLibraries()

return M
