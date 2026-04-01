import 'package:json_annotation/json_annotation.dart';

part 'movie_model.g.dart';

@JsonSerializable()
class Movie {
  final int id;
  final String title;
  @JsonKey(name: 'poster_path')
  final String? posterPath;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  final String? overview;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.overview,
  });

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
  Map<String, dynamic> toJson() => _$MovieToJson(this);

  String get fullPosterPath => posterPath != null 
    ? 'https://image.tmdb.org/t/p/w185$posterPath' 
    : 'https://via.placeholder.com/185x278?text=No+Image';
}
