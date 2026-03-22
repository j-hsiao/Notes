set x "The    quick    brown    fox    jumped    over    the    lazy    dog."
for {variable i 0} {$i < [string length $x]} {incr i} {
	puts "$i [string wordstart $x $i] [string wordend $x $i] [string range $x [string wordstart $x $i] [string wordend $x $i]]"
}

puts "i is $i"
