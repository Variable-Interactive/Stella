class_name BandPlotter
extends RefCounted

const SIZE_CONTROL := """
set terminal pdfcairo enhanced \\
color solid \\
font '%s,%s' \\
size %s
set size %s \n
"""
const ENABLE_PNG := "set term png \n"
const OUTPUT := "set output '%s' \n"
const ENCODER := "set encoding iso_8859_1 \n"
const Y_RANGE := "set yrange[%s:%s] \n"
const GRAPH_OUTLINE := "set border %s linewidth %s \n"
const TITLE := "set title '%s' \n"
const AXIS_LABELS := """
set xlabel '%s'
set ylabel '%s' \n
"""
const VERTICAL_ARROW := """
set arrow from %s,graph(0,0) to %s,graph(%s) nohead ls 1 lt 2 lw 2 lc rgb 'magenta' \n
"""
const MARKINGS := "set xtics (%s) \n"  # comma separated
const XTICK := "\"{/Symbol %s}\" %s"
const ZERO_LINE := "set zeroaxis ls 1.5 dt 4 lw 2.5 lc rgb 'magenta' \n"
const PLOT := """
plot \\
%s
"""
const PLOT_DATA := "'%s' using %s:%s with %s linewidth %s linecolor rgbcolor '#%s' title '%s' \\"


static func generate_gnu(data: Dictionary) -> String:
	var data_file_path: String = data.get("data_file_path", "")
	var plot_lines: Array[Dictionary] = data.get("plot_lines", [])
	var title: String = data.get("title", "")
	var x_label: String = data.get("x_label", "")
	var y_label: String = data.get("y_label", "")
	var font: String = data.get("font", "Times-bold")
	var font_size: int = data.get("font_size", 12)
	var size_value: Vector2 = data.get("size_value", Vector2(5.0, 6.0))
	var scale_value: Vector2 = data.get("scale_value", Vector2.ONE)
	var y_range: Vector2 = data.get("y_range", Vector2(-2, 2))
	var output_plot_name: String = data.get("output_plot_name", "OUTPUT.pdf")
	var border: float = data.get("border", 15)
	var outline: float = data.get("outline", 2.5)

	var gnu_code := ""
	var v_lines := {
		0.0000: "G",
		0.1000: "M",
		0.2000: "B",
	}

	gnu_code += SIZE_CONTROL % [
		font, str(font_size),
		str(size_value.x, "in, ", size_value.y, "in"),
		str(scale_value.x, ", ", scale_value.y)
	]
	if output_plot_name.get_extension().to_lower() == "png":
		gnu_code += ENABLE_PNG
	gnu_code += OUTPUT % output_plot_name
	gnu_code += ENCODER
	gnu_code += Y_RANGE % [str(y_range.x), str(y_range.y)]
	gnu_code += GRAPH_OUTLINE % [str(border), str(outline)]
	gnu_code += TITLE % title
	gnu_code += AXIS_LABELS % [x_label, y_label]

	var markings := ""
	for line_point in v_lines.keys():
		gnu_code += VERTICAL_ARROW % [
			str(line_point),
			str(line_point),
			str(scale_value.x,
			", ",
			scale_value.y)
		]
		markings += XTICK % [v_lines[line_point], str(line_point)] + ","
	if not markings.is_empty():
		markings = markings.substr(0, markings.length() - 1)  # Remove trailing comma
		gnu_code += MARKINGS % markings

	gnu_code += ZERO_LINE
	for plot: Dictionary in plot_lines:
		var plot_data := PLOT_DATA % [
			data_file_path,
			plot["x_column"],
			plot["y_column"],
			plot["line_type"],
			plot["width"],
			plot["color"].to_html(false),
			plot["title"],
		]
		gnu_code += PLOT % plot_data
	return gnu_code
