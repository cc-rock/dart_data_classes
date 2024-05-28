# dart_data_classes
An attempt at implementing data classes for Dart using the macros feature

## Requirements

1. Dart SDK >= `3.5.0-152.0.dev`

3. If using `flutter`, you probably need to be on the `master` branch

4. Enable the `macros` experiment in your project's `analisys-options.yaml` file, like this:
```
analyzer:
  enable-experiment:
    - macros
```
4. Add the dependency to your project's `pubspec.yaml` file, like this:
```
dependencies:
  ...
  dart_data_classes:
    git: https://github.com/cc-rock/dart_data_classes.git
```
If you decide to clone the repo instead (see next point), you'll need something like this:
```
dependencies:
  ...
  dart_data_classes:
    path: ../dart_data_classes
```
5. If using VSCode, in order to enjoy the great support for macros, unfortunately you'll need the project containing the macros (this one), to be opened in the IDE together with the one in which the macros are used.. this is because of some current limitation of the macro system and the analysis server, see https://github.com/dart-lang/sdk/issues/55688 and https://github.com/dart-lang/sdk/issues/55670.
The easiest way to achieve this is to clone this repo locally and create a common folder in which you place both this project and your project, and then open that parent folder with VSCode.
