class_name BandPlotter
extends RefCounted

const HEADER := """
# =============== Variables ===============

background_color = '#%s'
border_color = '#%s'
font_color = '#%s'
font_main = '%s'
font_size_main = %s
pdf_size_x = %s
pdf_size_y = %s
output_path = '%s'
x_range_start = %s
x_range_end = %s
y_range_start = %s
y_range_end = %s
border_mode = %s
border_width = %s

# =============== Functions ===============
plot_setting(plot_title, x_label, y_label, scale_x, scale_y) = sprintf("\\
plot_title = '%%s'; \\
x_label = '%%s'; \\
y_label = '%%s'; \\
scale_x = %%f; \\
scale_y = %%f; \\
\\
unset title; \\
unset xlabel; \\
unset ylabel; \\
set tics textcolor rgb font_color; \\
if (plot_title ne '') {set title plot_title textcolor rgb font_color}; \\
if (x_label ne '') {set xlabel x_label textcolor rgb font_color}; \\
if (y_label ne '') {set ylabel y_label textcolor rgb font_color}; \\
set size scale_x, scale_y; \\
set border border_mode linewidth border_width linecolor rgb border_color;" \\
, plot_title, x_label, y_label, scale_x, scale_y)


# ================ Script =================

set terminal pdfcairo enhanced \\
background rgb background_color \\
color solid \\
font sprintf("%%s,%%d", font_main, font_size_main) \\
size pdf_size_x in, pdf_size_y in
set output output_path \n
"""
const ENCODER := "set encoding iso_8859_1 \n"
const ENABLE_PNG := "set term png \n"
const X_RANGE := "if (x_range_start != x_range_end) set xrange[x_range_start : x_range_end] \n"
const Y_RANGE := "if (y_range_start != y_range_end) set yrange[y_range_start : y_range_end] \n"

const PLOT_SETTING := """
evaluate plot_setting('%s', '%s', '%s', %s, %s)
"""

const VERTICAL_ARROW := """
set arrow from %s,graph(0,0) to %s,graph(%s) nohead ls 1 lt 2 lw 2 lc rgb 'magenta' \n
"""
const MARKINGS := "set xtics (%s)\n"  # comma separated
const XTICK := "\"%s\" %s"
const LEGEND := "set key %s %s %s %s textcolor rgb font_color\n"
const LEGEND_BOX := "box lc rgb border_color lw %s opaque spacing %s"
const ZERO_AXIS := "set zeroaxis ls 1.5 dt 4 lw 2.5 lc rgb 'magenta' \n"
const PLOT := """
plot \\
%s
"""
const PLOT_DATA := "'%s' using %s:%s with %s linewidth %s linecolor rgbcolor '#%s' title '%s' \\\n"


static func generate_gnu(data: Dictionary) -> String:
	var data_file_path: String = data.get("data_file_path", "")
	var plot_lines: Array[Dictionary] = data.get("plot_lines", [])
	var title: String = data.get("title", "")
	if title.begins_with("_"):
		title = ""
	var x_label: String = data.get("x_label", "")
	var y_label: String = data.get("y_label", "")
	var font: String = data.get("font", "Times-bold")
	var background_color: Color = data.get("background_color", Color.WHITE)
	var border_color: Color = data.get("border_color", Color.BLACK)
	var font_color: Color = data.get("font_color", Color.BLACK)
	var font_size: int = data.get("font_size", 12)
	var size_value: Vector2 = data.get("size_value", Vector2(5.0, 6.0))
	var scale_value: Vector2 = data.get("scale_value", Vector2.ONE)
	var x_range: Vector2 = data.get("x_range", Vector2(0, 0))
	var y_range: Vector2 = data.get("y_range", Vector2(-2, 2))
	var output_plot_name: String = data.get("output_plot_name", "OUTPUT.pdf")
	var border: int = data.get("border", 15)
	var outline: float = data.get("outline", 2.5)
	var k_lines: Dictionary = data.get("k_lines", {})
	var legend_setting: Dictionary = data.get("legend_config", {})

	var gnu_code := HEADER % [
		background_color.to_html(false),
		border_color.to_html(false),
		font_color.to_html(false),
		font,
		str(font_size),
		str(size_value.x),
		str(size_value.y),
		output_plot_name,
		str(x_range.x),
		str(x_range.y),
		str(y_range.x),
		str(y_range.y),
		str(border),
		str(outline),
	]
	if output_plot_name.get_extension().to_lower() == "png":
		gnu_code += ENABLE_PNG
	gnu_code += ENCODER
	gnu_code += X_RANGE
	gnu_code += Y_RANGE
	gnu_code += PLOT_SETTING % [
		title, x_label, y_label, str(scale_value.x), str(scale_value.y)
	]

	var markings := ""
	for line_point in k_lines.keys():
		gnu_code += VERTICAL_ARROW % [
			str(line_point),
			str(line_point),
			str(scale_value.x,
			", ",
			scale_value.y)
		]
		markings += XTICK % [k_lines[line_point], str(line_point)] + ","
	if not markings.is_empty():
		markings = markings.substr(0, markings.length() - 1)  # Remove trailing comma
		gnu_code += MARKINGS % markings

	# Set Legend alignment
	var align_v = legend_setting.get("align_v", "top")
	var align_h = legend_setting.get("align_h", "right")
	var should_reverse_legend: bool = legend_setting.get("reverse_legend", false)
	var reverse_legend := "reverse" if should_reverse_legend else ""
	var use_box: bool = legend_setting.get("use_box", false)
	var box_options := ""
	if use_box:
		box_options = LEGEND_BOX % [
			legend_setting.get("outline", 1.2), legend_setting.get("spacing", 1.2)
		]
	gnu_code += LEGEND % [align_v, align_h, reverse_legend, box_options]

	gnu_code += ZERO_AXIS
	if not plot_lines.is_empty():
		var plots = ""
		var set_file := true
		for plot: Dictionary in plot_lines:
			var plot_file := data_file_path if set_file else ""
			var overwrite_file: String = plot["override_file"].strip_edges()
			if overwrite_file:
				plot_file = data_file_path.get_base_dir().path_join(overwrite_file)
			var plot_line_name: String = "" if plot["title"].begins_with("_") else plot["title"]
			var plot_data := PLOT_DATA % [
				plot_file,
				plot["x_column"],
				plot["y_column"],
				plot["line_type"],
				plot["width"],
				plot["color"].to_html(false),
				plot_line_name,
			]
			plots += (", " if !set_file else "") + plot_data
			set_file = false
		gnu_code += PLOT % plots
	return gnu_code
