set x [list a b c 1 2 3]

set y [list $x a b c 1 2 3]
set z [concat $x a b c 1 2 3]

puts "x: $x"
puts "y: $y"
puts "z: $z"

set a [linsert $x 5 x y z]
puts "a: $a"

set b [lreplace $a 1 2]
puts "b: $b"
