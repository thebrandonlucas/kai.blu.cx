import ast
g = ast.literal_eval(open("kai-600.json").read())
xmin, ymin, xmax, ymax = g["bounds"]
def place(cx, cy, h):
    s = h / (ymax - ymin)
    return f'translate({cx - (xmin + xmax) / 2 * s:.2f} {cy + (ymin + ymax) / 2 * s:.2f}) scale({s:.4f} {-s:.4f})'
# Favicon: gold ϗ on a dark rounded square.
open("favicon.svg", "w").write(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
    '<rect width="64" height="64" rx="12" fill="#141210"/>'
    f'<path fill="#e8c872" transform="{place(32, 32, 50)}" d="{g["d"]}"/></svg>')
# The bar's mark: the glyph alone, tight.
W, H = xmax - xmin, ymax - ymin
open("kai-mark.svg", "w").write(
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}">'
    f'<path fill="#e8c872" transform="translate({-xmin:.0f} {ymax:.0f}) scale(1 -1)" d="{g["d"]}"/></svg>')
print("ok")
