# EZ Debugger Documentation

## Overview

The EZ debugger is a full-featured debugging system that allows you to step through EZ programs, inspect variables, set breakpoints, and examine the call stack. It provides two interfaces:

1. **CLI Debugger** (`ez debug`) - Interactive command-line debugger for terminal use
2. **JSON-RPC Server** (`ez debugserver`) - Protocol-based debugger for IDE integration

## Why the Debugger Was Added

Debugging is an essential part of software development. While print statements and error messages are helpful, a proper debugger allows developers to:

- **Step through code** line by line to understand execution flow
- **Inspect variables** at any point during execution
- **Set breakpoints** to pause at specific locations
- **Examine the call stack** to understand function call chains
- **Identify bugs** more quickly and efficiently

This debugger was created to provide EZ developers with a professional debugging experience similar to what's available in other modern programming languages.

## Architecture

### Core Components

#### 1. Debugger Engine (`pkg/debugger/debugger.go`)

The core debugger manages:
- **Breakpoints**: Set, clear, and check breakpoints
- **Step Modes**: Control execution flow (Continue, StepInto, StepOver, StepOut)
- **Call Stack**: Track function calls and returns
- **Variable Inspection**: Access environment variables at any stack frame

**Key Types**:

```go
type Debugger struct {
    enabled      bool
    stepMode     StepMode
    callStack    []*CallFrame
    breakpoints  map[string]map[int]*Breakpoint
    stepDepth    int
    paused       bool
    pauseChan    chan struct{}
    resumeChan   chan struct{}
    mu           sync.RWMutex
    eventHandler EventHandler
}

type CallFrame struct {
    FunctionName string
    Node         ast.Node
    Env          *object.Environment
    Location     *ast.Location
    CallDepth    int
}

type Breakpoint struct {
    File      string
    Line      int
    Condition string  // Future: conditional breakpoints
    Enabled   bool
}
```

**Step Modes**:
- `ModeContinue`: Run until next breakpoint
- `ModeStepInto`: Step to next statement, entering function calls
- `ModeStepOver`: Step to next statement, skipping over function calls
- `ModeStepOut`: Run until return from current function

#### 2. Interpreter Integration (`pkg/interpreter/evaluator.go`)

The debugger hooks into the interpreter's evaluation loop:

```go
func Eval(node ast.Node, env *Environment) Object {
    // Debug hook: before evaluation
    if dbg := debugger.GetGlobalDebugger(); dbg != nil && dbg.IsEnabled() {
        if isSteppableStatement(node) {
            dbg.BeforeEval(node, env)
        }
    }
    
    // ... normal evaluation ...
}
```

**Steppable Statements**:
- Variable declarations
- Assignments
- Expression statements
- Return statements
- Control flow (if, while, for, loop)
- Break/continue statements

#### 3. CLI Handler (`pkg/debugger/cli_handler.go`)

Provides an interactive command-line interface:

**Commands**:
- `step` / `s` - Step to next statement (step into)
- `next` / `n` - Step over function calls
- `out` / `o` - Step out of current function
- `continue` / `c` - Continue until next breakpoint
- `break <file>:<line>` / `b <file>:<line>` - Set breakpoint
- `clear <file>:<line>` - Clear breakpoint
- `breakpoints` / `bp` - List all breakpoints
- `print <var>` / `p <var>` - Print variable value
- `vars` / `v` - Show all variables
- `stack` / `st` - Show call stack
- `help` / `h` - Show help
- `quit` / `q` - Quit debugger

#### 4. JSON Protocol (`pkg/debugger/json_protocol.go`)

Implements a JSON-RPC protocol for IDE integration over stdin/stdout.

**Message Format**:

```json
{
  \"type\": \"command\" | \"event\",
  \"command\": \"<command_name>\",
  \"event\": \"<event_name>\",
  \"params\": {},
  \"data\": {}
}
```

