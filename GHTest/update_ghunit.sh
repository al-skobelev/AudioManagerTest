#!/bin/sh

if [ ! -d "gh-unit" ] ; then
    git clone git://github.com/gabriel/gh-unit.git
fi
cd gh-unit/Project-iOS
make $@
