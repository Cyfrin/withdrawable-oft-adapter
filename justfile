# List available commands
list:
    @just --list

# Install dependencies
install:
    @forge install 

# Run tests
test: install
    @forge test