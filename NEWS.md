# side (development version)

* Added thinking mode support for Anthropic, OpenAI, and Google Gemini. Toggle with Ctrl+T in the chat interface. When enabled, the model's reasoning process is streaming into a collapsible block above each response. For Anthropic and Google Gemini, the number of reasoning tokens is set to 1024 when reasoning is on. For OpenAI, the reasoning effort parameter is set to "medium."

# side 0.0.2

Aligned Skills with Claude's storage format. Skills now use a directory-based 
format with `SKILL.md` instead of standalone `.md` files. User skills 
in `~/.config/side/skills/` must be migrated to the new format. The 
`side::kick()` agent now has access to a skill creation Skill; you can ask
side to use that skill to convert your existing ones.

# side 0.0.1

Initial "release" of the package. The side package will not go to CRAN, but I'll 
use the GitHub Releases feature here to track changes to the project from here on.
