#!/bin/bash -e


GODOT_BIN=${GODOT_BIN:-godot --no-window}
testdir=/tmp/material_maker_test
outputdir=$testdir/$(date +%s)/


if [[ ! -e .git ]]; then
	echo "This script needs to be run from the repository's root directory"
	exit 1
fi
if [[ $# -lt 1 ]]; then
	echo "Example Usage:"
	echo
	echo "	$0 --size 256 material_maker/examples/*.ptex"
	echo
	echo "The --size argument is optional but highly recommended to speed up testing."
	echo
	exit
fi


mkdir -p $outputdir
if [ ! -e .import ]; then
	echo "Generating .import files..."
	$GODOT_BIN --export "Linux/X11" /path/to/nonexistent/file >& /dev/null || true
	git restore '*.import'
fi
$GODOT_BIN --export-material -o $outputdir "$@"
cd $outputdir


if [[ -e $testdir/expect.sha ]]; then
	echo
	echo "Checksums found, testing for regressions..."
	echo
	shasum -c $testdir/expect.sha
else
	echo
	echo "Creating checksums..."
	echo
	shasum *.png | tee $testdir/expect.sha
fi


