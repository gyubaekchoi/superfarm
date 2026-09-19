--!strict
-- 서비스 로더. Services/*.luau 를 Priority 내림차순 → 이름순으로 Init 후 Start.
local ServicesFolder = script.Parent:WaitForChild("Services")

type Service = { Name: string?, Priority: number?, Init: ((any) -> ())?, Start: ((any) -> ())? }

local list: { { name: string, svc: Service } } = {}
for _, m in ServicesFolder:GetChildren() do
	if m:IsA("ModuleScript") then
		local svc = require(m) :: Service
		svc.Name = m.Name
		table.insert(list, { name = m.Name, svc = svc })
	end
end
table.sort(list, function(a, b)
	local pa, pb = a.svc.Priority or 0, b.svc.Priority or 0
	if pa ~= pb then
		return pa > pb
	end
	return a.name < b.name
end)

local t0 = os.clock()
for _, e in list do
	if e.svc.Init then
		e.svc.Init(e.svc)
	end
end
for _, e in list do
	if e.svc.Start then
		task.spawn(e.svc.Start, e.svc)
	end
end

local names = {}
for _, e in list do
	table.insert(names, e.name)
end
print(
	("[SuperFarm] server ready · %d services (%s) · %.0fms"):format(
		#list,
		table.concat(names, ", "),
		(os.clock() - t0) * 1000
	)
)
