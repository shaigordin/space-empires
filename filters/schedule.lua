-- schedule.lua
-- Renders a CSV file as a static HTML schedule table at render time.
-- Usage in a .qmd:  ::: {.schedule-csv file="schedule.csv"} :::
-- No R / Python / kernel required — runs inside Pandoc (bundled with Quarto).

local function read_file(path)
  local candidates = { path }
  local proj = os.getenv("QUARTO_PROJECT_DIR")
  if proj then table.insert(candidates, proj .. "/" .. path) end
  for _, p in ipairs(candidates) do
    local f = io.open(p, "rb")
    if f then
      local c = f:read("*a")
      f:close()
      return c
    end
  end
  return nil
end

-- RFC4180-style CSV parser: handles quoted fields, embedded commas,
-- doubled "" escapes and embedded newlines.
local function parse_csv(str)
  local rows, row, field = {}, {}, {}
  local in_quotes = false
  local i, len = 1, #str

  local function push_field()
    table.insert(row, table.concat(field))
    field = {}
  end
  local function push_row()
    push_field()
    table.insert(rows, row)
    row = {}
  end

  while i <= len do
    local c = str:sub(i, i)
    if in_quotes then
      if c == '"' then
        if str:sub(i + 1, i + 1) == '"' then
          table.insert(field, '"')
          i = i + 1
        else
          in_quotes = false
        end
      else
        table.insert(field, c)
      end
    else
      if c == '"' then
        in_quotes = true
      elseif c == ',' then
        push_field()
      elseif c == '\n' then
        push_row()
      elseif c ~= '\r' then
        table.insert(field, c)
      end
    end
    i = i + 1
  end
  if #field > 0 or #row > 0 then push_row() end
  return rows
end

local HEADERS = { "מס'", "תאריך ושעה", "נושא השיעור", "חומרי קריאה", "משימות", "הערות" }

function Div(el)
  if not el.classes:includes("schedule-csv") then return nil end
  local file = el.attributes["file"] or "schedule.csv"
  local content = read_file(file)
  if not content then
    return pandoc.RawBlock("html",
      '<p><em>קובץ לוח הזמנים לא נמצא: ' .. file .. '</em></p>')
  end

  local rows = parse_csv(content)
  local header = rows[1]
  local idx = {}
  for i, name in ipairs(header) do idx[name] = i end
  local function cell(r, name)
    local j = idx[name]
    return (j and r[j]) or ""
  end

  local h = {}
  table.insert(h, '<table class="schedule-table" dir="rtl">')
  table.insert(h, '<thead><tr>')
  for _, name in ipairs(HEADERS) do
    table.insert(h, '<th>' .. name .. '</th>')
  end
  table.insert(h, '</tr></thead><tbody>')

  for i = 2, #rows do
    local r = rows[i]
    if cell(r, "date") ~= "" then
      local topic = cell(r, "topic")
      local topic_url = cell(r, "topic_url")
      if topic_url ~= "" then
        topic = '<a href="' .. topic_url .. '" target="_blank">' .. topic .. '</a>'
      end
      local date_html =
        '<span class="sched-date">' .. cell(r, "date") .. '</span><br>' ..
        '<span class="sched-day">יום ' .. cell(r, "day") .. '׳</span><br>' ..
        '<span class="sched-time">' .. cell(r, "time") .. '</span>'
      table.insert(h, '<tr>')
      table.insert(h, '<td>' .. cell(r, "meeting") .. '</td>')
      table.insert(h, '<td>' .. date_html .. '</td>')
      table.insert(h, '<td><strong>' .. cell(r, "unit") .. ':</strong> ' .. topic .. '</td>')
      table.insert(h, '<td>' .. cell(r, "materials") .. '</td>')
      table.insert(h, '<td>' .. cell(r, "task") .. '</td>')
      table.insert(h, '<td>' .. cell(r, "note") .. '</td>')
      table.insert(h, '</tr>')
    end
  end

  table.insert(h, '</tbody></table>')
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end
