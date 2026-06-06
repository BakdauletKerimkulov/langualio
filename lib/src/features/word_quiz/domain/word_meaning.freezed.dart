// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_meaning.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WordMeaning {

 PartOfSpeech get partOfSpeech; String get translation; List<String> get alternativeTranslations; String? get definitionEn; String? get definitionRu; String get exampleEn; String get exampleRu;
/// Create a copy of WordMeaning
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordMeaningCopyWith<WordMeaning> get copyWith => _$WordMeaningCopyWithImpl<WordMeaning>(this as WordMeaning, _$identity);

  /// Serializes this WordMeaning to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordMeaning&&(identical(other.partOfSpeech, partOfSpeech) || other.partOfSpeech == partOfSpeech)&&(identical(other.translation, translation) || other.translation == translation)&&const DeepCollectionEquality().equals(other.alternativeTranslations, alternativeTranslations)&&(identical(other.definitionEn, definitionEn) || other.definitionEn == definitionEn)&&(identical(other.definitionRu, definitionRu) || other.definitionRu == definitionRu)&&(identical(other.exampleEn, exampleEn) || other.exampleEn == exampleEn)&&(identical(other.exampleRu, exampleRu) || other.exampleRu == exampleRu));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,partOfSpeech,translation,const DeepCollectionEquality().hash(alternativeTranslations),definitionEn,definitionRu,exampleEn,exampleRu);

@override
String toString() {
  return 'WordMeaning(partOfSpeech: $partOfSpeech, translation: $translation, alternativeTranslations: $alternativeTranslations, definitionEn: $definitionEn, definitionRu: $definitionRu, exampleEn: $exampleEn, exampleRu: $exampleRu)';
}


}

/// @nodoc
abstract mixin class $WordMeaningCopyWith<$Res>  {
  factory $WordMeaningCopyWith(WordMeaning value, $Res Function(WordMeaning) _then) = _$WordMeaningCopyWithImpl;
@useResult
$Res call({
 PartOfSpeech partOfSpeech, String translation, List<String> alternativeTranslations, String? definitionEn, String? definitionRu, String exampleEn, String exampleRu
});




}
/// @nodoc
class _$WordMeaningCopyWithImpl<$Res>
    implements $WordMeaningCopyWith<$Res> {
  _$WordMeaningCopyWithImpl(this._self, this._then);

  final WordMeaning _self;
  final $Res Function(WordMeaning) _then;

/// Create a copy of WordMeaning
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? partOfSpeech = null,Object? translation = null,Object? alternativeTranslations = null,Object? definitionEn = freezed,Object? definitionRu = freezed,Object? exampleEn = null,Object? exampleRu = null,}) {
  return _then(_self.copyWith(
partOfSpeech: null == partOfSpeech ? _self.partOfSpeech : partOfSpeech // ignore: cast_nullable_to_non_nullable
as PartOfSpeech,translation: null == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as String,alternativeTranslations: null == alternativeTranslations ? _self.alternativeTranslations : alternativeTranslations // ignore: cast_nullable_to_non_nullable
as List<String>,definitionEn: freezed == definitionEn ? _self.definitionEn : definitionEn // ignore: cast_nullable_to_non_nullable
as String?,definitionRu: freezed == definitionRu ? _self.definitionRu : definitionRu // ignore: cast_nullable_to_non_nullable
as String?,exampleEn: null == exampleEn ? _self.exampleEn : exampleEn // ignore: cast_nullable_to_non_nullable
as String,exampleRu: null == exampleRu ? _self.exampleRu : exampleRu // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WordMeaning].
extension WordMeaningPatterns on WordMeaning {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordMeaning value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordMeaning() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordMeaning value)  $default,){
final _that = this;
switch (_that) {
case _WordMeaning():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordMeaning value)?  $default,){
final _that = this;
switch (_that) {
case _WordMeaning() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PartOfSpeech partOfSpeech,  String translation,  List<String> alternativeTranslations,  String? definitionEn,  String? definitionRu,  String exampleEn,  String exampleRu)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordMeaning() when $default != null:
return $default(_that.partOfSpeech,_that.translation,_that.alternativeTranslations,_that.definitionEn,_that.definitionRu,_that.exampleEn,_that.exampleRu);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PartOfSpeech partOfSpeech,  String translation,  List<String> alternativeTranslations,  String? definitionEn,  String? definitionRu,  String exampleEn,  String exampleRu)  $default,) {final _that = this;
switch (_that) {
case _WordMeaning():
return $default(_that.partOfSpeech,_that.translation,_that.alternativeTranslations,_that.definitionEn,_that.definitionRu,_that.exampleEn,_that.exampleRu);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PartOfSpeech partOfSpeech,  String translation,  List<String> alternativeTranslations,  String? definitionEn,  String? definitionRu,  String exampleEn,  String exampleRu)?  $default,) {final _that = this;
switch (_that) {
case _WordMeaning() when $default != null:
return $default(_that.partOfSpeech,_that.translation,_that.alternativeTranslations,_that.definitionEn,_that.definitionRu,_that.exampleEn,_that.exampleRu);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordMeaning implements WordMeaning {
  const _WordMeaning({required this.partOfSpeech, required this.translation, final  List<String> alternativeTranslations = const <String>[], this.definitionEn, this.definitionRu, required this.exampleEn, required this.exampleRu}): _alternativeTranslations = alternativeTranslations;
  factory _WordMeaning.fromJson(Map<String, dynamic> json) => _$WordMeaningFromJson(json);

@override final  PartOfSpeech partOfSpeech;
@override final  String translation;
 final  List<String> _alternativeTranslations;
@override@JsonKey() List<String> get alternativeTranslations {
  if (_alternativeTranslations is EqualUnmodifiableListView) return _alternativeTranslations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_alternativeTranslations);
}

@override final  String? definitionEn;
@override final  String? definitionRu;
@override final  String exampleEn;
@override final  String exampleRu;

/// Create a copy of WordMeaning
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordMeaningCopyWith<_WordMeaning> get copyWith => __$WordMeaningCopyWithImpl<_WordMeaning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordMeaningToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordMeaning&&(identical(other.partOfSpeech, partOfSpeech) || other.partOfSpeech == partOfSpeech)&&(identical(other.translation, translation) || other.translation == translation)&&const DeepCollectionEquality().equals(other._alternativeTranslations, _alternativeTranslations)&&(identical(other.definitionEn, definitionEn) || other.definitionEn == definitionEn)&&(identical(other.definitionRu, definitionRu) || other.definitionRu == definitionRu)&&(identical(other.exampleEn, exampleEn) || other.exampleEn == exampleEn)&&(identical(other.exampleRu, exampleRu) || other.exampleRu == exampleRu));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,partOfSpeech,translation,const DeepCollectionEquality().hash(_alternativeTranslations),definitionEn,definitionRu,exampleEn,exampleRu);

@override
String toString() {
  return 'WordMeaning(partOfSpeech: $partOfSpeech, translation: $translation, alternativeTranslations: $alternativeTranslations, definitionEn: $definitionEn, definitionRu: $definitionRu, exampleEn: $exampleEn, exampleRu: $exampleRu)';
}


}

