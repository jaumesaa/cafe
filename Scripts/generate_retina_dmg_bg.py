import os
import subprocess
from PIL import Image, ImageDraw, ImageFont

# Logical dimensions for the Finder window
LOGICAL_W = 720
LOGICAL_H = 480

def render_background(scale=1):
    w = LOGICAL_W * scale
    h = LOGICAL_H * scale

    img = Image.new("RGBA", (w, h), (245, 241, 236, 255))  # #f5f1ec warm artisan paper
    draw = ImageDraw.Draw(img)

    # Architectural dot grid (mainlab style)
    dot_color = (222, 214, 205, 200)
    step = 25 * scale
    for x in range(step, w, step):
        for y in range(step, h, step):
            draw.ellipse([x - scale, y - scale, x + scale, y + scale], fill=dot_color)

    # Outer border (neo-brutalist)
    border_inset = 12 * scale
    border_width = 3 * scale
    draw.rectangle(
        [border_inset, border_inset, w - border_inset, h - border_inset],
        outline=(42, 37, 32, 240),
        width=border_width
    )

    # Fonts
    def font(size):
        try:
            return ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size * scale)
        except:
            return ImageFont.load_default()

    font_brand = font(18)
    font_badge = font(12)
    font_title = font(26)
    font_sub = font(14)
    font_label = font(14)
    font_footer = font(12)

    # 1. Top bar: Brand + Badge
    logo_path = "/Users/jaumesampolalcover/Documents/feina/mainlab/logo/logo_main.png"
    if os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path).convert("RGBA")
            logo_s = 36 * scale
            logo = logo.resize((logo_s, logo_s), Image.Resampling.LANCZOS)
            # Mask rounded
            mask = Image.new("L", (logo_s, logo_s), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, logo_s, logo_s], radius=8*scale, fill=255)
            logo_boxed = Image.new("RGBA", (logo_s, logo_s), (0,0,0,0))
            logo_boxed.paste(logo, (0,0), mask)
            img.paste(logo_boxed, (30 * scale, 24 * scale), logo_boxed)
        except Exception as e:
            print("Logo load:", e)

    draw.text((74 * scale, 25 * scale), "mainlab", font=font_brand, fill=(42, 37, 32, 255))
    draw.text((74 * scale, 48 * scale), "MACOS UTILITIES · CAFE v1.0", font=font(10), fill=(193, 126, 93, 255))

    # Top right pill badge
    tag = "✨ NATIVE FOR MACBOOK"
    t_box = draw.textbbox((0, 0), tag, font=font_badge)
    tw = t_box[2] - t_box[0] + 18 * scale
    th = 24 * scale
    tx = w - 30 * scale - tw
    ty = 28 * scale
    draw.rounded_rectangle([tx + 2*scale, ty + 2*scale, tx + tw + 2*scale, ty + th + 2*scale], radius=6*scale, fill=(42, 37, 32, 255))
    draw.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=6*scale, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=2*scale)
    draw.text((tx + 9*scale, ty + 5*scale), tag, font=font_badge, fill=(42, 37, 32, 255))

    # 2. Main Title & Subtitle
    title = "Instal·la Cafe al teu Mac"
    t_box = draw.textbbox((0, 0), title, font=font_title)
    tw = t_box[2] - t_box[0]
    draw.text(((w - tw) // 2, 78 * scale), title, font=font_title, fill=(42, 37, 32, 255))

    sub = "Arrossega la icona de Cafe cap a la carpeta Aplicacions"
    s_box = draw.textbbox((0, 0), sub, font=font_sub)
    sw = s_box[2] - s_box[0]
    draw.text(((w - sw) // 2, 114 * scale), sub, font=font_sub, fill=(107, 93, 84, 255))

    # 3. Two Target Landing Cards
    # Left icon center is x=190, y=240 in logical coordinates
    # Right icon center is x=530, y=240 in logical coordinates
    # Icon size is 110, so icon occupies x: [135, 245], y: [185, 295]
    card_w = 170 * scale
    card_h = 190 * scale
    card_y = 155 * scale

    # Left Card (Cafe)
    cx1 = (190 * scale) - (card_w // 2)
    # Neo-brutalist shadow
    draw.rounded_rectangle([cx1 + 5*scale, card_y + 5*scale, cx1 + card_w + 5*scale, card_y + card_h + 5*scale], radius=16*scale, fill=(42, 37, 32, 255))
    # Card surface
    draw.rounded_rectangle([cx1, card_y, cx1 + card_w, card_y + card_h], radius=16*scale, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=3*scale)
    # Subtle dashed placement zone circle
    draw.ellipse([cx1 + 35*scale, card_y + 20*scale, cx1 + card_w - 35*scale, card_y + 120*scale], outline=(193, 126, 93, 120), width=2*scale)
    # Bottom card label
    lbl1 = "1. Cafe.app"
    l1_box = draw.textbbox((0, 0), lbl1, font=font_label)
    l1_w = l1_box[2] - l1_box[0] + 16*scale
    l1_x = cx1 + (card_w - l1_w) // 2
    draw.rounded_rectangle([l1_x, card_y + card_h - 36*scale, l1_x + l1_w, card_y + card_h - 12*scale], radius=6*scale, fill=(245, 241, 236, 255), outline=(42, 37, 32, 255), width=2*scale)
    draw.text((l1_x + 8*scale, card_y + card_h - 33*scale), lbl1, font=font_label, fill=(42, 37, 32, 255))

    # Right Card (Applications)
    cx2 = (530 * scale) - (card_w // 2)
    # Neo-brutalist shadow
    draw.rounded_rectangle([cx2 + 5*scale, card_y + 5*scale, cx2 + card_w + 5*scale, card_y + card_h + 5*scale], radius=16*scale, fill=(42, 37, 32, 255))
    # Card surface
    draw.rounded_rectangle([cx2, card_y, cx2 + card_w, card_y + card_h], radius=16*scale, fill=(255, 255, 255, 255), outline=(42, 37, 32, 255), width=3*scale)
    # Subtle dashed placement zone circle
    draw.ellipse([cx2 + 35*scale, card_y + 20*scale, cx2 + card_w - 35*scale, card_y + 120*scale], outline=(122, 155, 118, 140), width=2*scale)
    # Bottom card label
    lbl2 = "2. Aplicacions"
    l2_box = draw.textbbox((0, 0), lbl2, font=font_label)
    l2_w = l2_box[2] - l2_box[0] + 16*scale
    l2_x = cx2 + (card_w - l2_w) // 2
    draw.rounded_rectangle([l2_x, card_y + card_h - 36*scale, l2_x + l2_w, card_y + card_h - 12*scale], radius=6*scale, fill=(245, 241, 236, 255), outline=(42, 37, 32, 255), width=2*scale)
    draw.text((l2_x + 8*scale, card_y + card_h - 33*scale), lbl2, font=font_label, fill=(42, 37, 32, 255))

    # 4. Central Arrow & Action badge
    arrow_y = 230 * scale
    ax_start = cx1 + card_w + 18 * scale
    ax_end = cx2 - 18 * scale
    # Main terracotta directional line
    draw.line([ax_start, arrow_y, ax_end - 16*scale, arrow_y], fill=(193, 126, 93, 255), width=5*scale)
    # Arrow head
    draw.polygon([
        (ax_end - 18*scale, arrow_y - 14*scale),
        (ax_end, arrow_y),
        (ax_end - 18*scale, arrow_y + 14*scale)
    ], fill=(193, 126, 93, 255), outline=(42, 37, 32, 255))

    # Action badge in center
    act_text = "ARROSSEGAR"
    act_b = draw.textbbox((0, 0), act_text, font=font_badge)
    act_w = act_b[2] - act_b[0] + 20*scale
    act_h = 24 * scale
    act_x = (w - act_w) // 2
    act_y = arrow_y - 40 * scale
    draw.rounded_rectangle([act_x + 2*scale, act_y + 2*scale, act_x + act_w + 2*scale, act_y + act_h + 2*scale], radius=10*scale, fill=(42, 37, 32, 255))
    draw.rounded_rectangle([act_x, act_y, act_x + act_w, act_y + act_h], radius=10*scale, fill=(193, 126, 93, 255), outline=(42, 37, 32, 255), width=2*scale)
    draw.text((act_x + 10*scale, act_y + 5*scale), act_text, font=font_badge, fill=(255, 255, 255, 255))

    # 5. Bottom microcopy & Footer
    bottom_desc = "Manté la pantalla i el disc desperts durant compilacions i descàrregues grans."
    bd_box = draw.textbbox((0, 0), bottom_desc, font=font_sub)
    bd_w = bd_box[2] - bd_box[0]
    draw.text(((w - bd_w) // 2, 370 * scale), bottom_desc, font=font_sub, fill=(107, 93, 84, 255))

    footer = "Creat amb orgull per mainlab.es · Codi Obert (MIT) · Universal M1–M4 & Intel"
    f_box = draw.textbbox((0, 0), footer, font=font_footer)
    fw = f_box[2] - f_box[0]
    draw.text(((w - fw) // 2, 440 * scale), footer, font=font_footer, fill=(140, 125, 115, 255))

    return img

def main():
    img_1x = render_background(scale=1)
    img_1x.save("Scripts/dmg_bg_1x.png", "PNG", dpi=(72, 72))
    print("Saved Scripts/dmg_bg_1x.png (720x480)")

    img_2x = render_background(scale=2)
    img_2x.save("Scripts/dmg_bg_2x.png", "PNG", dpi=(144, 144))
    print("Saved Scripts/dmg_bg_2x.png (1440x960)")

    # Create Retina multi-resolution TIFF using Apple's tiffutil
    cmd = ["tiffutil", "-cathidpicheck", "Scripts/dmg_bg_1x.png", "Scripts/dmg_bg_2x.png", "-out", "Scripts/dmg_bg.tiff"]
    subprocess.run(cmd, check=True)
    print("Created Scripts/dmg_bg.tiff with Retina support!")

if __name__ == "__main__":
    main()
