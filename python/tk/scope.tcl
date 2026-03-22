set a 1
variable b 1
puts "global before n1: a=${a}"
puts "global before n1: b=${b}"
namespace eval n1 {
	puts "namespace n1"
	upvar 1 a a1 b b1
	puts "  inside n1, upvar1: a=${a1}"
	puts "  inside n1, upvar1: b=${b1}"
	set a 2
	variable b 2
	puts "  inside n1, a=${a}"
	puts "  inside n1, b=${b}"
	namespace eval n2 {
		puts "  namespace n2"
		upvar 1 a a2 b b2
		puts "    inside n2, upvar1: a=${a2}"
		puts "    inside n2, upvar1: b=${b2}"

		upvar 2 a a3 b b3
		puts "    inside n2, upvar2: a=${a3}"
		puts "    inside n2, upvar2: b=${b3}"

		set a 3
		variable b 3
		puts "    inside n2, a=${a}"
		puts "    inside n2, b=${b}"
	}
	puts "  ns1 after n2: a=${a}"
	puts "  ns1 after n2: b=${b}"
}

puts "global after n1: a=${a}"
puts "global after n1: b=${b}"

try { puts "n1::a=${n1::a}" } on error {} { puts "n1::a error" }
puts "n1::b=${n1::b}"

try {
puts "n1::n2::a=${n1::n2::a}"
} on error {} {
	puts "n1::n2::a error"
}
puts "n1::n2::b=${n1::n2::b}"
