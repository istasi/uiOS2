_G ['repo'] = 'istasi/uiOS2';
_G ['branch'] = 'master';
_G ['url'] = 'https://raw.githubusercontent.com';

local address = component.list ('internet', true) ();
address = address or computer.getBootAddress ();

local handle = nil
if address ~= computer.getBootAddress () then
	handle = component.invoke ( address, _G['url'] ..'/'.. _G ['repo'] ..'/'.. _G ['branch'] ..'/boot/init.lua' );
else
	handle = component.invoke ( address, 'open', '/boot/init.lua' );
end

local content = '';
local continue = true;

while continue == true do
	local line = component.invoke ( address, 'read', handle, 1024 );

	if line == nil then
		continue = false
	else
		content = content .. line
	end
end
component.invoke ( address, 'close', handle );

if address ~= computer.getBootAddress () then
	local address = computer.getBootAddress ()

	if component.invoke ( address, 'exists', '/boot/' ) == false then
		component.invoke ( address, 'makeDirectory', '/boot/' )
	end

	local handle = component.invoke ( address, 'open', '/boot/init.lua', 'w' )
	component.invoke ( address, 'write', handle, content )
	component.invoke ( address, 'close', handle )
end


local f,e = load ( content, 'boot/init.lua' )
if type(f) ~= 'function' then error (e or 'function not returned') end
f ()