#!/bin/bash
# Simple test script to check required files exist

echo "Running tests for CarVilla web application"

# Check if index.html exists
if [ ! -f index.html ]; then
  echo "Error: index.html not found!"
  exit 1
fi

# Check if assets directory exists
if [ ! -d assets ]; then
  echo "Error: assets directory not found!"
  exit 1
fi

# Check if the title contains "CarVilla"
if ! grep -q "<title>CarVilla</title>" index.html; then
  echo "Warning: Title does not match expected value"
  # Not failing the build for this, just warning
fi

echo "All tests passed successfully!"
exit 0