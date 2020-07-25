# Some examples that can be achieved with MyMakefile

## Example 00

Basic hello word project.

To compile and run the main application:
```sh
make clean
make
make run
```

## Example 01

Basic hello word project with unit tests and Doxygen code.

To compile and run the main application:
```sh
make veryclean
make
make run
```

To

To compile and run unit-tests of the main application:
```sh
make veryclean
make check
```

If a gcov have been installed you will see an coverage report.
