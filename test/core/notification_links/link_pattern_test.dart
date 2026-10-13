import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/notification_links/link_match.dart';
import 'package:baseX/Core/notification_links/link_param.dart';
import 'package:baseX/Core/notification_links/link_pattern.dart';

LinkPattern pattern(String source) => LinkPattern.parse(source);

List<String> path(String text) =>
    text.split('/').where((part) => part.isNotEmpty).toList();

void main() {
  group('parsing', () {
    test('literal segments match exact text only', () {
      expect(
          pattern('orders/history').match(path('orders/history')), isNotNull);
      expect(pattern('orders/history').match(path('orders/History')), isNull);
      expect(pattern('orders/history').match(path('orders')), isNull);
      expect(pattern('orders/history').match(path('orders/history/x')), isNull);
    });

    test('plain param captures one segment', () {
      final matched =
          pattern('payments/{reference}').match(path('payments/REF-1'));
      expect(matched!.params, {'reference': 'REF-1'});
      expect(pattern('payments/{reference}').match(path('payments')), isNull);
    });

    test('int param falls through on non-numbers', () {
      expect(pattern('orders/{id:int}').match(path('orders/42'))!.params,
          {'id': '42'});
      expect(pattern('orders/{id:int}').match(path('orders/abc')), isNull);
    });

    test('enum param accepts only listed values', () {
      final kind = pattern('{kind:invoices|receipts}/{reference}');
      expect(kind.match(path('receipts/R1'))!.params,
          {'kind': 'receipts', 'reference': 'R1'});
      expect(kind.match(path('orders/R1')), isNull);
    });

    test('optional last segment may be absent', () {
      final settings = pattern('settings/{section?}');
      expect(settings.match(path('settings'))!.params, isEmpty);
      expect(settings.match(path('settings/privacy'))!.params,
          {'section': 'privacy'});
      expect(settings.match(path('settings/a/b')), isNull);
    });

    test('star matches exactly one segment', () {
      expect(pattern('files/*').match(path('files/a')), isNotNull);
      expect(pattern('files/*').match(path('files')), isNull);
      expect(pattern('files/*').match(path('files/a/b')), isNull);
    });

    test('double star matches zero or more trailing segments', () {
      final help = pattern('help/**');
      expect(help.match(path('help'))!.rest, isEmpty);
      expect(help.match(path('help/faq'))!.rest, ['faq']);
      expect(help.match(path('help/faq/123'))!.rest, ['faq', '123']);
      expect(help.match(path('other')), isNull);
    });

    test('root pattern matches an empty path', () {
      expect(pattern('/').match(const []), isNotNull);
      expect(pattern('/').match(path('orders')), isNull);
    });

    test('invalid patterns throw', () {
      expect(() => pattern('help/**/more'), throwsFormatException);
      expect(() => pattern('{a?}/b'), throwsFormatException);
      expect(() => pattern('{a}/{a}'), throwsFormatException);
      expect(() => pattern('{}'), throwsFormatException);
      expect(() => pattern('{a:}'), throwsFormatException);
      expect(() => pattern('{a:int?}'), throwsFormatException);
      expect(() => pattern('a{b}'), throwsFormatException);
    });
  });

  group('precedence', () {
    test(
        'literal beats constrained beats plain beats optional beats star beats double star',
        () {
      final ranked = [
        pattern('x/**'),
        pattern('x/*'),
        pattern('x/{a?}'),
        pattern('x/{a}'),
        pattern('x/{a:int}'),
        pattern('x/one'),
      ]..sort((first, second) => first.compareSpecificity(second));

      expect(ranked.map((pattern) => pattern.source), [
        'x/one',
        'x/{a:int}',
        'x/{a}',
        'x/{a?}',
        'x/*',
        'x/**',
      ]);
    });

    test('first differing segment decides', () {
      expect(
          pattern('orders/{id}/edit')
                  .compareSpecificity(pattern('orders/{id:int}/{x}')) >
              0,
          isTrue);
    });

    test('a shorter exact pattern beats a trailing optional or double star',
        () {
      expect(
          pattern('settings').compareSpecificity(pattern('settings/{s?}')) < 0,
          isTrue);
      expect(
          pattern('help').compareSpecificity(pattern('help/**')) < 0, isTrue);
    });

    test('same ranks on overlapping segments conflict', () {
      expect(pattern('{id:int}').conflictsWith(pattern('{n:int}')), isTrue);
      expect(pattern('{a}/x').conflictsWith(pattern('{b}/x')), isTrue);
      expect(pattern('{id:int}').conflictsWith(pattern('{kind:a|b}')), isFalse);
      expect(pattern('{id:int}').conflictsWith(pattern('{kind:1|b}')), isTrue);
    });

    test('different literals never conflict', () {
      expect(pattern('orders').conflictsWith(pattern('chat')), isFalse);
    });
  });

  group('LinkMatch.fromUri', () {
    test('exposes params, rest and query', () {
      final link = LinkMatch.fromUri(
        Uri.parse('shop://orders/42/a/b?tab=2'),
        pattern: 'orders/{id:int}/**',
      );

      expect(link.int('id'), 42);
      expect(link.param('id'), '42');
      expect(link.rest, ['a', 'b']);
      expect(link.query, {'tab': '2'});
    });

    test('throws when the uri does not match', () {
      expect(
        () => LinkMatch.fromUri(Uri.parse('shop://chat'), pattern: 'orders'),
        throwsArgumentError,
      );
    });

    test('int throws for a non-int param', () {
      final link =
          LinkMatch.fromUri(Uri.parse('shop://pay/REF'), pattern: 'pay/{ref}');
      expect(() => link.int('ref'), throwsStateError);
    });
  });

  group('pathSegmentsOf', () {
    test('host comes first and trailing slash is ignored', () {
      expect(LinkPattern.pathSegmentsOf(Uri.parse('shop://orders/42/')),
          ['orders', '42']);
      expect(LinkPattern.pathSegmentsOf(Uri.parse('shop://')), isEmpty);
    });
  });

  group('LinkParam', () {
    test('int accepts ints and numeric strings', () {
      expect(LinkParam.int.accepts(1042), isTrue);
      expect(LinkParam.int.accepts('1042'), isTrue);
      expect(LinkParam.int.accepts('x'), isFalse);
      expect(LinkParam.int.accepts(null), isFalse);
    });

    test('string rejects null and empty', () {
      expect(LinkParam.string.accepts('a'), isTrue);
      expect(LinkParam.string.accepts(''), isFalse);
      expect(LinkParam.string.accepts(null), isFalse);
    });
  });
}
