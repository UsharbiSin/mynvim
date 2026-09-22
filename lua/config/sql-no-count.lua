-- 禁止表格加载/重查时为分页自动统计总数，不修改 lazy 中的插件源码。
local M = {}

local function pack(...)
  return { n = select("#", ...), ... }
end

local function same_query(left, right)
  if not left or not right then return false end
  local a, b = vim.deepcopy(left), vim.deepcopy(right)
  a.page, b.page = nil, nil
  return vim.deep_equal(a, b)
end

function M.install()
  local grip = require("dadbod-grip")
  if grip._sql_no_auto_count then return end
  local query = require("dadbod-grip.query")
  local db = require("dadbod-grip.db")
  local view = require("dadbod-grip.view")
  assert(type(grip.open) == "function" and type(query.build_count_sql) == "function"
    and type(db.query) == "function" and type(view.set_callbacks) == "function",
    "Dadbod Grip 分页接口已变化，请更新免统计兼容层")

  local original_open = grip.open
  local original_count = query.build_count_sql
  local original_query = db.query
  local original_callbacks = view.set_callbacks
  local depth = 0
  -- 私有标记只从分页 COUNT 生成器传到 db.query；绝不按 SQL 内容匹配拦截。
  -- 用户手写的 SELECT COUNT(*)（包括 _grip_count 别名）仍原样执行。
  local skipped_count = {}

  local function without_count(callback, ...)
    local args = pack(...)
    depth = depth + 1
    local result = pack(xpcall(function()
      return callback(unpack(args, 1, args.n))
    end, debug.traceback))
    depth = depth - 1
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end

  query.build_count_sql = function(spec)
    if depth > 0 then return skipped_count end
    -- 显式选择“导出全部匹配行”等独立操作仍可按原逻辑确认数据规模。
    return original_count(spec)
  end

  db.query = function(sql, ...)
    if sql == skipped_count then
      -- 没有结果行表示总数未知，而不是 0；不取密、不启动客户端、不连接数据库。
      return { columns = {}, rows = {}, primary_keys = {} }, nil
    end
    return original_query(sql, ...)
  end

  grip.open = function(...)
    return without_count(original_open, ...)
  end

  local function wrap_refresh(callback)
    return function(bufnr, next_spec)
      local session = view._sessions[bufnr]
      if not session then return without_count(callback, bufnr, next_spec) end
      local previous_state = session.state
      local previous_spec = session.query_spec
      local previous_sql = session.query_sql
      local previous_total = session.total_rows

      -- 不足一页已经能确定当前没有下一页，无须 COUNT，也不继续翻出空页。
      -- 满一页时允许尝试下一页；刚好整页结束时可能得到一次空结果，再返回即可。
      if next_spec and previous_spec and previous_state
          and next_spec.page > previous_spec.page
          and same_query(previous_spec, next_spec)
          and #(previous_state.rows or {}) < previous_spec.page_size then
        vim.notify("已到最后一页（未统计总行数）", vim.log.levels.INFO)
        return
      end

      -- 原插件会依据旧 total_rows 钳制页码；筛选改变后不能继续使用旧总数。
      session.total_rows = nil
      local result = pack(pcall(without_count, callback, bufnr, next_spec))
      if not result[1] or session.state == previous_state then
        -- 查询失败时恢复原页信息；插件的错误提示由原调用负责。
        session.query_spec = previous_spec
        session.query_sql = previous_sql
        session.total_rows = previous_total
      end
      if not result[1] then error(result[2], 0) end
      return unpack(result, 2, result.n)
    end
  end

  view.set_callbacks = function(bufnr, callbacks)
    local wrapped = vim.tbl_extend("force", {}, callbacks)
    for _, name in ipairs({ "on_requery", "on_refresh" }) do
      if type(callbacks[name]) == "function" then
        wrapped[name] = wrap_refresh(callbacks[name])
      end
    end
    return original_callbacks(bufnr, wrapped)
  end

  grip._sql_no_auto_count = true
end

return M
