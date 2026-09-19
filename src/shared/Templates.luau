--!strict
-- ReplicatedStorage/Assets 템플릿 조회·복제. 템플릿이 없으면 nil (호출자가 프리미티브로 대체).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Templates = {}
local folder: Instance? = nil

local function getFolder(): Instance?
	if folder and folder.Parent then
		return folder
	end
	folder = ReplicatedStorage:FindFirstChild("Assets")
	return folder
end

function Templates.has(name: string): boolean
	local f = getFolder()
	return f ~= nil and f:FindFirstChild(name) ~= nil
end

function Templates.get(name: string): Model?
	local f = getFolder()
	local t = f and f:FindFirstChild(name)
	return if t and t:IsA("Model") then t else nil
end

-- 복제 후 바닥 중심 피벗을 cf 에 놓는다 (템플릿 피벗은 바운딩 박스 바닥 중심)
function Templates.spawn(name: string, cf: CFrame, parent: Instance, newName: string?): Model?
	local t = Templates.get(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if newName then
		m.Name = newName
	end
	m:PivotTo(cf)
	m:SetAttribute("Template", name)
	m.Parent = parent
	return m
end

-- 바운딩 박스 크기
function Templates.size(name: string): Vector3?
	local t = Templates.get(name)
	if not t then
		return nil
	end
	local _, size = t:GetBoundingBox()
	return size
end

return Templates
