# CLAUDE.md - AI Assistant Guide for spec-utils

This document provides comprehensive guidance for AI assistants working with the spec-utils codebase. It covers architecture, conventions, workflows, and best practices.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Repository Structure](#repository-structure)
- [Technology Stack](#technology-stack)
- [Development Environment Setup](#development-environment-setup)
- [Code Organization & Architecture](#code-organization--architecture)
- [Coding Conventions](#coding-conventions)
- [Build System](#build-system)
- [Testing](#testing)
- [Configuration System](#configuration-system)
- [Key Tools & Scripts](#key-tools--scripts)
- [Common Development Tasks](#common-development-tasks)
- [Important Files](#important-files)
- [External Dependencies](#external-dependencies)
- [Plugin Architecture](#plugin-architecture)
- [Best Practices for AI Assistants](#best-practices-for-ai-assistants)

---

## Project Overview

**spec-utils** is a comprehensive toolkit for style-preserving C-code transformations and analysis, specifically designed for Linux kernel modules. The project focuses on:

1. **ACSL Specification Management** - Moving and maintaining formal specifications across code versions
2. **Code Extraction** - Extracting function dependencies for verification tools (e.g., Frama-C)
3. **Callgraph Visualization** - Creating interactive maps of kernel module structure
4. **Code Analysis** - Complexity metrics, recursion detection, LSM interface analysis
5. **Verification Planning** - Tools for managing formal verification workflows

**Primary Use Case:** Analyzing Linux kernel code for formal verification with ACSL specifications

**License:** GPL v2

**Languages:** Perl 5 (minimum 5.22), with external tools in C (gcc), Python (lizard), and shell scripts

---

## Repository Structure

```
spec-utils/
├── bin/                    # 13 user-facing executable tools (main entry points)
│   ├── extricate          # Code extraction tool (33KB, plugin-based)
│   ├── merge              # ACSL specification merger (22KB)
│   ├── graph              # Callgraph generator (26KB)
│   ├── graph_diff         # Callgraph diff tool (9KB)
│   ├── complexity_plan    # Complexity analysis (18KB)
│   ├── calls              # Function/macro call analyzer (16KB)
│   ├── headers            # Header dependency visualizer (9KB)
│   ├── recursion          # Recursion detector (4KB)
│   ├── count_specifications # ACSL line counter (2KB)
│   ├── list_functions     # Priority function lister (4KB)
│   ├── get_preprocessed   # Preprocessing tool (3KB)
│   ├── lsm_diff           # LSM interface analyzer (10KB)
│   └── stapgen            # SystemTap script generator (8KB)
│
├── lib/                    # ~6,100 lines of Perl library code
│   ├── ACSL/              # ACSL specification utilities
│   ├── App/               # Application logic (Graph, Extricate plugins)
│   ├── C/                 # C code parsing and manipulation (core library)
│   ├── File/              # File merging utilities
│   ├── GCC/               # GCC preprocessor integration
│   ├── Kernel/            # Kernel-specific parsing and graph generation
│   ├── Local/             # Utility modules (Config, List, String, Terminal)
│   ├── RE/                # Common regular expressions
│   └── Configuration.pm   # Multi-system support (Linux/Contiki)
│
├── scripts/               # 13 helper scripts for maintenance and setup
│   ├── gentoo-list-deps   # Generate Gentoo dependency lists
│   ├── compile.sh         # Compilation test script
│   └── ...                # Other utility scripts
│
├── config/                # Sample configuration files
│   ├── *.conf.sample      # Example configs for tools
│   ├── etc/               # System service configs
│   ├── systemd/           # Systemd service units
│   ├── logrotate/         # Log rotation configs
│   └── systemtap/         # SystemTap configurations
│
├── t/                     # Test suite
│   ├── parse/             # Unit tests for parsing modules (7 test files)
│   └── extricate_*        # Integration tests for extricate
│
├── web/                   # Web interface for callgraph visualization
│   ├── app.psgi           # PSGI application entry point
│   ├── .config.sample     # Web server configuration example
│   └── static/            # Static web assets
│
├── doc/                   # Documentation
│   ├── FORMAT.md          # Configuration file format specifications
│   ├── EXTERNAL_DEPS.md   # External tool dependencies
│   ├── README_ru.md       # Russian documentation
│   └── *.png              # Visual documentation
│
├── .hooks/                # Git hooks (pre-commit)
├── Makefile               # Build and test automation
├── cpanfile               # Perl dependency specifications
├── .perltidyrc            # Code formatting rules
├── .travis.yml            # CI/CD configuration
├── Dockerfile             # Container setup for demos
└── README.md              # Main project documentation
```

---

## Technology Stack

### Core Technologies

**Perl 5** (5.22-5.28 tested)
- **Moose** - Object-oriented framework (primary OOP system)
- **namespace::autoclean** - Namespace cleaning
- **common::sense** - Sensible defaults
- **utf8::all** - UTF-8 support throughout

### Key Perl Modules

**Graph Processing:**
- `Graph`, `Graph::Directed` - Graph algorithms and data structures
- `Graph::Reader::Dot`, `Graph::Writer::Dot` - Graphviz DOT format I/O

**Data Structures:**
- `Hash::Ordered` - Ordered hash maps
- `Clone` - Deep cloning
- `YAML` - Configuration file parsing

**Utilities:**
- `List::MoreUtils`, `List::Util` (≥1.41) - List processing
- `File::Slurp`, `File::Which`, `File::Modified` - File operations
- `Try::Tiny` - Exception handling
- `Module::Loader` - Dynamic plugin loading

**Optional Features:**

*Merge feature:*
- `Algorithm::Diff` - Diff algorithm
- `Term::Clui` - CLI user interaction

*Report feature:*
- `Text::ANSITable` - Terminal tables
- `Excel::Writer::XLSX` - Excel generation
- `Class::CSV` - CSV handling
- `XML::Simple` - XML processing
- `Term::ProgressBar` - Progress indicators

*Web feature:*
- `Plack`/`PSGI` - Web application framework
- `Starman` - High-performance PSGI server
- `DBI`/`DBD::SQLite` - Database support
- `JSON` - JSON encoding

*Development:*
- `Smart::Comments` - Debug comments
- `DDP` - Data::Printer
- `Devel::Cover` - Code coverage
- `Devel::NYTProf` - Profiling

### External Tools

- **gcc** - C preprocessing and compilation (required)
- **graphviz (dot)** - Graph visualization (required for graph tools)
- **lizard** - Code complexity analysis (Python, required for complexity_plan)
- **sqlite3** - Database management (required for web feature)
- **Frama-C** - Formal verification (optional, for verification workflows)

---

## Development Environment Setup

### Installation

```bash
# Install Perl dependencies
cpan cpanm
cpanm --with-all-features --installdeps .

# Install external dependencies
# Debian/Ubuntu:
sudo apt-get install build-essential graphviz sqlite3
pip3 install --user lizard

# Fedora/RHEL:
sudo dnf install gcc graphviz sqlite
pip3 install --user lizard
```

### Environment Variables

Set these for convenience:

```bash
export CURRENT_KERNEL=/path/to/linux/kernel/source
export CURRENT_PROJECT=/path/to/kernel/module/directory
export GRAPH_CONFIG=/path/to/web/.config  # For web interface
```

### Testing Installation

```bash
# Run unit tests
make prove

# Run full test suite (requires kernel sources)
make test

# Run specific tool
bin/graph --help
```

---

## Code Organization & Architecture

### Module Naming Conventions

The codebase follows a namespace-based organization:

- **`C::`** - C language parsing and manipulation
  - `C::Function`, `C::Macro`, `C::Structure`, etc. - Entity classes
  - `C::FunctionSet`, `C::MacroSet`, etc. - Collection classes
  - `C::Util::*` - Utility modules

- **`Kernel::`** - Linux kernel-specific functionality
  - `Kernel::Module` - Main module parsing (6 key exported functions)
  - `Kernel::Module::Graph` - Callgraph generation
  - `Kernel::Makefile` - Makefile parsing

- **`App::`** - Application-level logic
  - `App::Graph` - Graph generation application
  - `App::Extricate::Plugin::*` - Plugin system (11 plugins)

- **`GCC::`** - GCC integration
  - `GCC::Preprocess` - Preprocessor wrapper

- **`Local::`** - Local utility modules
  - `Local::Config` - Configuration file handling
  - `Local::List::Util`, `Local::String::Util` - Utilities

- **`File::`** - File operations
  - `File::Merge`, `File::C::Merge` - Merging logic

### Design Patterns

**1. Entity-Set Pattern**

Most C code elements follow this pattern:

```perl
# Entity class (simple data holder)
package C::Function;
use Moose;
has 'name' => (is => 'ro', isa => 'Str');
has 'body' => (is => 'rw', isa => 'Str');
# ... other attributes

# Set class (collection with parsing)
package C::FunctionSet;
use Moose;
extends 'C::Set';              # Base collection class
with 'C::Parse';               # Parsing role

sub parse {
   # Parse C code and create C::Function objects
}
```

**2. Role-Based Composition**

Roles define required interfaces:

```perl
package C::Parse;
use Moose::Role;
requires 'parse';  # All parsers must implement parse()
```

**3. Plugin Architecture**

Extricate uses dynamic plugin loading:

```perl
# In bin/extricate
my $loader = Module::Loader->new;
foreach my $plugin (@plugins) {
   my $module = $loader->load("App::Extricate::Plugin::$plugin");
   $module->new->process($code, $config);
}
```

Plugins are in `lib/App/Extricate/Plugin/`:
- `Exec.pm` - Execute external commands
- `FramaC.pm` - Frama-C integration
- `Include.pm` - Include manipulation
- `Inline.pm` - Code injection
- `TestCompile.pm` - Compilation testing
- ... and 6 more

**4. Configuration Cascade**

Configuration loading follows a search path:

1. Current directory (`.toolname.conf`)
2. Home directory (`~/.config/toolname.conf`)
3. Specified via `--config` option
4. Command-line overrides config file

Implemented in `Local::Config`:

```perl
my $config = load_config($tool_name);  # Auto-searches
merge_with_cmdline_args($config, @ARGV);
```

### Key Abstractions

**`Kernel::Module`** - Main parsing interface

6 key exported functions:
1. `preprocess()` - Preprocess kernel module source
2. `parse()` - Parse preprocessed source into entities
3. `adapt()` - Adapt parsed code (resolve dependencies)
4. `get_modules_functions()` - Get module functions
5. `get_kernel_functions()` - Get kernel functions
6. `output()` - Generate output code

**`C::Set`** - Base collection class

All Set classes inherit from this:
- Provides collection management (add, remove, iterate)
- Implements serialization
- Handles set operations (union, intersection)

**Graph Generation Pipeline**

```
Source Code → Parse → Build Callgraph → Filter/Transform → Render → Output
```

Implemented across:
- `Kernel::Module::Graph` - Graph construction
- `App::Graph` - Application logic
- `Graph::Writer::Dot` - DOT output

---

## Coding Conventions

### Perl Style (`.perltidyrc`)

- **Encoding:** UTF-8
- **Line length:** 120 characters max
- **Indentation:** 3 spaces (NOT tabs)
- **Braces:** Cuddled else and blocks
- **Tightness:** High (2) for parens, brackets, braces
- **Comments:** Indented with code, no outdenting

### Code Quality Standards

```perl
# Standard module header
package My::Module;

use common::sense;           # ALWAYS include
use utf8::all;               # ALWAYS include for UTF-8 support
use Moose;                   # For OO modules
use namespace::autoclean;    # For OO modules

# ... module code ...

__PACKAGE__->meta->make_immutable;  # For Moose classes
1;
```

### Regular Expressions

```perl
use re '/aa';  # ASCII-safe regex matching
```

Common regex patterns are in `RE::Common`.

### Error Handling

```perl
use Try::Tiny;

try {
   # ... code that might fail ...
} catch {
   warn "Error: $_";
   # ... handle error ...
};
```

### Module Documentation

All `bin/` tools use POD (Plain Old Documentation):

```perl
=head1 NAME

toolname - Brief description

=head1 SYNOPSIS

   toolname [options] --kernel KDIR --module MDIR

=head1 DESCRIPTION

Detailed description...

=head1 OPTIONS

=over

=item B<--option>

Option description

=back

=cut
```

Access via `--help` flag.

### Contribution Guidelines

From `README.md`:

1. Fix warnings at [kritika.io](https://kritika.io/users/evdenis/repos/9148422910107407/)
2. Remove experimental constructions
3. Get rid of smart-matching
4. Minimize use of `Local::*` functions - prefer CPAN modules
5. Add tests for tools (e.g., DOT file comparison)
6. Use `Dist::Zilla` and prepare for CPAN
7. Add `--help` to all tools
8. Simplify regex configuration in `*Set.pm` modules

---

## Build System

### Makefile Targets

```bash
# Run unit tests only
make prove

# Prepare kernel for testing
make prepare_kernel

# Run kernel module tests (with coverage)
make kernel

# Run kernel module tests (without coverage)
make kernel_no_cover

# Run all tests (unit + kernel)
make test

# Clean generated files
make clean
```

### Kernel Testing

The Makefile can test against real kernel modules:

```bash
# Configure kernel version and module
export KERNEL_VERSION=4.19.42
export MODULE_TO_TEST=fs/ramfs
export MODULE_FUNCTIONS=--all

make kernel
```

**Default versions:** 4.19.42 (configurable)

**Tested modules:** fs/ramfs, fs/ext2, and others

### CI/CD (Travis CI)

Configured in `.travis.yml`:

**Test Matrix:**
- Perl 5.22 → Linux 4.9.x → ramfs
- Perl 5.24 → Linux 4.14.x → ext2
- Perl 5.26 → Linux 4.17.x → ext2
- Perl 5.28 → Linux 5.1.x → ramfs

**Coverage Reporting:**
- Coveralls.io

**Caching:**
- `$HOME/perl5` - Perl modules
- Kernel sources

---

## Testing

### Test Organization

```
t/
├── parse/                    # Unit tests for parsing
│   ├── EnumSet.t            # Enum parsing
│   ├── EnumSet2.t           # Complex enum tests
│   ├── GlobalSet.t          # Global variable parsing
│   ├── MacroSet.t           # Macro parsing
│   ├── StructureFields.t    # Structure field parsing
│   ├── StructureSet.t       # Structure parsing
│   └── TypedefSet.t         # Typedef parsing
├── extricate_compile_test   # Extricate compilation test
├── extricate_test_compilation
└── extricate_view_errors
```

### Test Structure

Tests use `Test::More` and inline `__DATA__` sections:

```perl
use Test::More;
use C::MacroSet;

my $code = do { local $/; <DATA> };
my $set = C::MacroSet->parse(\$code);

is($set->size, 5, "Parsed 5 macros");
# ... more tests ...

done_testing();

__DATA__
#define MACRO1 value1
#define MACRO2 value2
// ... test data ...
```

### Running Tests

```bash
# All unit tests
prove --jobs 1 --shuffle --lib --recurse t/

# Specific test
prove -l t/parse/MacroSet.t

# With coverage
PERL5OPT="-MDevel::Cover" prove -l t/

# Generate coverage report
cover -report html
```

### Integration Tests

Kernel module tests verify end-to-end functionality:

```bash
# Test extricate on real kernel module
bin/extricate --full --single --cache=0 \
   --plugin=testcompile \
   --kernel linux-4.19.42 \
   --module linux-4.19.42/fs/ramfs
```

---

## Configuration System

Configuration files use YAML or INI formats depending on the tool.

### Priority Configuration (YAML)

File: `.priority.conf` or `priority_*.conf.sample`

```yaml
priority:
   lists:
      - &1                      # Priority 1 (highest)
         - function_name1
         - function_name2
      - &2                      # Priority 2
         - function_name3
      - &3                      # Priority 3
         - function_name4
   colors:
      *1: lightcyan            # Color for priority 1 in graphs
      *2: yellow
      *3: orange
```

**Rules:**
- Function names must be unique
- Number of colors must match number of priorities
- Colors from [Graphviz color names](http://www.graphviz.org/content/color-names)

### Status Configuration (YAML)

File: `.status.conf` or `status_*.conf.sample`

```yaml
done:                          # Fully verified
   - verified_function1
   - verified_function2

lemma-proof-required:          # Verified except lemmas
   - almost_done_function

partial-specs:                 # Draft contracts
   - wip_function

specs-only:                    # Unproven contracts
   - cant_prove_function
```

**Categories:**
- `done` - Fully verified functions
- `lemma-proof-required` - Verified except lemma proofs
- `partial-specs` - Functions with draft contracts
- `specs-only` - Functions with unproven contracts

### Extricate Configuration (INI)

File: `.extricate.conf` or `extricate-*.conf.sample`

```ini
full=1                         # Enable full preprocessing
single=1                       # Single file output
cache=0                        # Disable caching

plugin=inline                  # Load inline plugin
plugin-inline-text=begin^1^#define KERNRELEASE "TEST"

plugin=exec                    # Load exec plugin
plugin-exec-file=scripts/compile.sh

plugin=testcompile             # Load test compile plugin
```

**Format:**
- Command-line options as keys
- Boolean flags: 1 (enabled) or 0 (disabled)
- Plugin-specific options: `plugin-<name>-<option>=value`
- Command-line args override config file

### Web Configuration (INI)

File: `web/.config` or `web/.config.sample`

```ini
kernel_dir=/path/to/linux-4.17/
module_dir=/path/to/linux-4.17/fs/ext2/
cache=1
cache_file=/path/to/web/_web.graph.cache
out=/path/to/web/
format=svg

priority=1
done=1

priority_config_file=/path/to/priority_ext2.conf.sample
status_config_file=/path/to/status_ext2.conf.sample
dbfile=/path/to/web/ext2.db
```

**Required fields:**
- `kernel_dir`, `module_dir` - Absolute paths
- `out` - Output directory for generated images
- `format` - Default image format (svg, png, jpeg)

**Optional fields:**
- `cache`, `cache_file` - Caching configuration
- `priority`, `priority_config_file` - Priority display
- `done`, `status_config_file` - Status display
- `dbfile` - SQLite database for metadata

### Calls Status Configuration (YAML)

File: `.calls.status.conf`

```yaml
functions:
   +/-:                        # Mixed status
      - copy_from_user
      - copy_to_user
   +:                          # Ready/approved
      - memcpy
      - kfree

macros:
   ready:
      - IS_RDONLY
   '!':                        # Ignore
      - likely
      - unlikely
```

**Purpose:** Categorize functions/macros for reporting

### Configuration Loading

Implemented in `Local::Config`:

```perl
use Local::Config;

# Auto-searches for .graph.conf, ~/.config/graph.conf, etc.
my $config = load_config('graph');

# Validate format
use Local::Config::Format;
validate_priority_config($config);
validate_status_config($config);
```

---

## Key Tools & Scripts

### bin/extricate

**Purpose:** Extract function dependencies from kernel modules for verification

**Key Features:**
- Extracts functions with all dependencies
- Preserves ACSL specifications
- Plugin architecture for extensibility
- Multiple output modes (single, double, merge)
- Partial or full preprocessing

**Common Usage:**

```bash
# Extract single function
extricate --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --functions=my_function --single

# Extract all functions with preprocessing
extricate --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --all --full

# Use plugins
extricate --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --functions=my_function --plugin=framac --plugin=testcompile
```

**Plugins:** See [Plugin Architecture](#plugin-architecture)

### bin/merge

**Purpose:** Semi-automatically move ACSL specs between code versions

**Key Features:**
- Location-independent function matching
- External diff tool integration (meld, kdiff3)
- Conflict resolution
- Preserves formatting

**Common Usage:**

```bash
# Merge specs from old to new version
merge --old-kernel linux-4.14 --new-kernel linux-4.17 \
   --module fs/ext2
```

### bin/graph

**Purpose:** Generate callgraph visualizations

**Key Features:**
- DOT/SVG/PNG output formats
- Priority and status coloring
- Filtering by function/priority/status
- Caching for performance

**Common Usage:**

```bash
# Generate full callgraph
graph --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --format=svg --output=callgraph.svg

# Filter by priority
graph --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --priority=1 --format=png

# Show only unverified functions
graph --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --available
```

### bin/complexity_plan

**Purpose:** Generate complexity metrics for functions

**Key Features:**
- Uses lizard for analysis
- Multiple output formats (table, CSV, Excel, SQLite)
- Progress tracking
- Integration with graph tool via SQLite

**Common Usage:**

```bash
# Generate complexity report
complexity_plan --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --format=table

# Export to Excel
complexity_plan --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --format=xlsx --output=complexity.xlsx

# Generate database for web interface
complexity_plan --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --format=db --output=web/module.db
```

### bin/calls

**Purpose:** Analyze function and macro call patterns

**Common Usage:**

```bash
calls --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT \
   --output=calls_report.txt
```

### bin/recursion

**Purpose:** Detect direct and indirect recursion

**Common Usage:**

```bash
recursion --kernel $CURRENT_KERNEL --module $CURRENT_PROJECT
```

### scripts/

Helper scripts for maintenance:

- `scripts/gentoo-list-deps` - Generate Gentoo package deps
- `scripts/compile.sh` - Compilation test helper
- Other utility scripts for specific tasks

---

## Common Development Tasks

### Adding a New Tool

1. Create executable in `bin/`:

```perl
#!/usr/bin/env perl

use common::sense;
use utf8::all;
use Getopt::Long;
use Pod::Usage;

# ... tool logic ...

__END__

=head1 NAME

newtool - Description

=head1 SYNOPSIS

   newtool [options]

=head1 OPTIONS

...

=cut
```

2. Add library modules in `lib/` if needed
3. Add tests in `t/`
4. Update `README.md` with tool description
5. Add configuration format to `doc/FORMAT.md` if needed

### Adding a New Parser

1. Create entity class in `lib/C/`:

```perl
package C::NewEntity;
use Moose;
use namespace::autoclean;

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'data' => (is => 'rw', isa => 'Str');

__PACKAGE__->meta->make_immutable;
```

2. Create set class:

```perl
package C::NewEntitySet;
use Moose;
use namespace::autoclean;
extends 'C::Set';
with 'C::Parse';

sub parse {
   my ($self, $code_ref) = @_;
   # Parse $$code_ref and create C::NewEntity objects
   # Add to set with $self->add($entity)
}

__PACKAGE__->meta->make_immutable;
```

3. Add tests in `t/parse/NewEntitySet.t`
4. Integrate with `Kernel::Module` if needed

### Adding an Extricate Plugin

1. Create plugin in `lib/App/Extricate/Plugin/`:

```perl
package App::Extricate::Plugin::MyPlugin;

use common::sense;
use utf8::all;

sub new {
   my ($class) = @_;
   bless {}, $class;
}

sub process {
   my ($self, $code_ref, $config) = @_;

   # Get plugin-specific config
   my $option = $config->{'plugin-myplugin-option'};

   # Process $$code_ref
   # Modify in place or return new code

   return $code_ref;
}

1;
```

2. Use in extricate:

```bash
extricate --plugin=myplugin --plugin-myplugin-option=value ...
```

### Running Code Quality Checks

```bash
# Run perltidy on file
perltidy myfile.pl

# Check with perlcritic (if installed)
perlcritic --severity 3 lib/

# Run tests with coverage
PERL5OPT="-MDevel::Cover" make prove
cover -report html

# View coverage
firefox cover_db/coverage.html
```

### Debugging

```perl
# Use Smart::Comments (development only)
use Smart::Comments;

### Variable: $var
### Array: @array

# Use Data::Printer
use DDP;
p $complex_structure;

# Use Devel::NYTProf for profiling
perl -d:NYTProf bin/graph ...
nytprofhtml
firefox nytprof/index.html
```

### Working with Web Interface

```bash
# Start web server
cd web
plackup -s Starman -p 8889 app.psgi

# Or use Docker
docker build -t my_callgraph .
docker run -d -p 127.0.0.1:8889:80 my_callgraph

# Access at http://localhost:8889/graph
```

**GET Parameters:**
- `fmt=svg|png|jpeg` - Image format
- `func=func1,func2` - Specific functions
- `level=n` - Priority level
- `no-display-done=1` - Hide verified functions
- `reverse=1` - Reverse callgraph direction
- `available=1` - Show available for verification

---

## Important Files

### .perltidyrc

Defines code formatting rules. **Always format code** before committing.

### cpanfile

Dependency specification. When adding dependencies:

1. Add to appropriate section (requires/feature)
2. Test with: `cpanm --with-all-features --installdeps .`
3. Update Travis CI config if needed

### Makefile

Build and test automation. When modifying:

1. Keep kernel version configurable
2. Maintain `prove` target for quick tests
3. Ensure `clean` removes all generated files

### .travis.yml

CI configuration. When updating:

1. Test matrix covers Perl 5.22-5.28
2. Each Perl version has appropriate kernel version
3. Coverage reporting still works

### Dockerfile

Demo container setup. When modifying:

1. Ensure kernel downloads correctly
2. Web server starts automatically
3. Port 80 exposed

---

## External Dependencies

### Required for All Tools

- **gcc** - C preprocessing and compilation
- **Perl 5.22+** - Core language

### Tool-Specific Dependencies

| Tool | Dependencies |
|------|-------------|
| `graph`, `graph_diff`, `headers` | graphviz (dot) |
| `extricate` | gcc |
| `complexity_plan` | lizard (Python), sqlite3 (optional) |
| `web` | sqlite3 |
| All verification workflows | Frama-C (optional) |

### Installation Commands

**Debian/Ubuntu:**
```bash
sudo apt-get install build-essential graphviz sqlite3
pip3 install --user lizard
```

**Fedora/RHEL:**
```bash
sudo dnf install gcc graphviz sqlite
pip3 install --user lizard
```

**From Source:**
```bash
# Frama-C (optional)
opam install frama-c
```

---

## Plugin Architecture

### Extricate Plugins

Located in `lib/App/Extricate/Plugin/`, plugins process extracted code.

**Available Plugins:**

1. **Exec** - Execute external commands on code
   - Config: `plugin-exec-file=script.sh`

2. **Filter** - Filter code based on patterns
   - Config: `plugin-filter-pattern=...`

3. **FramaC** - Frama-C integration
   - Config: `plugin-framac-options=...`

4. **Include** - Manipulate include directives
   - Config: `plugin-include-add=header.h`

5. **Inline** - Inject inline code
   - Config: `plugin-inline-text=begin^1^code`

6. **Modeline** - Insert editor modelines
   - Config: `plugin-modeline-style=vim`

7. **Rewrite** - Code rewriting rules
   - Config: `plugin-rewrite-rules=...`

8. **SmartLib** - Smart library handling
   - Config: `plugin-smartlib-mode=...`

9. **Spatch** - Coccinelle/Spatch integration
   - Config: `plugin-spatch-file=patch.cocci`

10. **StubSpec** - Generate stub specifications
    - Config: `plugin-stubspec-style=...`

11. **TestCompile** - Test compilation
    - Automatically compiles extracted code

### Plugin Loading

Plugins are loaded dynamically via `Module::Loader`:

```perl
use Module::Loader;

my $loader = Module::Loader->new;
foreach my $plugin_name (@plugins) {
   my $plugin_class = "App::Extricate::Plugin::" . ucfirst($plugin_name);
   my $plugin = $loader->load($plugin_class);
   my $instance = $plugin->new();
   $code_ref = $instance->process($code_ref, $config);
}
```

### Plugin Execution Order

Plugins execute in the order specified:

```bash
# Filter runs before inline
extricate --plugin=filter --plugin=inline ...
```

Or in config:

```ini
plugin=filter
plugin=inline
plugin=testcompile
```

---

## Best Practices for AI Assistants

### When Working with This Codebase

1. **Always Use Moose Properly**
   - Include `namespace::autoclean`
   - Call `__PACKAGE__->meta->make_immutable`
   - Use proper type constraints

2. **Follow the Entity-Set Pattern**
   - Entity classes are simple data holders
   - Set classes extend `C::Set` and implement `C::Parse` role
   - Parsing logic goes in Set classes, not Entity classes

3. **Configuration Files**
   - YAML for complex configs (priority, status, calls)
   - INI for simple configs (extricate, web)
   - Always validate with `Local::Config::Format`

4. **Testing**
   - Add unit tests for all parsers in `t/parse/`
   - Use `__DATA__` sections for test code
   - Test against real kernel modules when possible

5. **Code Style**
   - Run `perltidy` before committing
   - Use 3-space indentation
   - Keep lines under 120 characters
   - Include `use common::sense` and `use utf8::all`

6. **External Tools**
   - Check tool availability with `File::Which`
   - Provide helpful error messages if tools missing
   - Document external dependencies

7. **Performance**
   - Use caching for expensive operations (parsing, graph generation)
   - Check file modification times with `File::Modified`
   - Invalidate cache on config changes

8. **Documentation**
   - Add POD to all `bin/` tools
   - Update `README.md` for new features
   - Update `doc/FORMAT.md` for new config formats
   - Update this file (CLAUDE.md) for architectural changes

### Common Pitfalls to Avoid

1. **Don't mix entity and set responsibilities**
   - Parsing belongs in Set classes, not Entity classes

2. **Don't hardcode paths**
   - Use environment variables or config files
   - Make paths absolute in config files

3. **Don't ignore preprocessor state**
   - C code must be preprocessed before parsing
   - Use `GCC::Preprocess` or `Kernel::Module::preprocess()`

4. **Don't forget about ACSL comments**
   - They have special parsing rules
   - Use `C::AcslcommentSet` for handling them

5. **Don't assume single-file modules**
   - Kernel modules often span multiple files
   - Use `Kernel::Makefile` to find all sources

6. **Don't skip configuration validation**
   - Validate with `Local::Config::Format`
   - Provide clear error messages

7. **Don't ignore graph cycles**
   - Use `C::Util::Cycle` for detection
   - Handle recursion appropriately

### Useful Code Patterns

**Loading and parsing a module:**

```perl
use Kernel::Module qw(preprocess parse adapt);

my $preprocessed = preprocess($kernel_dir, $module_dir);
my $entities = parse($preprocessed);
my $adapted = adapt($entities, $kernel_dir, $module_dir);
```

**Creating a callgraph:**

```perl
use Kernel::Module::Graph;
use Graph::Writer::Dot;

my $graph = Kernel::Module::Graph->new(
   functions => $function_set,
   module_functions => \@module_funcs,
);
my $callgraph = $graph->build();

my $writer = Graph::Writer::Dot->new();
$writer->write_graph($callgraph, 'output.dot');
```

**Parsing C entities:**

```perl
use C::FunctionSet;
use C::MacroSet;

my $code = read_file($file);

my $funcs = C::FunctionSet->new();
$funcs->parse(\$code);

my $macros = C::MacroSet->new();
$macros->parse(\$code);

foreach my $func ($funcs->set) {
   say $func->name;
}
```

**Using configuration:**

```perl
use Local::Config qw(load_config);
use Local::Config::Format qw(validate_priority_config);

my $config = load_config('graph');
validate_priority_config($config);

my $priorities = $config->{priority}{lists};
my $colors = $config->{priority}{colors};
```

---

## Additional Resources

- **Main Documentation:** [README.md](README.md)
- **Configuration Formats:** [doc/FORMAT.md](doc/FORMAT.md)
- **External Dependencies:** [doc/EXTERNAL_DEPS.md](doc/EXTERNAL_DEPS.md)
- **Russian Docs:** [doc/README_ru.md](doc/README_ru.md)
- **Example Configs:** `config/*.conf.sample`
- **CI Status:** [Travis CI](https://travis-ci.org/evdenis/spec-utils)
- **Coverage:** [Coveralls](https://coveralls.io/github/evdenis/spec-utils?branch=devel)

---

## Repository State

This CLAUDE.md was generated on **2025-11-18** from the current state of the repository.

**Current Branch:** `claude/claude-md-mi4a34p56oedmarn-012XhUcUBJq28C1qQfeLtiYo`

**Recent Commits:**
- `cbb3bd0` - scripts: gentoo-list-deps: Update paths
- `6244970` - extricate: plugin: FramaC: add $FUNCTION parameter to cli args
- `f823ad8` - lib: Kernel: Module: refactor macro handling
- `35fa4b7` - lib: GCC: Preprocess: fix uninit variable
- `aabf147` - lib: Kernel: Module: refactor acslcomment handling

For the most up-to-date information, refer to the actual source files and documentation.

---

*This document is maintained for AI assistants working with the spec-utils codebase. When making significant architectural changes, please update this file accordingly.*
