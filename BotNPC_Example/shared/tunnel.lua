--tunnel.lua shared cache false

-- class's resource's
Tunnel = { };
Tunnel.middleware = { };
Tunnel.token = nil;

-- Local cache for performance
local _type = type;
local _unpack = unpack;
local _isElement = isElement;
local _triggerServerEvent = triggerServerEvent;
local _triggerClientEvent = triggerClientEvent;
local _addEvent = addEvent;
local _addEventHandler = addEventHandler;
local _setTimer = setTimer;
local _localPlayer = localPlayer;
local _resourceRoot = resourceRoot;
local _root = root;
local _md5 = md5;

function Tunnel.setToken (token)
	Tunnel.token = token;
end

-- Helper for dynamic function obfuscation
local function obfuscate(name, token)
	if (not token) then return name end
	return _md5(name .. token)
end

-- callback's resource's
local callbacks, callbacksId = { }, 0;

-- middleware's resource's
setmetatable (Tunnel.middleware, {
	__call = function (self, func)
		if (_type (func) ~= 'function') then
			return false;
		end

		self[#self + 1] = func;
		return true;
	end
});

local function runMiddlewares (func, args, player, token, sourceRes)
	local items = Tunnel.middleware;
	if (#items < 1) then
		return true, args;
	end

	for _, middleware in pairs (items) do
		local status, message, new = middleware (func, args, player, token, sourceRes);
		if (not status) then
			return false, message;
		end

		if (new) then
			args = new;
		end
	end
	return true, args;
end

-- method's resource's
function Tunnel.get (name, target)
	return setmetatable ({ }, {
		__index = function (_, func)
			return function (...)
				local args = {...}
				local s2c_target = nil -- Server to Client Target

				-- If we are on server and the first arg is a player, it's the target
				if (not _isElement(_localPlayer) and _isElement(args[1]) and getElementType(args[1]) == "player") then
					s2c_target = table.remove(args, 1)
				end

				callbacksId = (callbacksId + 1);
				local reqId = callbacksId;

				local promise = { };
				promise.try = function (self, fn) promise._try = fn return promise end
				promise.catch = function (self, fn) promise._catch = fn return promise end
				promise.timeout = function (self, ms) _setTimer (function () if (not callbacks[reqId]) then return false end if (_type (promise._catch) == 'function') then promise._catch ('timeout') end callbacks[reqId] = nil return true end, ms, 1) return promise end

				callbacks[reqId] = function (status, ...)
					local cb_args = { ... };
					
					local argType = _type (cb_args[1]);
					if (argType == 'nil') or (argType == 'boolean') then
						table.remove (cb_args, 1);
					end

					if (status) and (_type (promise._try) == 'function') then
						return promise._try (_unpack (cb_args));
					end

					if (not status) and (_type (promise._catch) == 'function') then
						return promise._catch (_unpack (cb_args));
					end
					return false;
				end

				if (_isElement (_localPlayer)) then
					_triggerServerEvent ('__tunnel:' .. name, _resourceRoot, obfuscate(func, Tunnel.token), args, reqId, Tunnel.token);
				else
					_triggerClientEvent ((s2c_target or target or _root), '__tunnel:' .. name, _resourceRoot, obfuscate(func, Tunnel.token), args, reqId, Tunnel.token);
				end

				return promise;
			end
		end,
	});
end

function Tunnel.bind (name, interface, options)
	local eventName = '__tunnel:' .. name;
	
	-- Map of obfuscated names to original names
	local obfuscatedMap = {}
	for funcName, _ in pairs(interface) do
		-- This is pre-calculated but we need the player token. 
		-- Since token is dynamic per player, we must calculate in the handler.
	end

	_addEvent (eventName, true);
	_addEventHandler (eventName, _resourceRoot,
		function (func, args, reqId, token)
			-- Find the original function by matching the obfuscated name
			local originalFunc = nil
			for funcName, _ in pairs(interface) do
				if (obfuscate(funcName, token) == func) then
					originalFunc = funcName
					break
				end
			end

			if (not originalFunc or not interface[originalFunc]) then
				return false;
			end

			if (reqId) then
				local isClient = _isElement (_localPlayer);
				if (isClient) then
					local result = { interface[originalFunc] (_unpack (args)) };
					return _triggerServerEvent ('__tunnel:callback', _resourceRoot, reqId, result);
				end

				if (not _isElement (client)) then
					return false;
				end

				local sourceRes = sourceResource and getResourceName(sourceResource) or "unknown";

				-- Per-interface Resource Whitelist
				if (options and options.allowedResources) then
					local allowed = false;
					for _, resName in ipairs(options.allowedResources) do
						if (resName == sourceRes) then
							allowed = true;
							break;
						end
					end
					if (not allowed) then
						return _triggerClientEvent (client, '__tunnel:callback', _resourceRoot, reqId, { false, "Resource '" .. sourceRes .. "' is not allowed to call this interface." });
					end
				end

				local status, message = runMiddlewares (originalFunc, args, client, token, sourceRes);
				if (not status) then
					return _triggerClientEvent (client, '__tunnel:callback', _resourceRoot, reqId, { false, message });
				end

				local result = { interface[originalFunc] (client, _unpack (message)) };
				return _triggerClientEvent (client, '__tunnel:callback', _resourceRoot, reqId, result);
			end
			return false;
		end
	);

	return true;
end

-- custom's event's resource's
_addEvent ('__tunnel:callback', true);
_addEventHandler ('__tunnel:callback', _resourceRoot,
	function (reqId, result)
		if (not callbacks[reqId]) then
			return false;
		end

		local resultType = _type (result[1]);
		local status = (result[1] ~= false) and (resultType ~= 'nil');
		callbacks[reqId] (status, _unpack (result));
		callbacks[reqId] = nil;

		collectgarbage ("step", 50); -- Optimized garbage collection
		return true;
	end
);
