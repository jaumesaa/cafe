import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 840  # 660x420 @ 2x

def make_rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return mask

def generate_pro_mainlab_background():
    img = Image.new("RGBA", (W, H), (245, 241, 236, 255))  # #f5f1ec warm artisan paper
    draw = ImageDraw.Draw(img)

    # Architectural dot grid (very subtle, iconic mainlab style)
    dot_color = (215, 206, 196, 180)
    for x in range(30, W, 30):
        for y in range(30, H, 30):
            draw.ellipse([x-1, y-1, x+1, y+1], fill=dot_color)

    # Outer neo-brutalist frame
    draw.rectangle([20, 20, W-20, H-20], outline=(42, 37, 32, 230), width=4)

    # Fonts
    try:
        font_brand = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 32)
        font_badge = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 20)
        font_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 44)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 24)
        font_label = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 26)
        font_arrow = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 52)
        font_footer = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 22)
    except:
        font_brand = font_badge = font_title = font_sub = font_label = font_arrow = font_footer = ImageFont.load_default()

    # Logo integration
    logo_path = "/Users/jaumesampolalcover/Documents/feina/mainlab/logo/logo_main.png"
    if os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path).convert("RGBA")
            logo = logo.resize((64, 64), Image.Resampling.LANCZOS)
            # Add rounded mask to logo
            logo_mask = make_rounded_mask((64, 64), 14)
            logo_boxed = Image.new("RGBA", (64, 64), (0,0,0,0))
            logo_boxed.paste(logo, (0,0), logo_mask)
            
            # Position at top-left
            img.paste(logo_boxed, (55, 45), logo_boxed)
        except Exception as e:
            print("Logo load error:", e)

    # Brand Title top-left next to logo
    draw.text((130, 48), "mainlab", font=font_brand, fill=(42, 37, 32, 255))
    draw.text((130, 84), "MACOS UTILITIES · CAFE v1.0", font=font_badge, fill=(193, 126, 93, 255))

    # Right badge at top
    tag = "✨ NATIVE FOR MACBOOK"
    t_box = draw.textbbox((0, 0), tag, font=font_badge)
    tw = t_box[2] - t_box[0] + 28
    tx = W - 55 - tw
    ty = 52
    draw.rounded_rectangle([tx+3, ty+3, tx+tw+3, ty+38], radius=8, fill=(42, 37, 32, 255))
    draw.rounded_rectangle([tx, ty, tx+tw, ty+35], radius=8, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=2)
    draw.text((tx + 14, ty + 8), tag, font=font_badge, fill=(42, 37, 32, 255))

    # Center instruction
    inst = "Arrossega Cafe a Aplicacions per instal·lar"
    in_box = draw.textbbox((0, 0), inst, font=font_title)
    iw = in_box[2] - in_box[0]
    draw.text(((W - iw) // 2, 135), inst, font=font_title, fill=(42, 37, 32, 255))

    # Two Neo-Brutalist Target Cards
    # Left: Cafe.app center at x=360, y=410
    # Right: Applications center at x=960, y=410
    card_w, card_h = 240, 270
    card_y = 280

    # Left Card
    cx1 = 240
    # Neo-brutalist shadow
    draw.rounded_rectangle([cx1+8, card_y+8, cx1+card_w+8, card_y+card_h+8], radius=20, fill=(42, 37, 32, 255))
    # Card body
    draw.rounded_rectangle([cx1, card_y, cx1+card_w, card_y+card_h], radius=20, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=4)
    # Target zone dotted circle for app icon
    draw.ellipse([cx1 + 45, card_y + 35, cx1 + card_w - 45, card_y + 185], outline=(193, 126, 93, 140), width=3)
    # Card label pill
    lbl1 = "1. Cafe.app"
    l1_box = draw.textbbox((0, 0), lbl1, font=font_label)
    l1_w = l1_box[2] - l1_box[0] + 24
    l1_x = cx1 + (card_w - l1_w) // 2
    draw.rounded_rectangle([l1_x, card_y + card_h - 52, l1_x + l1_w, card_y + card_h - 18], radius=8, fill=(245, 241, 236, 255), outline=(42, 37, 32, 255), width=2)
    draw.text((l1_x + 12, card_y + card_h - 48), lbl1, font=font_label, fill=(42, 37, 32, 255))

    # Right Card
    cx2 = 840
    # Neo-brutalist shadow
    draw.rounded_rectangle([cx2+8, card_y+8, cx2+card_w+8, card_y+card_h+8], radius=20, fill=(42, 37, 32, 255))
    # Card body
    draw.rounded_rectangle([cx2, card_y, cx2+card_w, card_y+card_h], radius=20, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=4)
    # Target zone dotted circle for applications icon
    draw.ellipse([cx2 + 45, card_y + 35, cx2 + card_w - 45, card_y + 185], outline=(122, 155, 118, 160), width=3)
    # Card label pill
    lbl2 = "2. Aplicacions"
    l2_box = draw.textbbox((0, 0), lbl2, font=font_label)
    l2_w = l2_box[2] - l2_box[0] + 24
    l2_x = cx2 + (card_w - l2_w) // 2
    draw.rounded_rectangle([l2_x, card_y + card_h - 52, l2_x + l2_w, card_y + card_h - 18], radius=8, fill=(245, 241, 236, 255), outline=(42, 37, 32, 255), width=2)
    draw.text((l2_x + 12, card_y + card_h - 48), lbl2, font=font_label, fill=(42, 37, 32, 255))

    # Center Flow Arrow & Pill Badge
    arrow_center_y = card_y + card_h // 2 - 20
    # Terracotta line with dots
    start_x = cx1 + card_w + 30
    end_x = cx2 - 30
    draw.line([start_x, arrow_center_y, end_x - 30, arrow_center_y], fill=(193, 126, 93, 255), width=6)
    # Arrow head
    draw.polygon([(end_x - 32, arrow_center_y - 22), (end_x, arrow_center_y), (end_x - 32, arrow_center_y + 22)], fill=(193, 126, 93, 255), outline=(42, 37, 32, 255))

    # Floating action badge over arrow
    act = "ARROSSEGAR"
    act_box = draw.textbbox((0, 0), act, font=font_badge)
    act_w = act_box[2] - act_box[0] + 32
    act_x = (W - act_w) // 2
    act_y = arrow_center_y - 65
    draw.rounded_rectangle([act_x+4, act_y+4, act_x+act_w+4, act_y+36], radius=16, fill=(42, 37, 32, 255))
    draw.rounded_rectangle([act_x, act_y, act_x+act_w, act_y+32], radius=16, fill=(193, 126, 93, 255), outline=(42, 37, 32, 255), width=3)
    draw.text((act_x + 16, act_y + 7), act, font=font_badge, fill=(255, 255, 255, 255))

    # Sub-bullet points at bottom of cards
    sub_desc = "Manté la pantalla i el disc desperts durant compilacions, renders i descàrregues grans."
    sd_box = draw.textbbox((0, 0), sub_desc, font=font_sub)
    sd_w = sd_box[2] - sd_box[0]
    draw.text(((W - sd_w) // 2, card_y + card_h + 35), sub_desc, font=font_sub, fill=(107, 93, 84, 255))

    # Footer
    footer = "Creat amb orgull per mainlab.es · Codi Obert a GitHub (MIT) · Universal M1–M4 & Intel"
    f_box = draw.textbbox((0, 0), footer, font=font_footer)
    fw = f_box[2] - f_box[0]
    draw.text(((W - fw) // 2, H - 65), footer, font=font_footer, fill=(140, 125, 115, 255))

    img.save("Scripts/dmg_background_pro.png", "PNG")
    print("Created Scripts/dmg_background_pro.png successfully!")

if __name__ == "__main__":
    generate_pro_mainlab_background()
