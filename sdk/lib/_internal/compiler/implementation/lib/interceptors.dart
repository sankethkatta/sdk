// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library _interceptors;

import 'dart:collection';

part 'js_array.dart';
part 'js_string.dart';

/**
 * The interceptor class for all non-primitive objects. All its
 * members are synthethized by the compiler's emitter.
 */
class ObjectInterceptor {
  const ObjectInterceptor();
}

/**
 * Get the interceptor for [object]. Called by the compiler when it needs
 * to emit a call to an intercepted method, that is a method that is
 * defined in an interceptor class.
 */
getInterceptor(object) {
  if (object is String) return const JSString();
  if (isJsArray(object)) return const JSArray();
  return const ObjectInterceptor();
}

get$length(var receiver) {
  if (receiver is String || isJsArray(receiver)) {
    return JS('num', r'#.length', receiver);  // TODO(sra): Use 'int'?
  } else {
    return UNINTERCEPTED(receiver.length);
  }
}

set$length(receiver, newLength) {
  if (isJsArray(receiver)) {
    checkNull(newLength); // TODO(ahe): This is not specified but co19 tests it.
    if (newLength is !int) throw new ArgumentError(newLength);
    if (newLength < 0) throw new RangeError.value(newLength);
    checkGrowable(receiver, 'set length');
    JS('void', r'#.length = #', receiver, newLength);
  } else {
    UNINTERCEPTED(receiver.length = newLength);
  }
  return newLength;
}

toString(var value) {
  if (JS('bool', r'typeof # == "object" && # != null', value, value)) {
    if (isJsArray(value)) {
      return Collections.collectionToString(value);
    } else {
      return UNINTERCEPTED(value.toString());
    }
  }
  if (JS('bool', r'# === 0 && (1 / #) < 0', value, value)) {
    return '-0.0';
  }
  if (value == null) return 'null';
  if (JS('bool', r'typeof # == "function"', value)) {
    return 'Closure';
  }
  return JS('String', r'String(#)', value);
}

get$isEmpty(receiver) {
  if (receiver is String || isJsArray(receiver)) {
    return JS('bool', r'#.length === 0', receiver);
  }
  return UNINTERCEPTED(receiver.isEmpty);
}

compareTo(a, b) {
  if (checkNumbers(a, b)) {
    if (a < b) {
      return -1;
    } else if (a > b) {
      return 1;
    } else if (a == b) {
      if (a == 0) {
        bool aIsNegative = a.isNegative;
        bool bIsNegative = b.isNegative;
        if (aIsNegative == bIsNegative) return 0;
        if (aIsNegative) return -1;
        return 1;
      }
      return 0;
    } else if (a.isNaN) {
      if (b.isNaN) {
        return 0;
      }
      return 1;
    } else {
      return -1;
    }
  } else if (a is String) {
    if (b is !String) throw new ArgumentError(b);
    return JS('bool', r'# == #', a, b) ? 0
      : JS('bool', r'# < #', a, b) ? -1 : 1;
  } else {
    return UNINTERCEPTED(a.compareTo(b));
  }
}

iterator(receiver) {
  if (isJsArray(receiver)) {
    return new ListIterator(receiver);
  }
  return UNINTERCEPTED(receiver.iterator());
}

indexOf$1(receiver, element) {
  if (isJsArray(receiver)) {
    var length = JS('num', r'#.length', receiver);
    return Arrays.indexOf(receiver, element, 0, length);
  } else if (receiver is String) {
    checkNull(element);
    if (element is !String) throw new ArgumentError(element);
    return JS('int', r'#.indexOf(#)', receiver, element);
  }
  return UNINTERCEPTED(receiver.indexOf(element));
}

indexOf$2(receiver, element, start) {
  if (isJsArray(receiver)) {
    if (start is !int) throw new ArgumentError(start);
    var length = JS('num', r'#.length', receiver);
    return Arrays.indexOf(receiver, element, start, length);
  } else if (receiver is String) {
    checkNull(element);
    if (start is !int) throw new ArgumentError(start);
    if (element is !String) throw new ArgumentError(element);
    if (start < 0) return -1; // TODO(ahe): Is this correct?
    return JS('int', r'#.indexOf(#, #)', receiver, element, start);
  }
  return UNINTERCEPTED(receiver.indexOf(element, start));
}

insertRange$2(receiver, start, length) {
  if (isJsArray(receiver)) {
    return insertRange$3(receiver, start, length, null);
  }
  return UNINTERCEPTED(receiver.insertRange(start, length));
}

insertRange$3(receiver, start, length, initialValue) {
  if (!isJsArray(receiver)) {
    return UNINTERCEPTED(receiver.insertRange(start, length, initialValue));
  }
  return listInsertRange(receiver, start, length, initialValue);
}

get$last(receiver) {
  if (!isJsArray(receiver)) {
    return UNINTERCEPTED(receiver.last);
  }
  return receiver[receiver.length - 1];
}

