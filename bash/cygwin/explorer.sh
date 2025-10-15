#!/bin/bash

explorer()
{
	local args=()
	readarray -t args < <(cygpath -w "${@}")
	command explorer "${args[@]}"
}
