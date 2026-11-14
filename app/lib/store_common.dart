/// 永続化層（端末 / Web 試用版）で共通の型。
library;

import 'models.dart';

class ProjectState {
  final List<Sign> signs;
  final String area;
  final int nextSeq;
  ProjectState({required this.signs, required this.area, required this.nextSeq});
}