**Commands** (IDE → Debugger):
- `initialize` - Initialize debug session
- `start` - Start program execution
- `stepInto` - Step into next statement
- `stepOver` - Step over function calls
- `stepOut` - Step out of current function
- `continue` - Continue execution
- `setBreakpoint` - Set a breakpoint
- `clearBreakpoint` - Clear a breakpoint
- `getVariables` - Get variables for a stack frame
- `getStackTrace` - Get the call stack
- `terminate` - End debug session

**Events** (Debugger → IDE):
- `initialized` - Debugger ready
- `started` - Program execution started
- `stopped` - Execution paused (with location)
- `output` - Program output
- `error` - Error occurred
- `variableUpdate` - Variable changed
- `variables` - Variable list response
- `stackTrace` - Stack trace response
- `breakpointSet` - Breakpoint confirmed
- `breakpointCleared` - Breakpoint removed
- `exited` - Program completed
- `terminated` - Debug session ended

### Environment Extensions (`pkg/object/object.go`)

Added methods to support variable inspection:

```go
// GetAll returns all variables in this environment
func (e *Environment) GetAll() map[string]Object {
    result := make(map[string]Object)
    for name, value := range e.store {
        result[name] = value
    }
    return result
}

// Outer returns the parent environment
func (e *Environment) Outer() *Environment {
    return e.outer
}
```

## CLI Usage

### Starting the Debugger

```bash
ez debug myprogram.ez
```

### Example Session

```
╔══════════════════════════════════════════════════════════╗
║        EZ Interactive Debugger - Debug Mode             ║
╚══════════════════════════════════════════════════════════╝

Debugging: myprogram.ez
Type 'help' at the debug prompt for available commands
Execution will start automatically. Use 'step' to begin stepping.

→ Paused at myprogram.ez:10:1

debug> vars
Variables in current frame:
  x = 10
  y = 20

debug> step
→ Paused at myprogram.ez:11:1

debug> print x
x = 10

debug> break myprogram.ez:15
Breakpoint set at myprogram.ez:15

debug> continue
→ Hit breakpoint at myprogram.ez:15:1

debug> stack
Call stack:
  #0 main at myprogram.ez:15:1
  #1 <program> at myprogram.ez:1:1

debug> quit
```

## JSON Protocol Usage

### Starting the Debug Server

```bash
ez debugserver myprogram.ez
```

### Protocol Examples

#### Initialize

**Command**:
```json
{
  \"type\": \"command\",
  \"command\": \"initialize\",
  \"params\": {
    \"file\": \"myprogram.ez\",
    \"workingDir\": \"/path/to/project\"
  }
}
```

**Response**:
```json
{
  \"type\": \"event\",
  \"event\": \"initialized\",
  \"data\": {}
}
```

#### Set Breakpoint

**Command**:
```json
{
  \"type\": \"command\",
  \"command\": \"setBreakpoint\",
  \"params\": {
    \"file\": \"myprogram.ez\",
    \"line\": 15
  }
}
```

**Response**:
```json
{
  \"type\": \"event\",
  \"event\": \"breakpointSet\",
  \"data\": {
    \"file\": \"myprogram.ez\",
    \"line\": 15
  }
}
```

#### Step Into

**Command**:
```json
{
  \"type\": \"command\",
  \"command\": \"stepInto\",
  \"params\": {}
}
```

**Response**:
```json
{
  \"type\": \"event\",
  \"event\": \"stopped\",
  \"data\": {
    \"location\": {
      \"file\": \"myprogram.ez\",
      \"line\": 11,
      \"column\": 1
    }
  }
}
```

#### Get Variables

**Command**:
```json
{
  \"type\": \"command\",
  \"command\": \"getVariables\",
  \"params\": {
    \"frameIndex\": 0
  }
}
```

**Response**:
```json
{
  \"type\": \"event\",
  \"event\": \"variables\",
  \"data\": {
    \"variables\": [
      {\"name\": \"x\", \"value\": \"10\", \"type\": \"int\"},
      {\"name\": \"y\", \"value\": \"20\", \"type\": \"int\"}
    ]
  }
}
```

## IDE Integration Guide

### For IDE Developers

