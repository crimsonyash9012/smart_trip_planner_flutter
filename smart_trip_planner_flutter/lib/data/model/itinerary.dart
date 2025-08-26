import 'package:isar/isar.dart';

part 'itinerary.g.dart';

@collection
class Itinerary {
  Id id = Isar.autoIncrement;
  late String title;
  late String content;
  late DateTime createdAt;
}
