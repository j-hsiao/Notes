namespace eval myns {
	variable mynsvar value_set_in_namespace
	set varfromset "set variable in namespace but is a global."
	proc myproc {} {
		variable a "variable in proc creates variable in namespace"
	}

	proc myproc2 {} {
		variable mynsvar
		if {$mynsvar != "value_set_in_namespace"} {
			error "variable without value should just link to namespace var."
		}
	}
}

proc myproc {} {
	variable a "variable in proc in global namespace just makes a global"
}



if {![info exists myns::varfromset]} {error "it should be a namespace variable."}
if {[info exists varfromset]} {error "it should be a namespace variable."}

# `variable` command in a proc creates a namespace variable.
if {[info exists myns::a]} { error "myns::a should not exist yet." }
myns::myproc
if {![info exists myns::a]} { error "myns::a Should have been created." }

# `variable` in proc in global namespace creates a variable in global namespace.
if {[info exists a]} { error "global a should not exist yet." }
myproc
if {![info exists a]} { error "global a should ahve been created." }

myns::myproc2

puts ok
