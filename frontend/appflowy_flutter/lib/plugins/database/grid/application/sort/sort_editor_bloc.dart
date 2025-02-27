import 'dart:async';

import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/application/sort/sort_service.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/sort/sort_info.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/sort_entities.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/sort_entities.pbserver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'util.dart';

part 'sort_editor_bloc.freezed.dart';

class SortEditorBloc extends Bloc<SortEditorEvent, SortEditorState> {
  SortEditorBloc({
    required this.viewId,
    required this.fieldController,
    required List<SortInfo> sortInfos,
  })  : _sortBackendSvc = SortBackendService(viewId: viewId),
        super(SortEditorState.initial(sortInfos, fieldController.fieldInfos)) {
    _dispatch();
  }

  final String viewId;
  final SortBackendService _sortBackendSvc;
  final FieldController fieldController;
  void Function(List<FieldInfo>)? _onFieldFn;

  void _dispatch() {
    on<SortEditorEvent>(
      (event, emit) async {
        await event.when(
          initial: () {
            _startListening();
          },
          didReceiveFields: (List<FieldInfo> fields) {
            final List<FieldInfo> allFields = List.from(fields);
            final List<FieldInfo> creatableFields = List.from(fields);
            creatableFields.retainWhere((field) => field.canCreateSort);
            emit(
              state.copyWith(
                allFields: allFields,
                creatableFields: creatableFields,
              ),
            );
          },
          setCondition: (SortInfo sortInfo, SortConditionPB condition) async {
            final result = await _sortBackendSvc.updateSort(
              fieldId: sortInfo.fieldInfo.id,
              sortId: sortInfo.sortId,
              fieldType: sortInfo.fieldInfo.fieldType,
              condition: condition,
            );
            result.fold((l) => {}, (err) => Log.error(err));
          },
          deleteAllSorts: () async {
            final result = await _sortBackendSvc.deleteAllSorts();
            result.fold((l) => {}, (err) => Log.error(err));
          },
          didReceiveSorts: (List<SortInfo> sortInfos) {
            emit(state.copyWith(sortInfos: sortInfos));
          },
          deleteSort: (SortInfo sortInfo) async {
            final result = await _sortBackendSvc.deleteSort(
              fieldId: sortInfo.fieldInfo.id,
              sortId: sortInfo.sortId,
              fieldType: sortInfo.fieldInfo.fieldType,
            );
            result.fold((l) => null, (err) => Log.error(err));
          },
          reorderSort: (fromIndex, toIndex) async {
            if (fromIndex < toIndex) {
              toIndex--;
            }

            final fromId = state.sortInfos[fromIndex].sortId;
            final toId = state.sortInfos[toIndex].sortId;

            final newSorts = [...state.sortInfos];
            newSorts.insert(toIndex, newSorts.removeAt(fromIndex));
            emit(state.copyWith(sortInfos: newSorts));
            final result = await _sortBackendSvc.reorderSort(
              fromSortId: fromId,
              toSortId: toId,
            );
            result.fold((l) => null, (err) => Log.error(err));
          },
        );
      },
    );
  }

  void _startListening() {
    _onFieldFn = (fields) {
      add(SortEditorEvent.didReceiveFields(List.from(fields)));
    };

    fieldController.addListener(
      listenWhen: () => !isClosed,
      onReceiveFields: _onFieldFn,
      onSorts: (sorts) {
        add(SortEditorEvent.didReceiveSorts(sorts));
      },
    );
  }

  @override
  Future<void> close() async {
    if (_onFieldFn != null) {
      fieldController.removeListener(onFieldsListener: _onFieldFn);
      _onFieldFn = null;
    }
    return super.close();
  }
}

@freezed
class SortEditorEvent with _$SortEditorEvent {
  const factory SortEditorEvent.initial() = _Initial;
  const factory SortEditorEvent.didReceiveFields(List<FieldInfo> fieldInfos) =
      _DidReceiveFields;
  const factory SortEditorEvent.didReceiveSorts(List<SortInfo> sortInfos) =
      _DidReceiveSorts;
  const factory SortEditorEvent.setCondition(
    SortInfo sortInfo,
    SortConditionPB condition,
  ) = _SetCondition;
  const factory SortEditorEvent.deleteSort(SortInfo sortInfo) = _DeleteSort;
  const factory SortEditorEvent.deleteAllSorts() = _DeleteAllSorts;
  const factory SortEditorEvent.reorderSort(int oldIndex, int newIndex) =
      _ReorderSort;
}

@freezed
class SortEditorState with _$SortEditorState {
  const factory SortEditorState({
    required List<SortInfo> sortInfos,
    required List<FieldInfo> creatableFields,
    required List<FieldInfo> allFields,
  }) = _SortEditorState;

  factory SortEditorState.initial(
    List<SortInfo> sortInfos,
    List<FieldInfo> fields,
  ) {
    return SortEditorState(
      creatableFields: getCreatableSorts(fields),
      allFields: fields,
      sortInfos: sortInfos,
    );
  }
}