To integrate the EZ debugger into your IDE:

1. **Detect Debugger Support**:
   ```bash
   ez debugserver --help
   # If successful, debugserver is available
   ```

2. **Start Debug Session**:
   ```bash
   ez debugserver /path/to/file.ez
   ```

3. **Communicate via JSON-RPC**:
   - Send commands to stdin
   - Read events from stdout
   - Each message is line-delimited JSON

4. **Handle Events**:
   - `stopped` - Update UI to show current line
   - `variables` - Update variable panel
   - `stackTrace` - Update call stack panel
   - `output` - Display program output
   - `error` - Show error messages

5. **Provide UI Controls**:
   - Start/Stop debugging
   - Step Into/Over/Out
   - Continue
   - Set/Clear breakpoints
   - Variable inspection
   - Call stack navigation

### Example IDE Integration (Python)

See the [EZ IDE](https://github.com/yourfork/MyEZ/tree/main/IDE) for a complete reference implementation using PyQt6.

Key components:
- `app/go_debug_session.py` - JSON-RPC communication
- `app/debug_panel.py` - Debug UI
- `app/main_window.py` - Integration

## Implementation Details

### Code Structure

```
pkg/debugger/
├── debugger.go         # Core debugger engine
├── cli_handler.go      # CLI interface
└── json_protocol.go    # JSON-RPC protocol

pkg/interpreter/
└── evaluator.go        # Debug hooks

pkg/object/
└── object.go           # Environment extensions

cmd/ez/
├── main.go             # Debug command handlers
└── commands.go         # Command definitions
```

### Thread Safety

The debugger uses mutexes to ensure thread-safe access:
- `debugger.mu` - Protects debugger state
- `debuggerMu` - Protects global debugger instance

### Pause/Resume Mechanism

The debugger uses channels for pause/resume control:

```go
// Pause execution
func (d *Debugger) Pause() {
    d.paused = true
    <-d.resumeChan  // Block until resumed
}

// Resume execution
func (d *Debugger) Resume() {
    if d.paused {
        d.resumeChan <- struct{}{}
        d.paused = false
    }
}
```

## Future Enhancements

Potential improvements for the debugger:

1. **Conditional Breakpoints**: Break only when a condition is true
2. **Watch Expressions**: Monitor specific expressions
3. **Data Breakpoints**: Break when a variable changes
4. **Reverse Debugging**: Step backwards through execution
5. **Multi-threaded Debugging**: Debug concurrent programs
6. **Remote Debugging**: Debug programs on remote machines
7. **Expression Evaluation**: Evaluate arbitrary expressions at breakpoints
8. **Breakpoint Hit Counts**: Break after N hits
9. **Log Points**: Log messages without stopping
10. **Hot Reload**: Modify code during debugging

## Troubleshooting

### Debugger Not Pausing

**Problem**: Debugger runs through entire program without pausing.

**Solution**: Ensure you're using step mode:
```bash
ez debug myprogram.ez
# Then type 'step' at the prompt
```

### Breakpoints Not Working

**Problem**: Breakpoints are set but not hit.

**Solution**: 
- Verify the file path is correct (use absolute paths)
- Ensure the line number has executable code
- Check that the breakpoint is enabled

### Variable Not Found

**Problem**: Cannot print a variable.

**Solution**:
- Ensure you're in the correct stack frame
- Check variable name spelling
- Verify the variable is in scope

### IDE Connection Issues

**Problem**: IDE cannot connect to debugserver.

**Solution**:
- Ensure `ez debugserver` is in PATH
- Check stdin/stdout are not buffered
- Verify JSON messages are line-delimited

## Contributing

Contributions to the debugger are welcome! Areas for improvement:

- Additional CLI commands
- Protocol enhancements
- Performance optimizations
- Bug fixes
- Documentation improvements

## License

The EZ debugger is part of the EZ language project and follows the same license.

## Credits

Debugger implementation by [Your Name] as an enhancement to the EZ programming language.

---

For more information about EZ, see the [main README](README.md).
