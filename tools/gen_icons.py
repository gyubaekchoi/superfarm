# 플랫 아이콘 32종 생성 (256x256 PNG, 두꺼운 외곽선, 채도 높은 색). python3 tools/gen_icons.py
from PIL import Image, ImageDraw
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
S = 256
LINE = (52, 40, 70, 255)     # 외곽선 (짙은 남보라)
LW = 12                      # 외곽선 두께

def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))

def hi(c, k=1.18):  # 하이라이트
    return tuple(min(255, int(v * k)) for v in c[:3]) + (255,)
def lo(c, k=0.78):
    return tuple(int(v * k) for v in c[:3]) + (255,)

def poly(d, pts, fill):
    d.polygon(pts, fill=fill, outline=LINE)
    d.line(pts + [pts[0]], fill=LINE, width=LW, joint="curve")

def circle(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=LINE, width=LW)

def rrect(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=LINE, width=LW)

def star_pts(cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = rot + i * math.pi / n
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts

def gloss(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r * 0.45, cy - r * 0.7, cx - r * 0.05, cy - r * 0.35], fill=(255, 255, 255, 160))

GOLD = (255, 200, 60, 255)
def icon_coin(d, img):
    circle(d, 128, 128, 100, GOLD); circle(d, 128, 128, 64, hi(GOLD, 1.08)); gloss(img, 128, 128, 100)
def icon_coin_gold(d, img):
    circle(d, 128, 128, 100, (255, 170, 30, 255)); poly(d, star_pts(128, 128, 58, 26), (255, 240, 150, 255)); gloss(img, 128, 128, 100)
def icon_stone(d, img):
    c = (90, 200, 255, 255)
    poly(d, [(128, 30), (222, 100), (176, 226), (80, 226), (34, 100)], c)
    d.polygon([(128, 30), (222, 100), (128, 100)], fill=hi(c)); d.polygon([(34, 100), (128, 100), (80, 226)], fill=lo(c))
    d.line([(128, 30), (222, 100), (176, 226), (80, 226), (34, 100), (128, 30)], fill=LINE, width=LW, joint="curve")
def icon_ticket(d, img):
    c = (255, 120, 150, 255)
    rrect(d, [24, 70, 232, 186], 22, c)
    for x in (24, 232):
        d.ellipse([x - 22, 106, x + 22, 150], fill=(0, 0, 0, 0)); d.ellipse([x - 22, 106, x + 22, 150], outline=LINE, width=LW)
    d.line([(128, 82), (128, 174)], fill=(255, 255, 255, 200), width=10)
def icon_star(d, img):
    poly(d, star_pts(128, 132, 104, 46), GOLD); gloss(img, 128, 120, 90)
def icon_shoe(d, img, c=(80, 150, 255, 255)):
    poly(d, [(40, 150), (40, 90), (110, 90), (150, 130), (220, 150), (230, 190), (40, 190)], c)
    rrect(d, [40, 180, 230, 208], 10, (240, 240, 245, 255))
def icon_shoe_gold(d, img): icon_shoe(d, img, GOLD)
def icon_sickle(d, img, c=(200, 205, 215, 255)):
    d.arc([40, 30, 220, 210], start=200, end=60, fill=LINE, width=LW + 30)
    d.arc([40, 30, 220, 210], start=200, end=60, fill=c, width=30)
    rrect(d, [120, 150, 156, 236], 12, (150, 100, 60, 255))
def icon_sickle_gold(d, img): icon_sickle(d, img, GOLD)
def icon_bag(d, img, c=(230, 150, 70, 255)):
    rrect(d, [46, 80, 210, 226], 30, c); rrect(d, [88, 30, 168, 100], 24, lo(c)); rrect(d, [80, 130, 176, 176], 14, hi(c))
def icon_bag_gold(d, img): icon_bag(d, img, GOLD)
def icon_bolt(d, img):
    poly(d, [(150, 20), (70, 140), (124, 140), (104, 236), (190, 106), (136, 106)], GOLD)
