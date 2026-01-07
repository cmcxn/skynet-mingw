local skynet = require "skynet"
local socket = require "skynet.socket"
local httpc = require "http.httpc"
local tls_available = pcall(require, "ltls.c")

local string = string
local table = table
local tonumber = tonumber

local MAX_HISTORY = 8

local function trim_line(line)
	return (line:gsub("\r", ""):gsub("%s+$", ""))
end

local function add_history(state, role, label, text)
	table.insert(state.history, { role = role, label = label, text = text })
	if #state.history > MAX_HISTORY then
		table.remove(state.history, 1)
	end
end

local function format_history(state)
	if #state.history == 0 then
		return "（目前还没有对话记录。）"
	end
	local lines = {}
	for _, item in ipairs(state.history) do
		table.insert(lines, string.format("[%s] %s", item.label or item.role, item.text))
	end
	return table.concat(lines, "\r\n")
end

local function build_state(addr)
	return {
		player_name = "旅人",
		innkeeper = "艾尔",
		persona = "旅店老板",
		addr = addr,
		history = {},
	}
end

local function command_reply(state, line)
	local lower = string.lower(line)
	if lower == "help" or line == "帮助" then
		return table.concat({
			"可用指令：",
			"  help / 帮助：查看指令",
			"  name:你的名字（或 名字:你的名字）",
			"  设定:老板人设（可选）",
			"  history / 历史：查看最近对话",
			"  quit / 退出：结束会话",
			"其他任意内容会被当作角色扮演对话。",
		}, "\r\n")
	end
	if lower == "history" or line == "历史" then
		return format_history(state)
	end
	if lower == "quit" or line == "退出" then
		return "愿你的旅途一路平安。"
	end

	local name = line:match("^name:%s*(.+)$") or line:match("^名字:%s*(.+)$")
	if name and name ~= "" then
		state.player_name = name
		return string.format("从现在起，我会叫你 %s。", state.player_name)
	end

	local persona = line:match("^设定:%s*(.+)$")
	if persona and persona ~= "" then
		state.persona = persona
		return string.format("好，我会以“%s”的人设与你对话。", state.persona)
	end

	return nil
end

local function json_escape(value)
	return (value:gsub("[\\\"\b\f\n\r\t]", {
		["\\"] = "\\\\",
		["\""] = "\\\"",
		["\b"] = "\\b",
		["\f"] = "\\f",
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
	}))
end

local function build_messages(state)
	local system = string.format(
		"你是奇幻世界酒馆里的%s，请用中文进行角色扮演。玩家名叫%s。",
		state.persona or "旅店老板",
		state.player_name
	)
	local messages = {
		string.format("{\"role\":\"system\",\"content\":\"%s\"}", json_escape(system)),
	}
	for _, item in ipairs(state.history) do
		table.insert(
			messages,
			string.format(
				"{\"role\":\"%s\",\"content\":\"%s\"}",
				item.role,
				json_escape(item.text)
			)
		)
	end
	return "[" .. table.concat(messages, ",") .. "]"
end

local function decode_json_string(body, start_index)
	local i = start_index
	local out = {}
	while i <= #body do
		local ch = body:sub(i, i)
		if ch == "\\" then
			local next_ch = body:sub(i + 1, i + 1)
			if next_ch == "n" then
				table.insert(out, "\n")
			elseif next_ch == "r" then
				table.insert(out, "\r")
			elseif next_ch == "t" then
				table.insert(out, "\t")
			elseif next_ch == "b" then
				table.insert(out, "\b")
			elseif next_ch == "f" then
				table.insert(out, "\f")
			else
				table.insert(out, next_ch)
			end
			i = i + 2
		elseif ch == "\"" then
			return table.concat(out), i
		else
			table.insert(out, ch)
			i = i + 1
		end
	end
	return nil
end

