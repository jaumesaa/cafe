import os
from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 840  # 660x420 @2x

def get_fonts():
    try:
        font_brand = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 28)
        font_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 46)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 24)
        font_pill = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 20)
        font_box = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 24)
        font_arrow = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 60)
        font_footer = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 22)
    except:
        font_brand = font_title = font_sub = font_pill = font_box = font_arrow = font_footer = ImageFont.load_default()
    return font_brand, font_title, font_sub, font_pill, font_box, font_arrow, font_footer

def create_light_design():
    font_brand, font_title, font_sub, font_pill, font_box, font_arrow, font_footer = get_fonts()
    img = Image.new("RGBA", (W, H), (245, 241, 236, 255)) # #f5f1ec
    draw = ImageDraw.Draw(img)

    # Architectural dot grid
    dot_color = (220, 212, 203, 180)
    for x in range(40, W, 40):
        for y in range(40, H, 40):
            draw.ellipse([x-1, y-1, x+1, y+1], fill=dot_color)

    # Outer neo-brutalist border
    draw.rectangle([20, 20, W-20, H-20], outline=(42, 37, 32, 220), width=4)

    # Top Brand Header
    # Pill badge: "MAINLAB · MACOS UTILITIES"
    pill_text = "MAINLAB · MACOS"
    pill_bbox = draw.textbbox((0, 0), pill_text, font=font_pill)
    pw = pill_bbox[2] - pill_bbox[0] + 30
    ph = 36
    px = (W - pw) // 2
    py = 50
    # Shadow
    draw.rounded_rectangle([px+4, py+4, px+pw+4, py+ph+4], radius=18, fill=(42, 37, 32, 255))
    # Box
    draw.rounded_rectangle([px, py, px+pw, py+ph], radius=18, fill=(193, 126, 93, 255), outline=(42, 37, 32, 255), width=3)
    draw.text((px + 15, py + 7), pill_text, font=font_pill, fill=(255, 255, 255, 255))

    # Main Title
    title = "Arrossega Cafe a la carpeta Aplicacions"
    t_bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = t_bbox[2] - t_bbox[0]
    draw.text(((W - tw) // 2, 105), title, font=font_title, fill=(42, 37, 32, 255))

    # Subtitle
    sub = "Instal·lació nativa per a MacBook · Sense processos ocults en segon pla"
    s_bbox = draw.textbbox((0, 0), sub, font=font_sub)
    sw = s_bbox[2] - s_bbox[0]
    draw.text(((W - sw) // 2, 165), sub, font=font_sub, fill=(107, 93, 84, 255))

    # Left Target Card (Cafe.app at x=180, y=190 -> 2x: 360, 380)
    # Target Box width=220, height=220 -> cx=360, cy=390
    bx1, by1 = 250, 270
    bw, bh = 220, 240
    # Shadow
    draw.rounded_rectangle([bx1+6, by1+6, bx1+bw+6, by1+bh+6], radius=24, fill=(42, 37, 32, 180))
    # Card
    draw.rounded_rectangle([bx1, by1, bx1+bw, by1+bh], radius=24, fill=(255, 255, 255, 240), outline=(42, 37, 32, 255), width=3)
    # Label at bottom of card
    lbl1 = "1. Cafe.app"
    l1_bbox = draw.textbbox((0, 0), lbl1, font=font_box)
    draw.text((bx1 + (bw - (l1_bbox[2]-l1_bbox[0]))//2, by1 + bh - 40), lbl1, font=font_box, fill=(42, 37, 32, 255))

    # Right Target Card (Applications at x=480, y=190 -> 2x: 960, 380)
    bx2 = 850
    # Shadow
    draw.rounded_rectangle([bx2+6, by1+6, bx2+bw+6, by1+bh+6], radius=24, fill=(42, 37, 32, 180))
    # Card
    draw.rounded_rectangle([bx2, by1, bx2+bw, by1+bh], radius=24, fill=(255, 255, 255, 240), outline=(42, 37, 32, 255), width=3)
    # Label at bottom of card
    lbl2 = "2. Aplicacions"
    l2_bbox = draw.textbbox((0, 0), lbl2, font=font_box)
    draw.text((bx2 + (bw - (l2_bbox[2]-l2_bbox[0]))//2, by1 + bh - 40), lbl2, font=font_box, fill=(42, 37, 32, 255))

    # Center stylized arrow
    # From x=500 to x=820, y=390
    arrow_y = by1 + bh // 2 - 20
    # Dotted line
    for dot_x in range(bx1 + bw + 30, bx2 - 40, 24):
        draw.ellipse([dot_x - 4, arrow_y - 4, dot_x + 4, arrow_y + 4], fill=(193, 126, 93, 230))
    
    # Arrow head
    ah_x = bx2 - 30
    draw.polygon([(ah_x - 30, arrow_y - 20), (ah_x, arrow_y), (ah_x - 30, arrow_y + 20)], fill=(193, 126, 93, 255), outline=(42, 37, 32, 255))

    # Action badge in center: "ARROSSEGA"
    action_text = "INSTAL·LAR"
    ab_bbox = draw.textbbox((0, 0), action_text, font=font_pill)
    ab_w = ab_bbox[2] - ab_bbox[0] + 24
    ab_x = (W - ab_w) // 2
    ab_y = arrow_y - 50
    draw.rounded_rectangle([ab_x+3, ab_y+3, ab_x+ab_w+3, ab_y+32], radius=14, fill=(42, 37, 32, 255))
    draw.rounded_rectangle([ab_x, ab_y, ab_x+ab_w, ab_y+29], radius=14, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=2)
    draw.text((ab_x + 12, ab_y + 5), action_text, font=font_pill, fill=(193, 126, 93, 255))

    # Footer banner
    footer = "✨ Dissenyat amb orgull per mainlab.es · Codi Obert (MIT) · Universal M1-M4 & Intel"
    f_bbox = draw.textbbox((0, 0), footer, font=font_footer)
    fw = f_bbox[2] - f_bbox[0]
    draw.text(((W - fw) // 2, H - 75), footer, font=font_footer, fill=(107, 93, 84, 255))

    img.save("Scripts/dmg_background_light.png", "PNG")
    print("Created Scripts/dmg_background_light.png")

def create_dark_design():
    font_brand, font_title, font_sub, font_pill, font_box, font_arrow, font_footer = get_fonts()
    img = Image.new("RGBA", (W, H), (26, 23, 20, 255)) # #1a1714 deep warm obsidian
    draw = ImageDraw.Draw(img)

    # Ambient radial glow in center
    cx, cy = W // 2, H // 2
    for r in range(450, 0, -5):
        alpha = int(28 * (1 - r / 450))
        draw.ellipse([cx - r*1.3, cy - r*0.8, cx + r*1.3, cy + r*0.8], fill=(212, 162, 131, alpha))

    # Subtle grid
    dot_color = (60, 52, 45, 120)
    for x in range(40, W, 40):
        for y in range(40, H, 40):
            draw.ellipse([x-1, y-1, x+1, y+1], fill=dot_color)

    # Outer border
    draw.rectangle([20, 20, W-20, H-20], outline=(212, 162, 131, 80), width=3)

    # Top Brand Header
    pill_text = "MAINLAB · MACOS"
    pill_bbox = draw.textbbox((0, 0), pill_text, font=font_pill)
    pw = pill_bbox[2] - pill_bbox[0] + 30
    ph = 36
    px = (W - pw) // 2
    py = 50
    draw.rounded_rectangle([px, py, px+pw, py+ph], radius=18, fill=(45, 38, 32, 230), outline=(212, 162, 131, 200), width=2)
    draw.text((px + 15, py + 7), pill_text, font=font_pill, fill=(212, 162, 131, 255))

    # Main Title
    title = "Arrossega Cafe a la carpeta Aplicacions"
    t_bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = t_bbox[2] - t_bbox[0]
    draw.text(((W - tw) // 2, 105), title, font=font_title, fill=(245, 240, 235, 255))

    # Subtitle
    sub = "Instal·lació nativa per a MacBook · Sense processos ocults en segon pla"
    s_bbox = draw.textbbox((0, 0), sub, font=font_sub)
    sw = s_bbox[2] - s_bbox[0]
    draw.text(((W - sw) // 2, 165), sub, font=font_sub, fill=(184, 169, 156, 255))

    # Target Cards
    bx1, by1 = 250, 270
    bw, bh = 220, 240
    # Left Card
    draw.rounded_rectangle([bx1, by1, bx1+bw, by1+bh], radius=24, fill=(35, 30, 26, 220), outline=(212, 162, 131, 140), width=2)
    lbl1 = "1. Cafe.app"
    l1_bbox = draw.textbbox((0, 0), lbl1, font=font_box)
    draw.text((bx1 + (bw - (l1_bbox[2]-l1_bbox[0]))//2, by1 + bh - 40), lbl1, font=font_box, fill=(245, 240, 235, 240))

    # Right Card
    bx2 = 850
    draw.rounded_rectangle([bx2, by1, bx2+bw, by1+bh], radius=24, fill=(35, 30, 26, 220), outline=(212, 162, 131, 140), width=2)
    lbl2 = "2. Aplicacions"
    l2_bbox = draw.textbbox((0, 0), lbl2, font=font_box)
    draw.text((bx2 + (bw - (l2_bbox[2]-l2_bbox[0]))//2, by1 + bh - 40), lbl2, font=font_box, fill=(245, 240, 235, 240))

    # Center arrow
    arrow_y = by1 + bh // 2 - 20
    for dot_x in range(bx1 + bw + 30, bx2 - 40, 24):
        draw.ellipse([dot_x - 4, arrow_y - 4, dot_x + 4, arrow_y + 4], fill=(212, 162, 131, 180))
    
    ah_x = bx2 - 30
    draw.polygon([(ah_x - 30, arrow_y - 20), (ah_x, arrow_y), (ah_x - 30, arrow_y + 20)], fill=(212, 162, 131, 240))

    # Center Badge
    action_text = "INSTAL·LAR"
    ab_bbox = draw.textbbox((0, 0), action_text, font=font_pill)
    ab_w = ab_bbox[2] - ab_bbox[0] + 24
    ab_x = (W - ab_w) // 2
    ab_y = arrow_y - 50
    draw.rounded_rectangle([ab_x, ab_y, ab_x+ab_w, ab_y+29], radius=14, fill=(45, 38, 32, 255), outline=(212, 162, 131, 200), width=2)
    draw.text((ab_x + 12, ab_y + 5), action_text, font=font_pill, fill=(212, 162, 131, 255))

    # Footer banner
    footer = "✨ Dissenyat amb orgull per mainlab.es · Codi Obert (MIT) · Universal M1-M4 & Intel"
    f_bbox = draw.textbbox((0, 0), footer, font=font_footer)
    fw = f_bbox[2] - f_bbox[0]
    draw.text(((W - fw) // 2, H - 75), footer, font=font_footer, fill=(184, 169, 156, 220))

    img.save("Scripts/dmg_background_dark.png", "PNG")
    print("Created Scripts/dmg_background_dark.png")

if __name__ == "__main__":
    create_light_design()
    create_dark_design()