/// @nodoc
abstract mixin class _$WordMeaningCopyWith<$Res> implements $WordMeaningCopyWith<$Res> {
  factory _$WordMeaningCopyWith(_WordMeaning value, $Res Function(_WordMeaning) _then) = __$WordMeaningCopyWithImpl;
@override @useResult
$Res call({
 PartOfSpeech partOfSpeech, String translation, List<String> alternativeTranslations, String? definitionEn, String? definitionRu, String exampleEn, String exampleRu
});




}
/// @nodoc
class __$WordMeaningCopyWithImpl<$Res>
    implements _$WordMeaningCopyWith<$Res> {
  __$WordMeaningCopyWithImpl(this._self, this._then);

  final _WordMeaning _self;
  final $Res Function(_WordMeaning) _then;

/// Create a copy of WordMeaning
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? partOfSpeech = null,Object? translation = null,Object? alternativeTranslations = null,Object? definitionEn = freezed,Object? definitionRu = freezed,Object? exampleEn = null,Object? exampleRu = null,}) {
  return _then(_WordMeaning(
partOfSpeech: null == partOfSpeech ? _self.partOfSpeech : partOfSpeech // ignore: cast_nullable_to_non_nullable
as PartOfSpeech,translation: null == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as String,alternativeTranslations: null == alternativeTranslations ? _self._alternativeTranslations : alternativeTranslations // ignore: cast_nullable_to_non_nullable
as List<String>,definitionEn: freezed == definitionEn ? _self.definitionEn : definitionEn // ignore: cast_nullable_to_non_nullable
as String?,definitionRu: freezed == definitionRu ? _self.definitionRu : definitionRu // ignore: cast_nullable_to_non_nullable
as String?,exampleEn: null == exampleEn ? _self.exampleEn : exampleEn // ignore: cast_nullable_to_non_nullable
as String,exampleRu: null == exampleRu ? _self.exampleRu : exampleRu // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
