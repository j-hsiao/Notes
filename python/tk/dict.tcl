dict set a k1 v1
dict set a k2 v2

puts "$a"

foreach {k v} $a {puts "$k: $v"}
dict for {k v} $a {puts "$k: $v"}

dict with a {puts "$k1 $k2"}

array set myarr {a b c d}
puts "[array get myarr]"

unset a
set a [dict create k1 v1 k2 v2]
foreach {k v} $a {puts "$k: $v"}
dict for {k v} $a {puts "$k: $v"}

puts [dict get $a k1]
puts [dict get $a k2]