local function extract_first_content(body)
	local key = "\"content\""
	local start_pos = body:find(key, 1, true)
	if not start_pos then
		return nil
	end
	local colon = body:find(":", start_pos + #key)
	if not colon then
		return nil
	end
	local quote = body:find("\"", colon + 1)
	if not quote then
		return nil
	end
	return decode_json_string(body, quote + 1)
end

local function request_openai(state)
	local api_key = skynet.getenv("openai_api_key")
	if not api_key or api_key == "" then
		return nil, "missing openai_api_key"
	end
	if not tls_available then
		return nil, "tls unavailable (ltls.c not loaded)"
	end
	local body = string.format(
		"{\"model\":\"gpt-4o\",\"messages\":%s}",
		build_messages(state)
	)
	local ok, status, resp = pcall(
		httpc.request,
		"POST",
		"https://api.openai.com",
		"/v1/chat/completions",
		{},
		{
			["content-type"] = "application/json",
			["authorization"] = "Bearer " .. api_key,
		},
		body
	)
	if not ok then
		return nil, status
	end
	if status ~= 200 then
		return nil, string.format("openai status %s", tostring(status))
	end
	local content = extract_first_content(resp)
	if not content then
		return nil, "openai response missing content"
	end
	return content
end

local function generate_reply(state, line)
	if line:find("任务") or line:find("quest") then
		return string.format(
			"【%s】%s压低声音对%s说：最近的森林里确实有异动，但情报要用故事交换。",
			state.persona,
			state.innkeeper,
			state.player_name
		)
	end
	if line:find("酒") or line:find("喝") then
		return string.format(
			"【%s】%s给%s斟了杯热麦酒：第一杯算我请。",
			state.persona,
			state.innkeeper,
			state.player_name
		)
	end

	return string.format(
		"【%s】%s点点头，对%s说：\"%s\" 我记下了你的话。",
		state.persona,
		state.innkeeper,
		state.player_name,
		line
	)
end

local function send_line(fd, text)
	socket.write(fd, text .. "\r\n")
end

local function read_line(state, fd)
	local buffer = {}
	local pending = state.pending_char
	state.pending_char = nil
	while true do
		local ch
		if pending then
			ch = pending
			pending = nil
		else
			ch = socket.read(fd, 1)
		end
		if not ch or ch == "" then
			return nil
		end
		if ch == "\n" then
			break
		elseif ch == "\r" then
			local next_ch = socket.read(fd, 1)
			if next_ch and next_ch ~= "" and next_ch ~= "\n" then
				state.pending_char = next_ch
			end
			break
		else
			table.insert(buffer, ch)
		end
	end
	return table.concat(buffer)
end

local function handle_client(fd, addr)
	local state = build_state(addr)
	send_line(fd, "欢迎来到北风旅店。输入 help 查看指令。")
	send_line(fd, string.format("你来自 %s ，现在可以开始对话：", addr))
	while true do
		local line = read_line(state, fd)
		if not line or line == "" then
			break
		end

		line = trim_line(line)
		if line == "" then
			send_line(fd, "（老板抬眼看了你一眼，等待你的回应。）")
		else
			skynet.error(string.format("roleplay recv from %s: %s", state.addr, line))
			local reply = command_reply(state, line)
			if reply then
				send_line(fd, reply)
				if line == "quit" or line == "退出" then
					break
				end
			else
				add_history(state, "user", state.player_name, line)
				skynet.error("roleplay request openai")
				local ai_reply, err = request_openai(state)
				if not ai_reply then
					skynet.error(string.format("openai reply failed: %s", tostring(err)))
					ai_reply = generate_reply(state, line)
				end
				add_history(state, "assistant", state.innkeeper, ai_reply)
				skynet.error("roleplay reply ready")
				send_line(fd, ai_reply)
			end
		end
	end
	socket.close(fd)
end

skynet.start(function()
	local port = tonumber(skynet.getenv("roleplay_port")) or 7001
	local listen_fd = socket.listen("0.0.0.0", port)
	skynet.error(string.format("Roleplay chat listen on 0.0.0.0:%d", port))
	socket.start(listen_fd, function(fd, addr)
		socket.start(fd)
		skynet.fork(handle_client, fd, addr)
	end)
end)
