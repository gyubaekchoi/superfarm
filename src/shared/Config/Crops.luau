--!strict
-- 작물 정의. 색은 {r,g,b} 0~255 (클라에서 Color3 변환). mesh는 에셋 업로드 후 채움.
export type CropDef = {
	zone: string,
	price: number,
	growSec: number,
	color: { number },
	mesh: string,
	tree: boolean?,
	perTree: number?,
}

local Crops: { [string]: CropDef } = {
	Wheat = { zone = "Z1", price = 1, growSec = 6, color = { 240, 200, 80 }, mesh = "" },
	Rice = { zone = "Z1", price = 2, growSec = 8, color = { 230, 230, 200 }, mesh = "" },
	Corn = { zone = "Z2", price = 5, growSec = 10, color = { 250, 210, 60 }, mesh = "" },
	Potato = { zone = "Z2", price = 8, growSec = 12, color = { 200, 160, 100 }, mesh = "" },
	Apple = { zone = "Z3", price = 20, growSec = 15, color = { 230, 60, 60 }, mesh = "", tree = true, perTree = 5 },
	Orange = { zone = "Z3", price = 30, growSec = 18, color = { 255, 150, 40 }, mesh = "", tree = true, perTree = 5 },
}

return Crops
