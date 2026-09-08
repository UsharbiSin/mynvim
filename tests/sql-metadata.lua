local metadata = require("config.sql-metadata")

local tables = metadata.parse({
  { "sys_user", "用户表", "BASE TABLE", "id", "用户编号", "bigint" },
  { "sys_user", "用户表", "BASE TABLE", "name", "用户姓名", "varchar(50)" },
  { "order_view", "订单视图", "VIEW", "order_no", "订单编号", "varchar(32)" },
})

assert(#tables == 2)
assert(tables[1].name == "sys_user")
assert(tables[1].comment == "用户表")
assert(#tables[1].columns == 2)
assert(tables[2].type == "view")

local multiline = metadata.parse({
  { "audit_log", "审计\n日志", "BASE TABLE", "detail", "操作\t详情", "text" },
})
assert(multiline[1].comment == "审计 日志")
assert(multiline[1].columns[1].comment == "操作 详情")

assert(#metadata.filter(tables, "用户") == 1, "table comments must be searchable")
assert(#metadata.filter(tables, "订单") == 1, "view comments must be searchable")
assert(#metadata.filter(tables, "姓名") == 1, "column comments must be searchable")
assert(#metadata.filter(tables, "sys_user") == 1, "technical table names must remain searchable")

local comments = metadata.column_comments(tables, { "id", "name" }, "sys_user")
assert(#comments == 2)
assert(comments[2].comment == "用户姓名")

local ambiguous = metadata.column_comments(tables, { "order_no" })
assert(#ambiguous == 1 and ambiguous[1].table_name == "order_view")

print("PASS: SQL metadata comments")
