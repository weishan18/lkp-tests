#!/bin/bash

# prefer $HOSTNAME over $(hostname)
get_hostname()
{
	[ -n "$HOSTNAME" ] && {
		echo "$HOSTNAME"
		return
	}

	hostname
}
