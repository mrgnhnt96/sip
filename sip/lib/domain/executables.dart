import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'executables.g.dart';

@JsonSerializable()
class Executables extends Equatable {
  const Executables({required this.dart, required this.flutter});

  factory Executables.fromJson(Map<String, dynamic> json) =>
      _$ExecutablesFromJson(json);

  final String? dart;
  final String? flutter;

  Map<String, dynamic> toJson() => _$ExecutablesToJson(this);

  @override
  List<Object?> get props => _$props;
}
