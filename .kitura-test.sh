# Run Kitura-NIO tests
swift test
echo ">> Done running tests. Now preparing to run Kitura tests ..."

# Clone Kitura
echo ">> cd .. && git clone https://github.com/IBM-Swift/Kitura && cd Kitura"
cd .. && git clone https://github.com/IBM-Swift/Kitura && cd Kitura

# Set KITURA_NIO
echo ">> export KITURA_NIO=1"
export KITURA_NIO=1

# Build once
echo ">> swift build"
swift build

# Edit package Kitura-NIO to point to the current branch
echo ">> swift package edit Kitura-NIO --path ../Kitura-NIO"
swift package edit Kitura-NIO --path ../Kitura-NIO
echo ">> swift package edit returned $?."

# If the `swift package edit` command failed, exit with the same failure code
PACKAGE_EDIT_RESULT=$?
if [[ $PACKAGE_EDIT_RESULT != 0 ]]; then
    echo ">> Failed to edit the Kitura-NIO dependency."
    exit $PACKAGE_EDIT_RESULT
fi

# Run Kitura tests
echo ">> swift test"
swift test

# If the tests failed, exit
TEST_EXIT_CODE=$?
if [[ $TEST_EXIT_CODE != 0 ]]; then
    exit $TEST_EXIT_CODE
fi
echo ">> Done running Kitura tests."

# Move back to the original build directory. This is needed on macOS builds for the subsequent swiftlint step.
cd ../Kitura-NIO
