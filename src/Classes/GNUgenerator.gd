class_name GNUgenerator
extends RefCounted

const HEADER := """
# =============== Variables ===============

background_color = '#{background_color}';
border_color = '#{border_color}';
font_color = '#{font_color}';
font_main = '{main_font}';
font_size_main = {fallback_font_size};
pdf_size_x = {pdf_size_x};
pdf_size_y = {pdf_size_y};
output_path = '{output_path}';
x_range_start = {x_range_start};
x_range_end = {x_range_end};
y_range_start = {y_range_start};
y_range_end = {y_range_end};
border_mode = {border_mode};
border_width = {border_width};

# ================ Script =================

{terminal} \\
background rgb background_color \\
color solid \\
font font_main . ',' . font_size_main \\
size pdf_size_x in, pdf_size_y in;
"""
const OUTPUT_FILE := "set output output_path; \n"
const ENCODER := "set encoding iso_8859_1; \n"
const ENABLE_PNG := "set terminal pngcairo enhanced";
const ENABLE_PDF := "set terminal pdfcairo enhanced";
const X_RANGE := "set xrange[x_range_start:x_range_end];\n"
const Y_RANGE := "set yrange[y_range_start:y_range_end];\n"

const PLOT_SETTING := """
plot_title = '{graph_title}'; \\
x_label = '{x_label}'; \\
y_label = '{y_label}'; \\
scale_x = {scale_x}; \\
scale_y = {scale_y}; \\
unset title; \\
unset xlabel; \\
unset ylabel; \\
set tics textcolor rgb font_color; \\
set title (plot_title ne '' ? plot_title : '') textcolor rgb font_color;
set xlabel (x_label ne '' ? x_label : '') textcolor rgb font_color;
set ylabel (y_label ne '' ? y_label : '') textcolor rgb font_color;
set size scale_x, scale_y; \\
set border border_mode linewidth border_width linecolor rgb border_color; \\
"""

const VERTICAL_ARROW := """
set arrow from {distance},graph(0, 0) to {distance},graph({scale_x}, {scale_y}) nohead ls 1 lt 2 lw 2 lc rgb 'magenta'; \n
"""
const MARKINGS := "set xtics ({x_ticks})\n"  # comma separated
const XTICK := "\"{k_label}\" {distance}"
const LEGEND := "set key {align_v} {align_h} {reverse_legend} {box_oprions} textcolor rgb font_color;\n"
const LEGEND_BOX := "box lc rgb border_color lw {box_border_width} opaque spacing {box_border_spacing}"
const ZERO_AXIS := "set zeroaxis ls 1.5 dt 4 lw 2.5 lc rgb 'magenta'; \n"
const PLOT := """
plot \\
{plot_lines}
"""
const PLOT_DATA := "'{data_path}' using {x_column}:{y_column} with {line_type} linewidth {line_width} linecolor rgbcolor '#{color}' title '{plot_name}' \\\n"


