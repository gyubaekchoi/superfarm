--!strict
-- 컨트롤러 로더. Controllers/*.luau (직속 ModuleScript만) Init → Start.
local ControllersFolder = script.Parent:WaitForChild("Controllers")

type Controller = { Name: string?, Priority: number?, Init: ((any) -> ())?, Start: ((any) -> ())? }

local list: { { name: string, ctl: Controller } } = {}
for _, m in ControllersFolder:GetChildren() do
	if m:IsA("ModuleScript") then
		local ctl = require(m) :: Controller
		ctl.Name = m.Name
		table.insert(list, { name = m.Name, ctl = ctl })
	end
end
table.sort(list, function(a, b)
	local pa, pb = a.ctl.Priority or 0, b.ctl.Priority or 0
	if pa ~= pb then
		return pa > pb
	end
	return a.name < b.name
end)

for _, e in list do
	if e.ctl.Init then
		e.ctl.Init(e.ctl)
	end
end
for _, e in list do
	if e.ctl.Start then
		task.spawn(e.ctl.Start, e.ctl)
	end
end

local names = {}
for _, e in list do
	table.insert(names, e.name)
end
print(("[SuperFarm] client ready · %d controllers (%s)"):format(#list, table.concat(names, ", ")))