def icon_lock(d, img, c=(140, 140, 160, 255), open_=False):
    rrect(d, [50, 110, 206, 230], 22, c)
    if open_:
        d.arc([70, 20, 186, 136], start=180, end=360 + 20, fill=LINE, width=LW + 22); d.arc([70, 20, 186, 136], start=180, end=380, fill=hi(c), width=22)
    else:
        d.arc([70, 30, 186, 146], start=180, end=360, fill=LINE, width=LW + 22); d.arc([70, 30, 186, 146], start=180, end=360, fill=hi(c), width=22)
    circle(d, 128, 165, 16, LINE)
def icon_unlock(d, img): icon_lock(d, img, (120, 220, 120, 255), True)
def icon_shop(d, img):
    c = (90, 150, 230, 255)
    poly(d, [(40, 130), (60, 60), (196, 60), (216, 130)], (255, 90, 90, 255))
    for i in range(4):
        x0 = 40 + i * 44; d.rectangle([x0 + 2, 72, x0 + 42, 128], fill=(255, 255, 255, 255) if i % 2 else (255, 90, 90, 255))
    rrect(d, [52, 126, 204, 226], 12, c)
def icon_gift(d, img):
    c = (235, 80, 110, 255)
    rrect(d, [44, 110, 212, 226], 18, c); rrect(d, [30, 78, 226, 122], 14, hi(c))
    d.rectangle([112, 78, 144, 226], fill=GOLD, outline=LINE, width=8)
    circle(d, 100, 66, 22, GOLD); circle(d, 156, 66, 22, GOLD)
def icon_anvil(d, img):
    c = (90, 95, 115, 255)
    poly(d, [(30, 80), (226, 80), (226, 120), (170, 140), (170, 190), (210, 220), (60, 220), (100, 190), (100, 140), (30, 120)], c)
def icon_robot(d, img):
    c = (240, 244, 250, 255)
    rrect(d, [60, 70, 196, 200], 28, c); circle(d, 100, 120, 16, (40, 60, 90, 255)); circle(d, 156, 120, 16, (40, 60, 90, 255))
    rrect(d, [92, 150, 164, 176], 8, (90, 200, 255, 255)); d.line([(128, 70), (128, 36)], fill=LINE, width=LW); circle(d, 128, 30, 14, (255, 120, 90, 255))
def icon_robot_gold(d, img): icon_robot(d, img); circle(d, 128, 30, 14, GOLD)
def icon_truck(d, img):
    rrect(d, [26, 90, 150, 186], 14, (70, 110, 190, 255)); rrect(d, [150, 120, 230, 186], 14, (255, 220, 90, 255))
    circle(d, 70, 196, 26, (60, 65, 80, 255)); circle(d, 190, 196, 26, (60, 65, 80, 255))
def icon_stall(d, img):
    poly(d, [(28, 120), (50, 50), (206, 50), (228, 120)], (255, 200, 60, 255))
    for i in range(4):
        x0 = 28 + i * 50; d.rectangle([x0 + 2, 64, x0 + 48, 118], fill=(255, 255, 255, 255) if i % 2 else (255, 200, 60, 255))
    rrect(d, [46, 118, 210, 214], 12, (160, 105, 60, 255))
def icon_drop(d, img):
    c = (80, 200, 240, 255)
    d.pieslice([44, 90, 212, 236], 0, 180, fill=c); poly(d, [(128, 20), (212, 163), (44, 163)], c)
    d.ellipse([44, 90, 212, 236], fill=c); d.ellipse([44, 90, 212, 236], outline=LINE, width=LW)
    d.line([(44, 163), (128, 20), (212, 163)], fill=LINE, width=LW); gloss(img, 128, 160, 80)
def icon_noentry(d, img):
    circle(d, 128, 128, 104, (230, 50, 50, 255)); d.line([(70, 128), (186, 128)], fill=(255, 255, 255, 255), width=28)
def icon_arrow(d, img):
    poly(d, [(30, 96), (140, 96), (140, 46), (230, 128), (140, 210), (140, 160), (30, 160)], GOLD)
def icon_hand(d, img):
    c = (255, 210, 170, 255)
    rrect(d, [70, 130, 190, 230], 30, c); rrect(d, [108, 20, 150, 150], 20, c); rrect(d, [150, 90, 188, 150], 18, c); rrect(d, [72, 100, 110, 150], 18, c)
