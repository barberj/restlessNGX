local http = require "resty.http"
local json = require "cjson.safe"
local shcache = require "resty.shcache"
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait

local _M = {}


local function requestJSON(uri)
  local httpc = http.new()
  local res, err = httpc:request_uri(uri)
  if err or not res then
    return nil, "xfailed to send request: " .. (err or "unknown error")
  end
  if res.status ~= 200 then
    local result, err = json.decode(res.body)
    local msg = not err and result.message or ("unexpected status " .. res.status)
    return nil, msg, res.status
  end
  local result, err = json.decode(res.body)
  if err then
    return nil, "cannot parse response: " .. err
  end
  return result, nil, res.status
end


function _M.getConsulServices(orgname)
  return requestJSON("http://192.168.99.100:8500/v1/catalog/services")
end


function _M.getOrg(orgname)
  -- perform both requests in parallel
  local tInfo = spawn(_M.getOrgInfo, orgname)
  local tMembers = spawn(_M.getOrgMembers, orgname)
  local ok, info, err, status = wait(tInfo)
  if not ok or err then
    return nil, err or "terminated", status
  end
  return info, nil, status
end


function _M.getOrgCached(orgname)
  local cache, err = shcache:new(ngx.shared.cache, {
    external_lookup = _M._orgLookup,
    external_lookup_arg = orgname,
    encode = json.encode,
    decode = json.decode
  }, {
    positive_ttl = 15,
    negative_ttl = 5,
    locks_shdict = "locks",
    name = "orgs"
  })
  if err or not cache then
    return nil, "cannot create cache: " .. (err or "error not provided")
  end
  local data = cache:load(orgname)
  if not data then
    return nil, "weird error: nil data"
  end
  return data.org, data.err, data.status
end


return _M
