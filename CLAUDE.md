# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Envious is a functional .env file parser for Elixir. It does not mutate the environment or have side effects - it purely parses .env file strings into maps.

**Key characteristics:**
- Uses NimbleParsec for parser implementation
- Purely functional (no side effects)
- Returns `{:ok, map}` or `{:error, message}` (with `parse!/1` variant)

## Commands

### Development
```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/envious_test.exs

# Run a single test by line number
mix test test/envious_test.exs:42

# Format code
mix format

# Generate documentation
mix docs
```

### Building and Publishing
```bash
# Compile the project
mix compile

# Build the Hex package
mix hex.build

# Publish to Hex (requires authentication)
mix hex.publish
```

## Architecture

### Core Modules

**`Envious`** (lib/envious.ex)
- Public API module with two functions: `parse/1` and `parse!/1`
- Delegates parsing to `Envious.Parser`
- Handles error formatting with line/column information
- Converts parser results to maps

**`Envious.Parser`** (lib/envious/parser.ex)
- NimbleParsec-based parser implementation
- Built using parser combinators that compose small parsing units
- Main parsing flow:
  1. Skip leading whitespace/newlines
  2. Parse key-value pairs or comment lines
  3. Skip trailing whitespace/newlines
  4. Repeat until input consumed

### Parser Implementation Details

The parser uses NimbleParsec combinators defined at compile-time:

- **`key_value`**: Parses `[export] KEY=VALUE` patterns
- **`val`**: Handles quoted (single/double) and unquoted values
- **`comment_line`**: Ignores lines starting with `#`
- **`var_name`**: Matches POSIX-compliant variable names `[a-zA-Z_][a-zA-Z0-9_]*`

Post-traversal callbacks:
- **`trim_value/5`**: Removes trailing whitespace from unquoted values
- **`to_tuple/5`**: Converts `[value, key]` to `{key, value}` tuples
- **`process_escape_sequences/5`**: Converts `\n`, `\t`, `\r`, `\\`, `\"`, `\'` in quoted strings

## Testing

Tests are organized to match the module structure:
- `test/envious_test.exs` - Tests for the public API
- `test/envious/parser_test.exs` - Tests for parser internals

When modifying the parser, ensure tests cover:
- Edge cases (empty values, multi-line values, escape sequences)
- Error conditions (invalid syntax, unclosed quotes)
- POSIX compliance (valid variable names)
- Both Unix (`\n`) and Windows (`\r\n`) line endings

## Elixir Version

Requires Elixir ~> 1.16 (CI uses 1.19.2 with OTP 28.1)

## Commit Message Style

Use concise, one-line commit messages in the imperative mood:

- ✅ "Add Envious.Helpers module with value extraction and type conversion functions"
- ✅ "Update CI to Elixir 1.19.2/OTP 28.1"
- ✅ "Remove unused config folder"
- ❌ Multi-line commit messages with body paragraphs
