import 'package:flutter/material.dart';

@Deprecated('Use XExceptionHandler (runXApp exceptionHandler:) instead')
typedef GeneralErrorHandle = bool Function(BuildContext context, int code, String msg,
    {Function? tryAgain});
typedef OnFail = bool Function(int code, String message, dynamic result);
typedef FromJsonM<T> = T Function(dynamic json);
typedef JSON = Map<String, dynamic>;
typedef JSONLIST = List<dynamic>;
typedef AdditionalWidget = Widget Function(Widget child);

@Deprecated('Use XExceptionHandler (runXApp exceptionHandler:) instead')
GeneralErrorHandle onFailed = ((BuildContext context, code, msg, {tryAgain}) => true);

typedef OnDoneCallBack<T> = void Function(T item);
