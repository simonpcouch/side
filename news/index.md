# Changelog

## side (development version)

## side 0.0.2

Aligned Skills with Claude’s storage format. Skills now use a
directory-based format with `SKILL.md` instead of standalone `.md`
files. User skills in `~/.config/side/skills/` must be migrated to the
new format. The
[`side::kick()`](https://simonpcouch.github.io/side/reference/kick.md)
agent now has access to a skill creation Skill; you can ask side to use
that skill to convert your existing ones.

## side 0.0.1

Initial “release” of the package. The side package will not go to CRAN,
but I’ll use the GitHub Releases feature here to track changes to the
project from here on.
