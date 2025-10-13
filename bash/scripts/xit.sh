#!/bin/bash

xit()
{
	((SHLVL > 1)) && exit || echo 'top shell'
}
