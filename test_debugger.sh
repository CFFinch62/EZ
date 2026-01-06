#!/bin/bash
# Test script for EZ debugger

echo "Testing EZ Debugger"
echo "==================="
echo ""

# Test 1: Check if debug command exists
echo "Test 1: Checking if 'ez debug' command exists..."
if ./ez debug --help 2>&1 | grep -q "Error reading file"; then
    echo "✓ 'ez debug' command exists"
else
    echo "✗ 'ez debug' command not found"
    exit 1
fi

echo ""

# Test 2: Check if debugserver command exists
echo "Test 2: Checking if 'ez debugserver' command exists..."
if ./ez debugserver examples/__nonexistent__.ez 2>&1 | grep -q "Error reading file"; then
    echo "✓ 'ez debugserver' command exists"
else
    echo "✗ 'ez debugserver' command not found"
    exit 1
fi

echo ""

# Test 3: Test debugserver with JSON protocol
echo "Test 3: Testing debugserver JSON protocol..."
echo '{"type":"command","command":"initialize","params":{"file":"examples/test_debug.ez"}}' | timeout 2 ./ez debugserver examples/test_debug.ez 2>&1 | head -5

echo ""
echo "==================="
echo "Basic tests complete!"
echo ""
echo "For interactive testing, run:"
echo "  ./ez debug examples/test_debug.ez"
echo ""
echo "Available debug commands:"
echo "  step (s)     - Step to next statement"
echo "  next (n)     - Step over function calls"
echo "  continue (c) - Continue execution"
echo "  vars (v)     - Show all variables"
echo "  print <var>  - Print variable value"
echo "  help (h)     - Show help"
echo "  quit (q)     - Quit debugger"
