#!/bin/bash
cd "$(dirname "$0")"

echo "Running Flutter Shadcn CLI Tests..."
echo "===================================="
echo ""

echo "1. Running version_manager_test.dart..."
dart test test/version_manager_test.dart

echo ""
echo "2. Running skill_manager_test.dart..."
dart test test/skill_manager_test.dart

echo ""
echo "3. Running all tests..."
dart test

echo ""
echo "===================================="
echo "Tests completed!"
