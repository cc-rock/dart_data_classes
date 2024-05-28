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
5. If using VSCode, in order to enjoy the great IDE support for macros, unfortunately you'll need the project containing the macros (this one), to be opened in the IDE together with the one in which the macros are used.. this is because of some current limitation of the macro system and the analysis server, see https://github.com/dart-lang/sdk/issues/55688 and https://github.com/dart-lang/sdk/issues/55670.
The easiest way to achieve this is to clone this repo locally and create a common folder in which you place both this project and your project, and then open that parent folder with VSCode.

## Usage example
```dart
@DataClass()
class Person {
  final String name;
  @DefaultValue('Brown')
  final String hairColour;
  final int age;
}

@DataClass()
class Employee extends Person {
  final double salary;
}

final person = Person(name: 'John', age: 25);
final employee = Employee(name: 'Peter', age: 30, salary: 12.4);

print('Person: ${person.name}, ${person.age}');
print('Hair colours: ${person.hairColour, employee.hairColour}'); // 'Brown' for both
print('Employee: ${employee.name}, ${employee.age}, ${employee.salary}');
```

## Features and limitations
1. Data classes can not define an un-named constructor, it must be generated and will have named parameters for all fields (required, except for nullable fields and fields that have a default value)
2. Data classes can only extend other data classes, extending any other class is an error.
3. Sub-classes inherit all fields and constructor parameters of super classes, together with eventual default values.
4. Equality is supported, `==` and `hashCode` will be generated.
5. Collections (List, Map, Set) are currently kept as mutable and non-deeply compared (will be fixed soon)
6. `copyWith`: coming soon.
7. `toString`: likely to be coming at some point.
8. Unions: no special support is needed.. since inheritance is supported, we can just use sealed classes and write something like this:
```dart
@DataClass()
sealed class Event {
  final String origin;
}

@DataClass()
class TapEvent extends Event {
  final Point coordinates;
}

@DataClass()
class SwipeEvent extends Event {
  final Point start;
  final Point end;
}

final event = TapEvent(origin: 'origin', coordinates: Point(1, 2));

switch (event) {
  case TapEvent tapEvent:
    print(tapEvent.coordinates);
    break;
  case SwipeEvent swipeEvent:
    print(swipeEvent.start);
    print(swipeEvent.end);
    break;
}
```
