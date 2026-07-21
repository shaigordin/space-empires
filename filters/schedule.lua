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

-- Convert the small subset of HTML used in the CSV cells to Markdown, so that
-- non-HTML outputs (docx, pdf, …) render real links/emphasis rather than losing
-- the raw HTML block.
local function html_to_md(s)
  if not s or s == "" then return "" end
  s = s:gsub("<a%s+href='(.-)'.->(.-)</a>", "[%2](%1)")
  s = s:gsub('<a%s+href="(.-)".->(.-)</a>', "[%2](%1)")
  s = s:gsub("<strong>(.-)</strong>", "**%1**")
  s = s:gsub("<em>(.-)</em>", "*%1*")
  s = s:gsub("<br%s*/?>", " ")
  s = s:gsub("%b<>", "")            -- strip any remaining tags
  s = s:gsub("|", "\\|")            -- escape pipe so it can't break the table
  -- Collapse/trim ASCII whitespace only. Never use %s here: under the C locale
  -- it matches byte 0xA0, which is the second byte of נ (D7 A0) and other
  -- Hebrew letters, corrupting the UTF-8 stream.
  s = s:gsub("[ \t\r\n]+", " ")
  s = s:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")
  return s
end

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

  -- Non-HTML formats (e.g. Word/.docx): emit a native Pandoc table so it
  -- survives conversion, built by parsing a Markdown pipe table.
  if not (FORMAT and FORMAT:match("html")) then
    local md = { "| " .. table.concat(HEADERS, " | ") .. " |",
                 "|:--|:--|:--|:--|:--|:--|" }
    for i = 2, #rows do
      local r = rows[i]
      if cell(r, "date") ~= "" then
        local topic = html_to_md(cell(r, "topic"))
        local topic_url = cell(r, "topic_url")
        if topic_url ~= "" then topic = "[" .. topic .. "](" .. topic_url .. ")" end
        local datemd = "**" .. cell(r, "date") .. "** · יום " ..
          cell(r, "day") .. "׳ · " .. cell(r, "time")
        local unit_topic = "**" .. cell(r, "unit") .. ":** " .. topic
        md[#md + 1] = "| " .. table.concat({
          cell(r, "meeting"), datemd, unit_topic,
          html_to_md(cell(r, "materials")),
          html_to_md(cell(r, "task")),
          html_to_md(cell(r, "note"))
        }, " | ") .. " |"
      end
    end
    return pandoc.read(table.concat(md, "\n"), "markdown").blocks
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
