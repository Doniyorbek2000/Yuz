import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';

void main() {
  group('BeautyAdjustments', () {
    test('clamps values into 0..100', () {
      final adjustments = BeautyAdjustments({BeautyEffect.skinSmoothing: 140, BeautyEffect.skinBrightening: -5});
      expect(adjustments.valueOf(BeautyEffect.skinSmoothing), 100);
      expect(adjustments.valueOf(BeautyEffect.skinBrightening), 0);
    });

    test('missing values fall back to defaults', () {
      final adjustments = BeautyAdjustments({BeautyEffect.skinSmoothing: 10});
      expect(
        adjustments.valueOf(BeautyEffect.texturePreservation),
        BeautyAdjustments.defaults.valueOf(BeautyEffect.texturePreservation),
      );
    });

    test('maps 0..100 sliders to 0..1 engine parameters', () {
      final parameters = BeautyAdjustments({
        BeautyEffect.skinSmoothing: 25,
        BeautyEffect.texturePreservation: 100,
        BeautyEffect.skinBrightening: 0,
      }).toEngineParameters();
      expect(parameters.skinSmoothing, 0.25);
      expect(parameters.texturePreservation, 1.0);
      expect(parameters.skinBrightening, 0.0);
    });

    test('JSON round trip ignores unknown keys and tolerates bad types', () {
      final original = BeautyAdjustments({BeautyEffect.skinSmoothing: 42, BeautyEffect.skinBrightening: 7});
      final json = {...original.toJson(), 'futureEffect': 99, 'skinBrightening': 'oops'};
      final restored = BeautyAdjustments.fromJson(json);
      expect(restored.valueOf(BeautyEffect.skinSmoothing), 42);
      expect(restored.valueOf(BeautyEffect.skinBrightening), 0);
    });

    test('value equality', () {
      expect(BeautyAdjustments({BeautyEffect.skinSmoothing: 3}), BeautyAdjustments({BeautyEffect.skinSmoothing: 3}));
      expect(
        BeautyAdjustments({BeautyEffect.skinSmoothing: 3}).hashCode,
        BeautyAdjustments({BeautyEffect.skinSmoothing: 3}).hashCode,
      );
    });
  });

  group('BeautyEditorState', () {
    final a = BeautyAdjustments({BeautyEffect.skinSmoothing: 10});
    final b = BeautyAdjustments({BeautyEffect.skinSmoothing: 20});

    test('commit records undo steps and undo restores them', () {
      final state = const BeautyEditorState(current: BeautyAdjustments.defaults).commit(a).commit(b);
      expect(state.current, b);
      expect(state.undo().current, a);
      expect(state.undo().undo().current, BeautyAdjustments.defaults);
      expect(state.undo().undo().canUndo, isFalse);
    });

    test('committing an identical value is a no-op', () {
      final state = BeautyEditorState(current: a).commit(a);
      expect(state.canUndo, isFalse);
    });

    test('a continuous edit is a single undo step', () {
      var state = BeautyEditorState(current: a).checkpoint();
      for (var v = 11; v <= 30; v++) {
        state = state.preview(state.current.withValue(BeautyEffect.skinSmoothing, v));
      }
      state = state.finalizeEdit();
      expect(state.history.length, 1);
      expect(state.undo().current, a);
    });

    test('an edit that changes nothing leaves no undo step', () {
      final state = BeautyEditorState(current: a).checkpoint().finalizeEdit();
      expect(state.canUndo, isFalse);
    });

    test('history is bounded', () {
      var state = const BeautyEditorState(current: BeautyAdjustments.defaults);
      for (var i = 1; i <= BeautyEditorState.maxHistory + 20; i++) {
        state = state.commit(BeautyAdjustments({BeautyEffect.skinSmoothing: i % 101}));
      }
      expect(state.history.length, BeautyEditorState.maxHistory);
    });

    test('reset returns to defaults and is undoable', () {
      final state = BeautyEditorState(current: b).reset();
      expect(state.isDefault, isTrue);
      expect(state.undo().current, b);
    });
  });
}