lastIndexOf$1(receiver, element) {
  if (isJsArray(receiver)) {
    var start = JS('num', r'#.length', receiver);
    return Arrays.lastIndexOf(receiver, element, start);
  } else if (receiver is String) {
    checkNull(element);
    if (element is !String) throw new ArgumentError(element);
    return JS('int', r'#.lastIndexOf(#)', receiver, element);
  }
  return UNINTERCEPTED(receiver.lastIndexOf(element));
}

lastIndexOf$2(receiver, element, start) {
  if (isJsArray(receiver)) {
    return Arrays.lastIndexOf(receiver, element, start);
  } else if (receiver is String) {
    checkNull(element);
    if (element is !String) throw new ArgumentError(element);
    if (start != null) {
      if (start is !num) throw new ArgumentError(start);
      if (start < 0) return -1;
      if (start >= receiver.length) {
        if (element == "") return receiver.length;
        start = receiver.length - 1;
      }
    }
    return stringLastIndexOfUnchecked(receiver, element, start);
  }
  return UNINTERCEPTED(receiver.lastIndexOf(element, start));
}

removeRange(receiver, start, length) {
  if (!isJsArray(receiver)) {
    return UNINTERCEPTED(receiver.removeRange(start, length));
  }
  checkGrowable(receiver, 'removeRange');
  if (length == 0) {
    return;
  }
  checkNull(start); // TODO(ahe): This is not specified but co19 tests it.
  checkNull(length); // TODO(ahe): This is not specified but co19 tests it.
  if (start is !int) throw new ArgumentError(start);
  if (length is !int) throw new ArgumentError(length);
  if (length < 0) throw new ArgumentError(length);
  var receiverLength = JS('num', r'#.length', receiver);
  if (start < 0 || start >= receiverLength) {
    throw new RangeError.value(start);
  }
  if (start + length > receiverLength) {
    throw new RangeError.value(start + length);
  }
  Arrays.copy(receiver,
              start + length,
              receiver,
              start,
              receiverLength - length - start);
  receiver.length = receiverLength - length;
}

setRange$3(receiver, start, length, from) {
  if (isJsArray(receiver)) {
    return setRange$4(receiver, start, length, from, 0);
  }
  return UNINTERCEPTED(receiver.setRange(start, length, from));
}

setRange$4(receiver, start, length, from, startFrom) {
  if (!isJsArray(receiver)) {
    return UNINTERCEPTED(receiver.setRange(start, length, from, startFrom));
  }

  checkMutable(receiver, 'indexed set');
  if (length == 0) return;
  checkNull(start); // TODO(ahe): This is not specified but co19 tests it.
  checkNull(length); // TODO(ahe): This is not specified but co19 tests it.
  checkNull(from); // TODO(ahe): This is not specified but co19 tests it.
  checkNull(startFrom); // TODO(ahe): This is not specified but co19 tests it.
  if (start is !int) throw new ArgumentError(start);
  if (length is !int) throw new ArgumentError(length);
  if (startFrom is !int) throw new ArgumentError(startFrom);
  if (length < 0) throw new ArgumentError(length);
  if (start < 0) throw new RangeError.value(start);
  if (start + length > receiver.length) {
    throw new RangeError.value(start + length);
  }

  Arrays.copy(from, startFrom, receiver, start, length);
}

some(receiver, f) {
  if (!isJsArray(receiver)) {
    return UNINTERCEPTED(receiver.some(f));
  } else {
    return Collections.some(receiver, f);
  }
}

every(receiver, f) {
  if (!isJsArray(receiver)) {
    return UNINTERCEPTED(receiver.every(f));
  } else {
    return Collections.every(receiver, f);
  }
}

// TODO(ngeoffray): Make it possible to have just one "sort" function ends
// an optional parameter.

sort$0(receiver) {
  if (!isJsArray(receiver)) return UNINTERCEPTED(receiver.sort());
  checkMutable(receiver, 'sort');
  coreSort(receiver, Comparable.compare);
}

sort$1(receiver, compare) {
  if (!isJsArray(receiver)) return UNINTERCEPTED(receiver.sort(compare));
  checkMutable(receiver, 'sort');
  coreSort(receiver, compare);
}

get$isNegative(receiver) {
  if (receiver is num) {
    return (receiver == 0) ? (1 / receiver) < 0 : receiver < 0;
  } else {
    return UNINTERCEPTED(receiver.isNegative);
  }
}

get$isNaN(receiver) {
  if (receiver is num) {
    return JS('bool', r'isNaN(#)', receiver);
  } else {
    return UNINTERCEPTED(receiver.isNaN);
  }
}

remainder(a, b) {
  if (checkNumbers(a, b)) {
    return JS('num', r'# % #', a, b);
  } else {
    return UNINTERCEPTED(a.remainder(b));
  }
}

abs(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.abs());

  return JS('num', r'Math.abs(#)', receiver);
}

toInt(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.toInt());

  if (receiver.isNaN) throw new FormatException('NaN');

  if (receiver.isInfinite) throw new FormatException('Infinity');

  var truncated = receiver.truncate();
  return JS('bool', r'# == -0.0', truncated) ? 0 : truncated;
}

ceil(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.ceil());

  return JS('num', r'Math.ceil(#)', receiver);
}

