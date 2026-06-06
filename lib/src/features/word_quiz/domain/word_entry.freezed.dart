// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WordEntry {

 String get id; String get word; String? get ipa; DifficultyLevel get level; List<WordMeaning> get meanings; String? get topic; List<String> get tags; DateTime get createdAt; DateTime? get updatedAt; String? get status; String? get createdBy;
/// Create a copy of WordEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordEntryCopyWith<WordEntry> get copyWith => _$WordEntryCopyWithImpl<WordEntry>(this as WordEntry, _$identity);

  /// Serializes this WordEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.ipa, ipa) || other.ipa == ipa)&&(identical(other.level, level) || other.level == level)&&const DeepCollectionEquality().equals(other.meanings, meanings)&&(identical(other.topic, topic) || other.topic == topic)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,ipa,level,const DeepCollectionEquality().hash(meanings),topic,const DeepCollectionEquality().hash(tags),createdAt,updatedAt,status,createdBy);

@override
String toString() {
  return 'WordEntry(id: $id, word: $word, ipa: $ipa, level: $level, meanings: $meanings, topic: $topic, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt, status: $status, createdBy: $createdBy)';
}


}

/// @nodoc
abstract mixin class $WordEntryCopyWith<$Res>  {
  factory $WordEntryCopyWith(WordEntry value, $Res Function(WordEntry) _then) = _$WordEntryCopyWithImpl;
@useResult
$Res call({
 String id, String word, String? ipa, DifficultyLevel level, List<WordMeaning> meanings, String? topic, List<String> tags, DateTime createdAt, DateTime? updatedAt, String? status, String? createdBy
});




}
/// @nodoc
class _$WordEntryCopyWithImpl<$Res>
    implements $WordEntryCopyWith<$Res> {
  _$WordEntryCopyWithImpl(this._self, this._then);

  final WordEntry _self;
  final $Res Function(WordEntry) _then;

/// Create a copy of WordEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? word = null,Object? ipa = freezed,Object? level = null,Object? meanings = null,Object? topic = freezed,Object? tags = null,Object? createdAt = null,Object? updatedAt = freezed,Object? status = freezed,Object? createdBy = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,ipa: freezed == ipa ? _self.ipa : ipa // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as DifficultyLevel,meanings: null == meanings ? _self.meanings : meanings // ignore: cast_nullable_to_non_nullable
as List<WordMeaning>,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WordEntry].
extension WordEntryPatterns on WordEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordEntry value)  $default,){
final _that = this;
switch (_that) {
case _WordEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordEntry value)?  $default,){
final _that = this;
switch (_that) {
case _WordEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String word,  String? ipa,  DifficultyLevel level,  List<WordMeaning> meanings,  String? topic,  List<String> tags,  DateTime createdAt,  DateTime? updatedAt,  String? status,  String? createdBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordEntry() when $default != null:
return $default(_that.id,_that.word,_that.ipa,_that.level,_that.meanings,_that.topic,_that.tags,_that.createdAt,_that.updatedAt,_that.status,_that.createdBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String word,  String? ipa,  DifficultyLevel level,  List<WordMeaning> meanings,  String? topic,  List<String> tags,  DateTime createdAt,  DateTime? updatedAt,  String? status,  String? createdBy)  $default,) {final _that = this;
switch (_that) {
case _WordEntry():
return $default(_that.id,_that.word,_that.ipa,_that.level,_that.meanings,_that.topic,_that.tags,_that.createdAt,_that.updatedAt,_that.status,_that.createdBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String word,  String? ipa,  DifficultyLevel level,  List<WordMeaning> meanings,  String? topic,  List<String> tags,  DateTime createdAt,  DateTime? updatedAt,  String? status,  String? createdBy)?  $default,) {final _that = this;
switch (_that) {
case _WordEntry() when $default != null:
return $default(_that.id,_that.word,_that.ipa,_that.level,_that.meanings,_that.topic,_that.tags,_that.createdAt,_that.updatedAt,_that.status,_that.createdBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordEntry extends WordEntry {
  const _WordEntry({required this.id, required this.word, this.ipa, required this.level, required final  List<WordMeaning> meanings, this.topic, final  List<String> tags = const <String>[], required this.createdAt, this.updatedAt, this.status, this.createdBy}): _meanings = meanings,_tags = tags,super._();
  factory _WordEntry.fromJson(Map<String, dynamic> json) => _$WordEntryFromJson(json);

@override final  String id;
@override final  String word;
@override final  String? ipa;
@override final  DifficultyLevel level;
 final  List<WordMeaning> _meanings;
@override List<WordMeaning> get meanings {
  if (_meanings is EqualUnmodifiableListView) return _meanings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_meanings);
}

@override final  String? topic;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  DateTime createdAt;
@override final  DateTime? updatedAt;
@override final  String? status;
@override final  String? createdBy;

/// Create a copy of WordEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordEntryCopyWith<_WordEntry> get copyWith => __$WordEntryCopyWithImpl<_WordEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.ipa, ipa) || other.ipa == ipa)&&(identical(other.level, level) || other.level == level)&&const DeepCollectionEquality().equals(other._meanings, _meanings)&&(identical(other.topic, topic) || other.topic == topic)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,ipa,level,const DeepCollectionEquality().hash(_meanings),topic,const DeepCollectionEquality().hash(_tags),createdAt,updatedAt,status,createdBy);

@override
String toString() {
  return 'WordEntry(id: $id, word: $word, ipa: $ipa, level: $level, meanings: $meanings, topic: $topic, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt, status: $status, createdBy: $createdBy)';
}


}

/// @nodoc
abstract mixin class _$WordEntryCopyWith<$Res> implements $WordEntryCopyWith<$Res> {
  factory _$WordEntryCopyWith(_WordEntry value, $Res Function(_WordEntry) _then) = __$WordEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String word, String? ipa, DifficultyLevel level, List<WordMeaning> meanings, String? topic, List<String> tags, DateTime createdAt, DateTime? updatedAt, String? status, String? createdBy
});




}
/// @nodoc
class __$WordEntryCopyWithImpl<$Res>
    implements _$WordEntryCopyWith<$Res> {
  __$WordEntryCopyWithImpl(this._self, this._then);

  final _WordEntry _self;
  final $Res Function(_WordEntry) _then;

/// Create a copy of WordEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? word = null,Object? ipa = freezed,Object? level = null,Object? meanings = null,Object? topic = freezed,Object? tags = null,Object? createdAt = null,Object? updatedAt = freezed,Object? status = freezed,Object? createdBy = freezed,}) {
  return _then(_WordEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,ipa: freezed == ipa ? _self.ipa : ipa // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as DifficultyLevel,meanings: null == meanings ? _self._meanings : meanings // ignore: cast_nullable_to_non_nullable
as List<WordMeaning>,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
