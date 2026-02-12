#!/bin/bash

fun1() {
	echo inner1-start----------
	trap -p ERR RETURN SIGINT
	echo inner1-stop-----------
	trap 'echo inner returned' RETURN
	trap 'echo inner errored' ERR
	trap 'echo inner sigint' SIGINT
	echo inner2-start----------
	trap -p ERR RETURN SIGINT
	echo inner2-stop-----------
}

fun2() {
	# inner traps overwrite outer traps
	# by default, ERR and RETURN are not inherited
	# when entering a new function.
	trap 'echo outer return' RETURN
	trap 'echo outer err' ERR
	trap 'echo outer sigint' SIGINT
	echo outer1-start----------
	trap -p ERR RETURN SIGINT
	echo outer1-stop-----------
	fun1
	echo outer2-start----------
	trap -p ERR RETURN SIGINT
	echo outer2-stop-----------
}

fun3() {
	echo inner1-start----------
	trap -p ERR RETURN SIGINT
	echo inner1-stop-----------
	trap 'echo inner returned' RETURN
	trap 'echo inner errored' ERR
	trap 'echo inner sigint' SIGINT
	echo inner2-start----------
	trap -p ERR RETURN SIGINT
	echo inner2-stop-----------

	trap - ERR RETURN SIGINT
	echo inner3-start----------
	trap -p ERR RETURN SIGINT
	echo inner3-stop-----------
}

fun4() {
	# inner traps overwrite outer traps
	# by default, ERR and RETURN are not inherited
	# when entering a new function.
	trap 'echo outer return' RETURN
	trap 'echo outer err' ERR
	trap 'echo outer sigint' SIGINT
	echo outer1-start----------
	trap -p ERR RETURN SIGINT
	echo outer1-stop-----------
	fun3
	echo outer2-start----------
	trap -p ERR RETURN SIGINT
	echo outer2-stop-----------
}


fun5() {
	echo innest1-start----------
	trap -p ERR RETURN SIGINT
	echo innest1-stop-----------

	trap 'echo innest' ERR RETURN SIGINT

	echo innest2-start----------
	trap -p ERR RETURN SIGINT
	echo innest2-stop-----------
}

fun6() {
	echo inner1-start----------
	trap -p ERR RETURN SIGINT
	echo inner1-stop-----------

	fun5

	echo inner2-start----------
	trap -p ERR RETURN SIGINT
	echo inner2-stop-----------

	trap - ERR RETURN SIGINT

	echo inner3-start----------
	trap -p ERR RETURN SIGINT
	echo inner3-stop-----------
}
fun7() {
	trap 'echo outer' ERR RETURN SIGINT

	echo outer1-start----------
	trap -p ERR RETURN SIGINT
	echo outer1-stop-----------

	fun6

	echo outer2-start----------
	trap -p ERR RETURN SIGINT
	echo outer2-stop-----------
}


fun2
printf '%s\n' ------------------------------
fun4
printf '%s\n' ------------------------------
fun7
