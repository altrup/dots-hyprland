def midnight_color(color: str) -> str:
    rgb = [int(color[index:index + 2], 16) for index in (1, 3, 5)]
    lightness = sum(rgb) / 3
    # Match https://github.com/InioX/matugen/blob/v4.1.0/src/color/color.rs with --lightness-dark -0.1.
    scale = max(0, 1.1 - 25.5 / lightness) if lightness else 0
    return '#{:02x}{:02x}{:02x}'.format(*(round(channel * scale) for channel in rgb))
