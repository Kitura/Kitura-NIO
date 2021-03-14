#!/bin/sh

# Run Kitura-NIO tests
travis_start "swift_test"
echo ">> Executing Kitura-NIO tests"
swift test
SWIFT_TEST_STATUS=$?
travis_end
if [ $SWIFT_TEST_STATUS -ne 0 ]; then
  echo ">> swift test command exited with $SWIFT_TEST_STATUS"
  # Return a non-zero status so that Package-Builder will generate a backtrace
  return $SWIFT_TEST_STATUS
fi

# For now, short-circuit kitura tests until those are stabalized.
return 0



# Clone Kitura
set -e
echo ">> Building Kitura"
travis_start "swift_build_kitura"
cd .. && git clone https://github.com/Kitura/Kitura && cd Kitura

# Set KITURA_NIO
export KITURA_NIO=1

# Build once
swift build

# Edit package Kitura-NIO to point to the current branch
echo ">> Editing Kitura package to use latest Kitura-NIO"
swift package edit Kitura-NIO --path ../Kitura-NIO
travis_end
set +e

# Run Kitura tests
travis_start "swift_test_kitura"
echo ">> Executing Kitura tests"
swift test
SWIFT_TEST_STATUS=$?
travis_end
if [ $SWIFT_TEST_STATUS -ne 0 ]; then
  echo ">> swift test command exited with $SWIFT_TEST_STATUS"
  # Return a non-zero status so that Package-Builder will generate a backtrace
  return $SWIFT_TEST_STATUS
fi

# Move back to the original build directory. This is needed on macOS builds for the subsequent swiftlint step.
cd ../Kitura-NIO
