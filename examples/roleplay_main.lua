local skynet = require "skynet"
local socket = require "skynet.socket"

local string = string
local table = table
local tonumber = tonumber

local MAX_HISTORY = 8

local function trim_line(line)
	return (line:gsub("\r", ""):gsub("%s+$", ""))
end

local function add_history(state, role, text)
	table.insert(state.history, { role = role, text = text })
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
		table.insert(lines, string.format("[%s] %s", item.role, item.text))
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

local function generate_reply(state, line)
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

local function handle_client(fd, addr)
	local state = build_state(addr)
	send_line(fd, "欢迎来到北风旅店。输入 help 查看指令。")
	send_line(fd, string.format("你来自 %s ，现在可以开始对话：", addr))
	while true do
		local line, rest = socket.readline(fd, "\n")
		if line == false then
			line = rest
		end
		if not line or line == "" then
			break
		end

		line = trim_line(line)
		if line == "" then
			send_line(fd, "（老板抬眼看了你一眼，等待你的回应。）")
		else
			add_history(state, state.player_name, line)
			local reply = generate_reply(state, line)
			add_history(state, state.innkeeper, reply)
			send_line(fd, reply)
			if line == "quit" or line == "退出" then
				break
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
