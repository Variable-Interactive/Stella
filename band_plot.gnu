
set terminal pdfcairo enhanced \
color solid \
font 'Noto Naskh Arabic,15' \
size 5.0in, 6.0in
set size 1.0, 1.0 

set output '/home/variable/Programing Projects/Godot/Godot 4.x Projects/g4v/Bandstructure.pdf' 
set encoding iso_8859_1 
set yrange[-2.0:2.0] 
set border 15.0 linewidth 2.5 
set title 'Bandstructure' 

set xlabel 'KPOINTS Distance'
set ylabel 'E - E_f (eV)' 


set arrow from 0.0,graph(0,0) to 0.0,graph(1.0, 1.0) nohead ls 1 lt 2 lw 2 lc rgb 'magenta' 


set arrow from 0.1,graph(0,0) to 0.1,graph(1.0, 1.0) nohead ls 1 lt 2 lw 2 lc rgb 'magenta' 


set arrow from 0.2,graph(0,0) to 0.2,graph(1.0, 1.0) nohead ls 1 lt 2 lw 2 lc rgb 'magenta' 

set xtics ("{/Symbol G}" 0.0,"{/Symbol M}" 0.1,"{/Symbol B}" 0.2) 
set zeroaxis ls 1.5 dt 4 lw 2.5 lc rgb 'magenta' 

plot \
'/home/variable/Programing Projects/Godot/Godot 4.x Projects/g4v/BAND.dat' using 1:2 with lines linewidth 1.0 linecolor rgbcolor '#00f3ff' title 'Spin Down' \
