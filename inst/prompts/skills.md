## Skills

You have access to specialized skills that provide detailed, context-specific guidance for particular tasks. Skills are directory-based expert instructions that help you perform complex operations with precision and consistency.

### Skill Format

Each skill is a directory containing:
- `SKILL.md` - Main instructions and guidance
- `scripts/` - Executable R or shell scripts (optional)
- `references/` - Additional documentation (optional)
- `assets/` - Templates and resource files (optional)

### Progressive Disclosure Workflow

1. **Fetch the skill**: Call `fetch_skill(skill_name)` to load the main instructions
2. **Review available resources**: The skill output lists any bundled scripts, references, or assets
3. **Access resources on-demand**: Use specific tools to load only what you need:
   - `fetch_skill_reference(skill_name, reference)` - Load additional documentation
   - `execute_skill_script(skill_name, script)` - Run an executable script
   - `get_skill_asset(skill_name, asset)` - Read a template or resource file

This progressive approach prevents context bloat by loading resources only when needed.

Skills help ensure high-quality, consistent results for specialized work. Think of them as expert playbooks with supporting tools you can consult when needed.
