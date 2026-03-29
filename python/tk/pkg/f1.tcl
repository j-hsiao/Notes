package provide testpkg 0.1
package require Tcl 8.6

namespace eval ::testpkg {
	variable v 32
	proc fun {a b} {
		puts "I got $a and $b."
	}
	puts "testpkg loaded!"
}
