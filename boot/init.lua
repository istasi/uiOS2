local cinvoke,clist = component.invoke,component.list
local floor,rep = math.floor,string.rep
local pairs,ipairs,type = pairs,ipairs,type
local insert,remove = table.insert,table.remove
local tostring = tostring

local myAddress = computer.getBootAddress ()
local gpu = clist ( 'gpu',true ) ()
screen = clist ( 'screen',true ) ()
cinvoke ( gpu, 'bind', screen )
cinvoke ( gpu, 'setBackground', 0x000000 )
cinvoke ( gpu, 'setForeground', 0xFFFFFF )
local size = ({cinvoke ( gpu, 'getResolution' )})


local function clear () cinvoke ( gpu, 'fill', 1,1, size [1],size[2], ' ' ) end
clear ()


local status = {
	['bar'] = {
		['size'] = {
			['width'] = floor(size[1]/4),
			['height'] = 1,
		},
		['position'] = {
			['x'] = floor ( (size[1] - floor(size[1]/4)) / 2 ),
			['y'] = floor ( (size[2]) / 2 ),
		},
		['bgColor'] = 0x000000,
		['fgColor'] = 0xFFFFFF,
		['abColor'] = 0x990000,
		['afColor'] = 0xFFFFFF,

		['char'] = {
			['fill']  = ' ',
			['start'] = '[',
			['end']   = ']',
		},

		['clear'] = function ( self )
			if cinvoke ( gpu, 'getForeground' ) ~= self.fgColor then cinvoke ( gpu, 'setForeground', self.fgColor ) end
			if cinvoke ( gpu, 'getBackground' ) ~= self.bgColor then cinvoke ( gpu, 'setBackground', self.bgColor ) end

			for h = 1,self.size.height do
				cinvoke ( gpu, 'set', self.position.x,self.position.y + h - 1, self.char ['start'] .. rep ( self.char ['fill'], (self.size.width - 2) ) .. self.char ['end'] )
			end
		end,
		['set'] = function ( self, procent )
			local str = self.char ['start'] .. rep ( self.char ['fill'], (self.size.width - 2) ) .. self.char ['end']

			if cinvoke ( gpu, 'getForeground' ) ~= self.afColor then cinvoke ( gpu, 'setForeground', self.afColor ) end
			if cinvoke ( gpu, 'getBackground' ) ~= self.abColor then cinvoke ( gpu, 'setBackground', self.abColor ) end

			for h = 1,self.size.height do
				cinvoke ( gpu, 'set', self.position.x,self.position.y + h - 1, str:sub (1, math.floor (self.size.width * procent) ) )
			end
		end,
	},
	['message'] = {
		['position'] = {
			['x'] = floor ( size[1] / 2 ) - 1,
			['y'] = floor ( size[2] / 2 ) - 1,
		},
		['fgColor'] = 0xFFFFFF,
		['bgColor'] = 0x000000,

		['lastMessage'] = 1,

		['write'] = function ( self, message )
			if cinvoke ( gpu, 'getForeground' ) ~= self.fgColor then cinvoke ( gpu, 'setForeground', self.fgColor ) end
			if cinvoke ( gpu, 'getBackground' ) ~= self.bgColor then cinvoke ( gpu, 'setBackground', self.bgColor ) end

			if message:match ( '^[Ee]rror' ) then cinvoke ( gpu, 'setForeground', 0xFF0000 ) end

			if self.lastMessage > #message then
				local pad = math.ceil ( (self.lastMessage - #message) / 2 )
				self.lastMessage = #message

				message = rep ( ' ', pad ) .. message .. rep ( ' ', pad )
			else
				self.lastMessage = #message
			end

			local x = self.position.x - floor(#message / 2)

			cinvoke ( gpu, 'set', x,self.position.y, message )
			
		end,
	},
}

status.message:write ( 'Creating various boot tools' )
local function stall () while true do computer.pullSignal () end end
local function download ( url, _file )
	local internet = clist ( 'internet' ) ()
	if internet == nil then return false end

	local urlHandle = cinvoke ( internet, 'request', url .. (urlOpts or '') )

	local content = ''
	local continue = true

	while continue == true do
        local line = urlHandle.read ( 1024 )

		if line == nil then
			continue = false
		else
			content = content .. line
		end
	end
	urlHandle.close ()

	if _file == false then
		return content
	end

	local fileHandle = cinvoke ( myAddress, 'open', _file, 'w' )
	if fileHandle == nil then
		clear ()
		status.message:write ( 'Error while download (' .. url ..', '.. _file ..')' )

		stall ()
	end
	cinvoke ( myAddress, 'write', fileHandle, content )
	cinvoke ( myAddress, 'close', fileHandle )

	return true
end

local function loadfile ( _file, ... )
	if cinvoke ( myAddress, 'exists', _file ) == false then
		clear ()
		status.message:write ( 'Error while loadfile ('.. _file .. ').' )

		stall ()
	end

	local fileHandle = cinvoke ( myAddress, 'open', _file, 'r' )

	local content = ''
	local continue = true

	while continue == true do
        local line = cinvoke ( myAddress, 'read', fileHandle, 1024 )

		if line == nil then
			continue = false
		else
			content = content .. line
		end
	end
	cinvoke ( myAddress, 'close', fileHandle )

	local func, reason = load ( content, '=' .. _file, 't', _G )
	if type(func) ~= 'function' or reason ~= nil then
		clear ()
		status.message:write ( 'Error while loadfile ('.. _file .. '): ' .. tostring(reason) )

		stall ()
	end

	local state, reason = pcall ( func )
	if state == false or state == nil then
		clear ()
		status.message:write ( 'Error while loadfile ('.. _file .. '): ' .. tostring(reason) )

		stall ()
	end

	return reason
end

local function mkdir ( path )
	if cinvoke ( myAddress, 'exists', path ) == false then
		if cinvoke ( myAddress, 'makeDirectory', path ) == false then
			clear ()
			status.message:write ( 'Error while makeDirectory (' .. path .. ').' )

			stall ()
		end
	end
end
local function purgeEmptyDirectory ( path )
    if path:sub(1,1) ~= '/' then
        path = '/'.. path
    end

    local continue = true
    while continue == true do
        path = path:match ('(.-)/[^/]*/?$')

        local list = cinvoke ( myAddress, 'list', path )
        if type (list) == 'table' and #list == 0 then
            cinvoke ( myAddress, 'remove', path )
        end

        if path:len () < 1 or path == '.' then continue = false end
    end
end


-- Make sure we got the json lib so we can parse the response from github
if cinvoke ( myAddress, 'exists', '/lib/json.lua' ) == false then
    status.message:write ( 'Downloading json.lua' )

    download ( path ..'/lib/json.lua', '/lib/json.lua' )
end

status.message:write ( 'Loading json.lua' )
local json = loadfile ('/lib/json.lua')

status.message:write ( 'Checking for updates' );
local github = download ('https://api.github.com/repos/'.. _G ['github_repo'] ..'/git/trees/'.. _G ['github_branch'] ..'?recursive=1', false )
github = json.decode ( github ).tree

-- Build local version object so we can check which files we need to update
local version = {};
if cinvoke ( myAddress, 'exists', '/lib/version.db' ) == false then
    for k, v in pairs ( github ) do
        if v.type == "blob" then
            version [ v.path ] = 'download'
        end
    end
else
    local handle = cinvoke ( myAddress, 'open', '/lib/version.db', 'r' )

    local content = ''
    local continue = true

    while continue == true do
        local line = cinvoke ( myAddress, 'read', handle, 1024 )

        if line == nil then
            continue = false
        else
            content = content .. line
        end
    end
    cinvoke ( myAddress, 'close', handle )

    -- Parse the version.db file into something easy to handle
    for line in content:gmatch ('([^\n]*)\n?') do
        local key, value = line:match ('([^:]*) ?: ?(.*)')

        if key ~= nil then
            version [ key ] = value
        end
    end
end

-- Loop though the github object to see where the SHA doesnt match local version
local update = {}
for i, obj in pairs ( github ) do
    if obj.type == "blob" and (version [ obj.path ] == nil or version [ obj.path ] ~= obj.sha or cinvoke ( myAddress, 'exists', '/'.. path ) == false) then
        insert ( update, obj.path )
    end

    -- Mark which files exists on github, as the ones left over needs to be deleted
    version [ obj.path ] = nil
end

status.message:write ( 'Cleaning up' )
status.bar:clear ()

local length = 0
for _ in pairs ( version ) do
    length = length + 1
end

local at = 0
for file,_ in pairs ( version ) do
    at = at + 1
    status.bar:set ( at / length )

    -- Remove file if it exists
    if cinvoke ( myAddress, 'exists', file ) == true then
        --cinvoke ( myAddress, 'remove', file )
    end

    -- Regardless of whenever the file exists, we need to make sure we dont leave behind empty folders
    purgeEmptyDirectory ( file )
end


status.message:write ('Downloading updates')
status.bar:clear ()

local cache = {}
for i, _file in ipairs ( update ) do
    local path = ''
    local bits = {}

    for bit in _file:gmatch ( '([^%/]*/?)' ) do
        path = path .. bit
        
        if path:match ('%/$') then
            if path:sub(1,1) == '/' then path = path:sub(2) end

            if cinvoke ( myAddress, 'exists', path ) == false then
                mkdir ( path )
            end
        end
    end

    status.message:write ( _file )

    path = "/".. _file:match("(.*)/[^/]*")
    if cache [ path ] == nil then
        cache [ path ] = download ( 'https://api.github.com/repos/'.. github_repo ..'/contents'.. path ..'?ref='.. github_branch, false )
        print ( cache [ path ] )
    end
    --download ( _G['path'] ..'/'.. _file, '/'.. _file )
    status.bar:set ( i / #update )
end

-- Generate content of version.db
local content = ''
for i,obj in pairs ( github ) do
    if obj.type == "blob" then
        content = content.. obj.path .." : ".. obj.sha .."\n"
    end
end
local handle = cinvoke ( myAddress, 'open', '/lib/version.db', 'w' )
cinvoke ( myAddress, 'write', handle, content )
cinvoke ( myAddress, 'close', handle )