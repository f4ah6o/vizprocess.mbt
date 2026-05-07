default:
    @just --list

fmt:
    moon fmt

check:
    moon check

build:
    moon build

test:
    moon test

clean:
    moon clean

ci: fmt check test
