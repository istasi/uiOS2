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
				cinvoke ( gpu, 'set', self.position.x,self.position.y + h - 1, str:sub (1,#str * procent) )
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
		local line = cinvoke ( internet, 'read', urlHandle )
		if line == nil then
			continue = false
		else
			content = content .. line
		end
	end
	cinvoke ( internet, 'close', urlHandle )

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

status.message:write ( 'Fetching current version.db' .. (urlOpts or '') )
local content = download ( repo .. 'config/version.db', false )
if content ~= false then
	local function p ( content )
		local o = {}
		for line in content:gmatch ('([^\n]*)\n?') do
			local key, value = line:match ('([^:]*) ?: ?(.*)')
			if key ~= nil then
				o [key] = value
			end
		end

		return o
	end
	local function s ( content )
		if cinvoke ( myAddress, 'exists', '/config/' ) == false then
			cinvoke ( myAddress, 'makeDirectory', '/config/' )
		end

		local h = cinvoke ( myAddress, 'open', '/config/version.db', 'w' )
		cinvoke ( myAddress, 'write', h, content )
		cinvoke ( myAddress, 'close', h )
	end
	local function g ()
		if cinvoke ( myAddress, 'exists', '/config/' ) == false then return '' end

		local h = cinvoke ( myAddress, 'open', '/config/version.db', 'r' )

		local content = ''
		local c = true

		while c == true do
			local l = cinvoke ( myAddress, 'read', h, 1024 )
			if l == nil then
				c = false
			else
				content = content .. l
			end
		end
		cinvoke ( myAddress, 'close', h )

		return content
	end

	status.message:write ( 'Checking for updates' )
	local offline = p( g() ) -- yes, it most certainly is ugly.
	local online = p(content)

	local list = {}
	for file, date in pairs ( online ) do
		if (offline [file] == nil or offline[file] < date) or cinvoke ( myAddress, 'exists', file ) == false then
			insert ( list, file )
		end

		offline [file] = nil
	end

	local function cp ( path )
		local continue = true
		while continue == true do
			path = path:match ('(.-)/[^/]*/?$')

			local l = cinvoke ( myAddress, 'list', path )
			if type(l) == 'table' and #l == 0 then 
				cinvoke ( myAddress, 'remove', path )
			end

			if path:len () < 1 or path == '.' then continue = false end
		end

		return true
	end

	status.message:write ( 'Cleaning up' )
	for file,_ in pairs (offline) do
		status.message:write ( 'Removing ' .. file:match ('([^/]*)$') )

		if cinvoke ( myAddress, 'exists', file ) == true then
			cinvoke ( myAddress, 'remove', file )
		end
		cp (file)
	end

	s(content)

	status.bar:clear ()

	for i, _file in ipairs ( list ) do
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
		download ( repo .. _file, _file )
		status.bar:set ( i / #list )
	end
end
_G ['repo'] = nil

status.message:write ( 'loading system' )
if cinvoke ( myAddress, 'exists', 'boot/load' ) == false then
	clear ()
	status.message:write ( 'Error while loading system: No files to load' )

	stall ()
end

status.bar.abColor = 0x009900
local list = cinvoke ( myAddress, 'list', 'boot/load' )
if type(list) ~= 'table' then
	clear ()
	status.message:write ( 'Error while attempting to list: boot/load' )

	stall ()
end

for i, _file in ipairs (list) do
	_G [ _file:match( '(.-)%.lua') ] = loadfile ( 'boot/load/' .. _file )
	status.bar:set ( i / #list )
end

status.message:write ( 'Starting system' )
local reason = loadfile ( 'start.lua' )

gpu = clist( 'gpu', true ) ()
if type(reason) == 'table' then
	if type(reason [1]) == 'number' then reason [1] = 'Process id: ' .. reason [1] end
	reason = table.concat ( reason, ', ' )
end

if type(reason) ~= 'string' then
	reason = 'System stopped unexpectedly' 
end

cinvoke ( gpu, 'setBackground', 0x000000 )
clear ()

local lines = {}
insert ( lines, "system returned: " )
for line in reason:gmatch ( '([^\n]*)\n?' ) do
	insert ( lines, line )
end
if #lines < 2 then insert ( lines, reason ) end

local longest = 1
for _,line in ipairs ( lines ) do
	longest = math.max ( longest, line:len () )
end

cinvoke ( gpu, 'setForeground', 0xFF0000 )
local size = ({cinvoke ( gpu, 'getResolution' )})
if size == nil then
	cinvoke ( gpu, 'bind', clist('screen',true)())
	size = ({cinvoke( gpu, 'getResolution')})
end
if size == nil or size[1] == nil or size[2] == nil then size = {80,25} end -- Retarded check.

local x = size[1] / 2
x = x - (longest / 2)

local y = size[2] / 2
y = y - (#lines / 2)

for i,line in ipairs ( lines ) do
	cinvoke ( gpu, 'set', x,y + i, tostring(line:gsub('%\t','  ')) )
end

stall ()