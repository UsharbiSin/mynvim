local M = {}

-- Recognize this one MySQL command without accepting arbitrary SHOW statements
-- or executable comments. Used by both execution and the SQLFluff workaround.
function M.is_processlist(sql)
  if type(sql) ~= "string" or sql:find("%z") then return false end

  local tokens, index = {}, 1
  while index <= #sql do
    local char = sql:sub(index, index)
    local pair = sql:sub(index, index + 1)
    if char:match("%s") then
      index = index + 1
    elseif char == "#"
        or (pair == "--" and sql:sub(index + 2, index + 2):match("[%s%c]")) then
      local newline = sql:find("\n", index, true)
      local carriage_return = sql:find("\r", index, true)
      -- A bare CR may terminate a MySQL comment. Do not absorb later SQL;
      -- accept CRLF, but leave ambiguous lone-CR input to the normal path.
      if carriage_return and (not newline or carriage_return < newline - 1) then
        return false
      end
      index = (newline or #sql) + 1
    elseif pair == "/*" then
      local marker = sql:sub(index + 2, index + 3):upper()
      if marker:sub(1, 1) == "!" or marker:sub(1, 1) == "+" or marker == "M!" then
        return false
      end
      local closing = sql:find("*/", index + 2, true)
      local nested = sql:find("/*", index + 2, true)
      if not closing or (nested and nested < closing) then return false end
      index = closing + 2
    elseif char == ";" then
      tokens[#tokens + 1] = char
      index = index + 1
    elseif char:match("[A-Za-z]") then
      local word = sql:sub(index):match("^[A-Za-z]+")
      tokens[#tokens + 1] = word:upper()
      index = index + #word
    else
      return false
    end
  end

  if tokens[#tokens] == ";" then table.remove(tokens) end
  return (#tokens == 2 and tokens[1] == "SHOW" and tokens[2] == "PROCESSLIST")
    or (#tokens == 3 and tokens[1] == "SHOW" and tokens[2] == "FULL" and tokens[3] == "PROCESSLIST")
end

return M