floor(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.floor());

  return JS('num', r'Math.floor(#)', receiver);
}

get$isInfinite(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.isInfinite);

  return JS('bool', r'# == Infinity', receiver)
    || JS('bool', r'# == -Infinity', receiver);
}

round(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.round());

  if (JS('bool', r'# < 0', receiver)) {
    return JS('num', r'-Math.round(-#)', receiver);
  } else {
    return JS('num', r'Math.round(#)', receiver);
  }
}

toDouble(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.toDouble());

  return receiver;
}

truncate(receiver) {
  if (receiver is !num) return UNINTERCEPTED(receiver.truncate());

  return receiver < 0 ? receiver.ceil() : receiver.floor();
}

toStringAsFixed(receiver, fractionDigits) {
  if (receiver is !num) {
    return UNINTERCEPTED(receiver.toStringAsFixed(fractionDigits));
  }
  checkNum(fractionDigits);

  String result = JS('String', r'#.toFixed(#)', receiver, fractionDigits);
  if (receiver == 0 && receiver.isNegative) return "-$result";
  return result;
}

toStringAsExponential(receiver, fractionDigits) {
  if (receiver is !num) {
    return UNINTERCEPTED(receiver.toStringAsExponential(fractionDigits));
  }
  String result;
  if (fractionDigits != null) {
    checkNum(fractionDigits);
    result = JS('String', r'#.toExponential(#)', receiver, fractionDigits);
  } else {
    result = JS('String', r'#.toExponential()', receiver);
  }
  if (receiver == 0 && receiver.isNegative) return "-$result";
  return result;
}

toStringAsPrecision(receiver, fractionDigits) {
  if (receiver is !num) {
    return UNINTERCEPTED(receiver.toStringAsPrecision(fractionDigits));
  }
  checkNum(fractionDigits);

  String result = JS('String', r'#.toPrecision(#)',
                     receiver, fractionDigits);
  if (receiver == 0 && receiver.isNegative) return "-$result";
  return result;
}

toRadixString(receiver, radix) {
  if (receiver is !num) {
    return UNINTERCEPTED(receiver.toRadixString(radix));
  }
  checkNum(radix);
  if (radix < 2 || radix > 36) throw new ArgumentError(radix);
  return JS('String', r'#.toString(#)', receiver, radix);
}

contains$1(receiver, other) {
  if (receiver is String) {
    return contains$2(receiver, other, 0);
  } else if (isJsArray(receiver)) {
    for (int i = 0; i < receiver.length; i++) {
      if (other == receiver[i]) return true;
    }
    return false;
  }
  return UNINTERCEPTED(receiver.contains(other));
}

contains$2(receiver, other, startIndex) {
  if (receiver is !String) {
    return UNINTERCEPTED(receiver.contains(other, startIndex));
  }
  checkNull(other);
  return stringContainsUnchecked(receiver, other, startIndex);
}

/**
 * This is the [Jenkins hash function][1] but using masking to keep
 * values in SMI range.
 *
 * [1]: http://en.wikipedia.org/wiki/Jenkins_hash_function
 */
get$hashCode(receiver) {
  // TODO(ahe): This method shouldn't have to use JS. Update when our
  // optimizations are smarter.
  if (receiver == null) return 0;
  if (receiver is num) return receiver & 0x1FFFFFFF;
  if (receiver is bool) return receiver ? 0x40377024 : 0xc18c0076;
  if (isJsArray(receiver)) return Primitives.objectHashCode(receiver);
  if (receiver is !String) return UNINTERCEPTED(receiver.hashCode);
  int hash = 0;
  int length = receiver.length;
  for (int i = 0; i < length; i++) {
    hash = 0x1fffffff & (hash + JS('int', r'#.charCodeAt(#)', receiver, i));
    hash = 0x1fffffff & (hash + (0x0007ffff & hash) << 10);
    hash = JS('int', '# ^ (# >> 6)', hash, hash);
  }
  hash = 0x1fffffff & (hash + (0x03ffffff & hash) <<  3);
  hash = JS('int', '# ^ (# >> 11)', hash, hash);
  return 0x1fffffff & (hash + (0x00003fff & hash) << 15);
}

get$isEven(receiver) {
  if (receiver is !int) return UNINTERCEPTED(receiver.isEven);
  return (receiver & 1) == 0;
}

get$isOdd(receiver) {
  if (receiver is !int) return UNINTERCEPTED(receiver.isOdd);
  return (receiver & 1) == 1;
}

get$runtimeType(receiver) {
  if (receiver is int) {
    return createRuntimeType('int');
  } else if (receiver is String) {
    return createRuntimeType('String');
  } else if (receiver is double) {
    return createRuntimeType('double');
  } else if (receiver is bool) {
    return createRuntimeType('bool');
  } else if (receiver == null) {
    return createRuntimeType('Null');
  } else if (isJsArray(receiver)) {
    return createRuntimeType('List');
  } else {
    return UNINTERCEPTED(receiver.runtimeType);
  }
}

// TODO(lrn): These getters should be generated automatically for all
// intercepted methods.
get$toString(receiver) => () => toString(receiver);