def icon_construction(d, img):
    poly(d, [(128, 24), (236, 220), (20, 220)], (255, 180, 40, 255)); d.line([(128, 90), (128, 160)], fill=LINE, width=LW + 6); circle(d, 128, 190, 10, LINE)
def icon_field(d, img):
    rrect(d, [30, 60, 226, 200], 18, (150, 105, 60, 255))
    for y in (96, 130, 164): d.line([(50, y), (206, y)], fill=(110, 75, 40, 255), width=10)
def icon_check(d, img):
    circle(d, 128, 128, 104, (110, 210, 110, 255)); d.line([(72, 132), (112, 176), (188, 84)], fill=(255, 255, 255, 255), width=26, joint="curve")
def icon_close(d, img):
    circle(d, 128, 128, 104, (230, 80, 80, 255)); d.line([(84, 84), (172, 172)], fill=(255, 255, 255, 255), width=24); d.line([(172, 84), (84, 172)], fill=(255, 255, 255, 255), width=24)
def icon_percent(d, img):
    circle(d, 84, 84, 30, (255, 255, 255, 255)); circle(d, 172, 172, 30, (255, 255, 255, 255)); d.line([(60, 200), (196, 56)], fill=LINE, width=LW + 6)
def crop_icon(color, head):
    def f(d, img):
        for x in (88, 128, 168):
            d.line([(x, 236), (x, 110)], fill=LINE, width=LW + 8); d.line([(x, 236), (x, 110)], fill=(120, 190, 80, 255), width=8)
            d.ellipse([x - 22, 40, x + 22, 120], fill=color, outline=LINE, width=LW)
    return f
def icon_apple(d, img):
    circle(d, 128, 140, 92, (230, 60, 60, 255)); d.line([(128, 60), (140, 20)], fill=(110, 70, 40, 255), width=14); d.ellipse([140, 26, 196, 60], fill=(110, 190, 80, 255), outline=LINE, width=8); gloss(img, 128, 140, 92)
def icon_orange(d, img):
    circle(d, 128, 140, 92, (255, 140, 40, 255)); d.ellipse([120, 20, 176, 56], fill=(110, 190, 80, 255), outline=LINE, width=8); gloss(img, 128, 140, 92)
def icon_potato(d, img):
    d.ellipse([36, 80, 220, 196], fill=(200, 160, 100, 255), outline=LINE, width=LW); circle(d, 90, 120, 8, LINE); circle(d, 150, 150, 8, LINE); circle(d, 170, 110, 8, LINE)

ICONS = {
    "Coin": icon_coin, "CoinGold": icon_coin_gold, "Stone": icon_stone, "Ticket": icon_ticket, "Star": icon_star,
    "Shoe": icon_shoe, "ShoeGold": icon_shoe_gold, "Sickle": icon_sickle, "SickleGold": icon_sickle_gold,
    "Bag": icon_bag, "BagGold": icon_bag_gold, "Bolt": icon_bolt, "Lock": icon_lock, "Unlock": icon_unlock,
    "Shop": icon_shop, "Gift": icon_gift, "Anvil": icon_anvil, "Robot": icon_robot, "RobotGold": icon_robot_gold,
    "Truck": icon_truck, "Stall": icon_stall, "Drop": icon_drop, "NoEntry": icon_noentry, "Arrow": icon_arrow,
    "Hand": icon_hand, "Construction": icon_construction, "Field": icon_field, "Check": icon_check, "Close": icon_close,
    "Percent": icon_percent,
    "Wheat": crop_icon((246, 208, 96, 255), None), "Rice": crop_icon((240, 240, 215, 255), None),
    "Corn": crop_icon((250, 210, 60, 255), None), "Potato": icon_potato, "Apple": icon_apple, "Orange": icon_orange,
}

os.makedirs(OUT, exist_ok=True)
for name, fn in ICONS.items():
    img = canvas(); d = ImageDraw.Draw(img); fn(d, img)
    img.save(os.path.join(OUT, f"{name}.png"))
print(f"{len(ICONS)} icons → {os.path.abspath(OUT)}")
