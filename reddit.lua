dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end

  if (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if (string.match(url, "[^a-z0-9]"..item_value.."[0-9a-z]") and not string.match(url, "[^a-z0-9]"..item_value.."[0-9a-z][0-9a-z]")) or html == 0 then
      return true
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  if downloaded[url] ~= true then
    downloaded[url] = true
  end
 
  local function check(url)
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and (string.match(url, "[^a-z0-9]"..item_value.."[0-9a-z]") or string.match(url, "redditmedia%.com")) and not string.match(url, "[^a-z0-9]"..item_value.."[0-9a-z][0-9a-z]") and not string.match(url, "pixel%.redditmedia%.com") and not string.match(url, "stats%.redditmedia%.com") then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      elseif string.match(url, "#") then
        table.insert(urls, { url=string.match(url, "(https?:[^#]+)#") })
        addedtolist[url] = true
        addedtolist[string.match(url, "(https?:[^#]+)#")] = true
      elseif not string.match(url, "related/"..item_value.."[0-9a-zA-Z]%/[-_/0-9a-zA-Z]*/?$") and string.match(url, "related/"..item_value.."[0-9a-zA-Z]%/[-_/0-9a-zA-Z]*/") then
        --Ignore anything past the first related page, do nothing I think
        io.stdout:write("\nignoring related "..url.."\n")
      elseif string.match(url, "m%.reddit%.com/login/") then
        --Ignore the mobile login page, do nothing I think
      elseif string.match(url, "i%.redditmedia%.com/") then
        --Ignore the i.redditmedia.com, serves images for mobile and doesn't work, do nothing I think
        io.stdout:write("\nignoring i.redditmedia.com url "..url.."\n")
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end
  
  if string.match(url, "[^a-z0-9]"..item_value.."[0-9a-z]") and not string.match(url, "[^a-z0-9]"..item_value.."[0-9a-z][0-9a-z]") then
    html = read_file(file)
    for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
      check(newurl)
    end
    for newurl in string.gmatch(html, "'(https?://[^']+)'") do
      check(newurl)
    end
    for newurl in string.gmatch(html, '("/[^"]+)"') do
      if string.match(newurl, '"//') then
        check(string.gsub(newurl, '"//', 'http://'))
      elseif not string.match(newurl, '"//') then
        check(string.match(url, "(https?://[^/]+)/")..string.match(newurl, '"(/.+)'))
      end
    end
    for newurl in string.gmatch(html, "('/[^']+)'") do
      if string.match(newurl, "'//") then
        check(string.gsub(newurl, "'//", "http://"))
      elseif not string.match(newurl, "'//") then
        check(string.match(url, '(https?://[^/]+)/')..string.match(newurl, "'(/.+)"))
      end
    end
  end
  
  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")

    tries = tries + 1

    if tries >= 6 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")
    
    tries = tries + 1

    if tries >= 6 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
