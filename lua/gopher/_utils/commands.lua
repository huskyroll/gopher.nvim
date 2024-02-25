---Run any go commands like `go generate`, `go get`, `go mod`
---@param cmd string
---@param ... string|string[]
return function(cmd, ...)
    local Job = require "plenary.job"
    local c = require("gopher.config").config.commands
    local u = require "gopher._utils"

    local args = { ... }
    if #args == 0 then
        u.notify("please provice any arguments", "error")
        return
    end

    if cmd == "generate" and #args == 1 and args[1] == "%" then
        args[1] = vim.fn.expand "%" ---@diagnostic disable-line: missing-parameter
    elseif cmd == "get" then
        for i, arg in ipairs(args) do
            ---@diagnostic disable-next-line: param-type-mismatch
            local m = string.match(arg, "^https://(.*)$") or string.match(arg, "^http://(.*)$") or arg
            table.remove(args, i)
            table.insert(args, i, m)
        end
    end

    if cmd == "run" and #args == 1 and args[1] == "%" then
        args[1] = vim.fn.expand "%" ---@diagnostic disable-line: missing-parameter
        local cmd_args = vim.list_extend({ cmd }, args) ---@diagnostic disable-line: missing-parameter
        local full_command = c.go .. " " .. table.concat(cmd_args, " ")
        local bufnr = vim.api.nvim_create_buf(false, true)

        -- Calculate the height and position of the new window
        local height = math.floor(vim.o.lines * 0.25)
        local width = vim.o.columns
        local row = vim.o.lines - height

        -- Create a new window at the bottom of the screen
        local win_id = vim.api.nvim_open_win(bufnr, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = 0,
            style = "minimal",
        }) -- Create a new terminal

        local job_id = vim.fn.termopen(full_command)

        local job = Job:new {
            command = c.go,
            args = cmd_args,
            on_exit = function(_, retval)
                if retval ~= 0 then
                    u.notify("command 'go " .. unpack(cmd_args) .. "' exited with code " .. retval, "error")
                    u.notify(cmd .. " " .. unpack(cmd_args), "debug")
                    return
                end

                u.notify("go " .. cmd .. " was successful.", "info")
            end,
        }
        job:start()
    else
        Job
            :new({
                command = c.go,
                args = cmd_args,
                on_exit = function(_, retval)
                    if retval ~= 0 then
                        u.notify("command 'go " .. unpack(cmd_args) .. "' exited with code " .. retval, "error")
                        u.notify(cmd .. " " .. unpack(cmd_args), "debug")
                        return
                    end

                    u.notify("go " .. cmd .. " was successful.", "info")
                end,
            })
            :start()
    end

    local function open_term_and_run_job(command, args)
        -- Create a new buffer and open it in a new split window
        -- Create a new job
        local job = Job:new {
            command = command,
            args = args,
            on_stdout = function(j, data)
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { data })
            end,
        }

        -- Start the job
        job:start()
    end
end
