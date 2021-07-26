local function write_file(file_name, content)
    if not file_name then
        return nil,"missing file_name"
    end
    local content = content or "";
    local file = io.open(file_name, "w")
    if not file then
        return "can\'t open file " .. file_name
    end
    file:write(content)
    file:close()
    return nil
end
local function read_file(file_name)
    if not file_name then
        return nil, "missing file_name"
    end
    local file = io.open(file_name,"r")
    if not file then
        return nil, "can\'t open file " .. file_name
    end
    local content = file:read("*all")
    file:close()
    return content, nil
end
function get_from_cache(key)
    local cache_ngx = ngx.shared.my_cache
    local value = cache_ngx:get(key)
    return value
end 
function delete_from_cache(key)
    local cache_ngx = ngx.shared.my_cache
    local value = cache_ngx:delete(key)
end 
function set_to_cache(key,value,exptime)
    if not exptime then
        exptime = 86400
    end
    local cache_ngx = ngx.shared.my_cache
    local succ,err,forcible = cache_ngx:set(key, value,exptime)
    return succ
end

local uri = ngx.var.uri;
local uri_args = ngx.req.get_uri_args();
local request_uri = ngx.var.request_uri;
local md5 = ngx.md5
local key = md5(request_uri)

--- https://blog.csdn.net/wtswjtu/article/details/38898945
cache_file = string.gsub(request_uri,"/","_")

local item_model = get_from_cache(key)
--- local item_model = nil
if item_model == nil then
    local backend_url = ngx.var.proxy;
    local method = uri_args["method"]
    local http = require("resty.http");
    local httpc = http.new();
    httpc:set_timeout(10000);
    local resp, err = httpc:request_uri(
        backend_url,   -- 请求地址
        {
            headers = {
                ["Host"]= ngx.var.host,
            },
            method = method,  -- 请求方式
            path = uri,      -- 接口地址
            query=uri_args    -- 请求参数
                                  
        }           
    )
    if not resp then
        ngx.header["X-Cache"] = "geturl timeout"
        ngx.exit(ngx.HTTP_BAD_GATEWAY)   --- https://www.cnblogs.com/tinywan/p/6538006.html
    end
    if resp.status ~= 200 then
	ngx.exit(resp.status)
    end
    ngx.header["Content-type"] = "text/html; charset=utf-8"
    ngx.header["X-Cache"] = "url-cache"
    ngx.say(resp.body);
    set_to_cache(key,1,2*86400)
    write_file("/xq_data/cache/"..ngx.var.host.."/" .. cache_file, resp.body)
    httpc:close();
else
    local content,err = read_file("/xq_data/cache/"..ngx.var.host.."/" .. cache_file)
    if err == nil then
        ngx.header["Content-type"] = "text/html; charset=utf-8"
        ngx.header["X-Cache"] = "file-cache"
        ngx.say(content)
        ngx.exit(ngx.OK)
    else
        delete_from_cache(key)
        ngx.header["X-Cache"] = "read file error"
        ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
end