static func generate_gnu(
	data: Dictionary, export_path: String, export_format:= OpenSave.Format.PNG
) -> Dictionary:
	var path_dependencies := PackedStringArray()
	# General Properties
	var graph_title: String = data.get("graph_title")
	var x_label: String = data.get("x_label")
	var y_label: String = data.get("y_label")
	var font_name: String = data.get("font_name")
	var font_bold: bool = data.get("font_bold", true)
	var fallback_font_size: int = data.get("fallback_font_size")
	var font_color: Color = data.get("font_color")
	var border_mode: int = data.get("border_mode")
	var border_width: float = data.get("border_width")
	var border_color: Color = data.get("border_color")
	var background_color: Color = data.get("background_color")
	var graph_size: Vector2 = data.get("graph_size")
	var graph_scale: Vector2 = data.get("graph_scale")

	var show_zero_axis: bool = data.get("show_zero_axis", false)
	var hide_x_axis: bool = data.get("hide_x_axis", false)

	var full_range: bool = data.get("full_range")
	var x_range_min: float = data.get("x_range_min")
	var x_range_max: float = data.get("x_range_max")
	var y_range_min: float = data.get("y_range_min")
	var y_range_max: float = data.get("y_range_max")
	var data_files: Array[Dictionary] = data.get("data_files")
	var kline_data: Dictionary = data.get("k_lines")

	var legend_vertical: Project.LegendAlign = data.get("legend_vertical")
	var legend_horizontal: Project.LegendAlign = data.get("legend_horizontal")
	var should_reverse_legend: bool = data.get("reverse_legend")
	var use_box: bool = data.get("use_box")
	var legend_box_outline: float = data.get("legend_box_outline")
	var legend_box_spacing: float = data.get("legend_box_spacing")

	# Directory creation
	export_path = export_path.strip_edges()
	var export_file := export_path.get_file().get_slice(".", 0)
	if not export_path.is_empty():
		export_path = export_path.get_base_dir().path_join(export_file)
		match export_format:
			OpenSave.Format.PNG:
				export_path += ".png"
			OpenSave.Format.PDF:
				export_path += ".pdf"
	if not DirAccess.dir_exists_absolute(export_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(export_path.get_base_dir())
	if font_bold:
		font_name += "-Bold"
	path_dependencies.append(export_path)
	var gnu_code := HEADER.format(
		{
			"background_color": background_color.to_html(false),
			"border_color": border_color.to_html(false),
			"font_color": font_color.to_html(false),
			"main_font": font_name,
			"fallback_font_size": str(fallback_font_size),
			"pdf_size_x": str(graph_size.x),
			"pdf_size_y": str(graph_size.y),
			"output_path": "{%s}" % str(path_dependencies.size() - 1),
			"x_range_start": str(x_range_min),
			"x_range_end": str(x_range_max),
			"y_range_start": str(y_range_min),
			"y_range_end": str(y_range_max),
			"border_mode": str(border_mode),
			"border_width": str(border_width),
			"terminal": ENABLE_PNG if export_format == OpenSave.Format.PNG else ENABLE_PDF
		}
	)
	gnu_code += "#" if export_path.is_empty() else "" + OUTPUT_FILE
	gnu_code += ENCODER
	gnu_code += "#" if (x_range_min == x_range_max) or full_range else "" + X_RANGE
	gnu_code += "#" if (y_range_min == y_range_max) or full_range else "" + Y_RANGE
	gnu_code += PLOT_SETTING.format(
		{
			"graph_title": graph_title,
			"x_label": x_label,
			"y_label": y_label,
			"scale_x": str(graph_scale.x),
			"scale_y": str(graph_scale.y)
		}
	)
	var markings := ""
	for line_distance in kline_data.keys():
		gnu_code += VERTICAL_ARROW.format(
			{
				"distance": str(line_distance),
				"scale_x": str(graph_scale.x),
				"scale_y": str(graph_scale.y),
			}
		)
		if hide_x_axis:
			markings += XTICK.format(
				{"k_label": kline_data[line_distance], "distance":str(line_distance)}
			) + ","
	if not markings.is_empty():
		markings = markings.substr(0, markings.length() - 1)  # Remove trailing comma
		gnu_code += MARKINGS.format({"x_ticks": markings})

	# Set Legend alignment
	var align_v = Project.alignment_string[legend_vertical]
	var align_h = Project.alignment_string[legend_horizontal]
	var reverse_legend := "reverse" if should_reverse_legend else ""
	var box_options := ""
	if use_box:
		box_options = LEGEND_BOX.format(
			{"box_border_width": legend_box_outline, "box_border_spacing": legend_box_spacing}
		)
	gnu_code += LEGEND.format(
		{
			"align_v": align_v,
			"align_h": align_h,
			"reverse_legend": reverse_legend,
			"box_oprions": box_options
		}
	)
	# Add a zero axis line
	if show_zero_axis:
		gnu_code += ZERO_AXIS
	var plots = ""
	if not data_files.is_empty():
		var first_plot_line_added := false
		for data_file_dict: Dictionary in data_files:
			var data_file_added := false
			var plot_file: String = data_file_dict.get("file_path", "")
			if not FileAccess.file_exists(plot_file):
				continue

			var plot_array: Array[Dictionary] = data_file_dict.get("plot_lines", [])
			for plot: Dictionary in plot_array:
				var temp_plot_file := plot_file
				if not plot.get("visible", true):
					continue
				var plot_string: String = Project.DataFile.PlotData.LINE_MODES[
					plot.get("line_type", 0)
				].values()[0]
				var is_birch_line: bool = plot.get("birch_enabled", false)
				if is_birch_line:
					var birch_data: String = plot.get("birch_prediction_data", "")
					var birch_path := ProjectSettings.globalize_path(
						Global.CACHE_DIR
					).path_join(birch_data.sha256_text())
					var birch_file := FileAccess.open(birch_path, FileAccess.WRITE)
					if FileAccess.get_open_error() == OK:
						birch_file.store_string(birch_data)
						birch_file.close()
						temp_plot_file = birch_path
						data_file_added = false


				path_dependencies.append(temp_plot_file if not data_file_added else "")
				var plot_data := PLOT_DATA.format(
					{
						"plot_name": plot.get("title"),
						"line_type": plot_string,
						"line_width": plot.get("width"),
						"x_column": plot.get("x_column"),
						"y_column": plot.get("y_column"),
						"color": plot.get("color").to_html(false),
						"data_path": "{%s}" % str(path_dependencies.size() - 1),
					}
				)
				plots += (", " if first_plot_line_added else "") + plot_data
				if not is_birch_line:
					data_file_added = true
				first_plot_line_added = true
	if plots.strip_edges().is_empty():
		plots = "0 notitle"
	gnu_code += PLOT.format({"plot_lines": plots})
	return {"code": gnu_code, "deps": path_dependencies}
