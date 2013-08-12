evie
====

Eagle VCS Image Export

Create fancy images of your boards and schematic files prior to commiting then into your favourite VCS.
Currently only git is supported, but it should be no problem to create a commit hook for your preferred VCS.

These scripts take care that
* The shown layers are always the same
* You get seperate renderings of front- and back of your PCBs
* Lovely colors are used (default: green pcb, gold finish)

## Installation

1. copy `export-images.ulp` into your `<eagle install dir>/ulp` (or any other ulp path set in your eagle config)
1. copy `export-images-colors.scr` into your `<eagle install dir>/scr` (or any other scr path set in your eagle config)
1. adjust the eagle binary path inside `git-pre-commit`
1. rename and copy `git-pre-commit` to your `<project>/.git/hooks/pre-commit`

## Usage

Just git commit and enjoy the magic happening. And ignore the eagle windows opening and disappearing, they are a lie.

## FAQ

I used `git commit <file> -m '<message>'` and strange things happened.
* I know, just `git add` the generated images, and they will disappered from the changed list. It looks like they are 
  included in the commit, but for some reasons not tracked correctly.
