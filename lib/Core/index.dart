library core;

export 'x_base_controller.dart' show BaseXController;
export 'x_base_widget.dart' show BaseXWidget;
export 'x_constant.dart' show BaseXConstant, DefaultBaseConstant, Environment, Flavor, Position;
export 'x_declaration.dart'
    show
        GeneralErrorHandle,
        GeneralErrorHandleConfig,
        OnFailed,
        OnFail,
        OnGenericCallBack,
        FromJsonM,
        JSON,
        JSONLIST,
        AddtionalWidget,
        onFailed;
export 'x_extension.dart'
    show
        TextUtilsStringExtension,
        GeneralUtilsObjectExtension,
        Unique,
        DateTimeExtension,
        HexColorOnNull;
export 'x_get_app.dart' show runXApp, baseConstant, defaultService, defaultLangController;
export 'x_service_provider.dart' show ServiceProvider, ProviderConfig;
export 'x_env.dart' show XEnv, XEnvironment, flavorFromEnv;
export 'x_navigation.dart'
    show
        onGetPage,
        cGetPageInitial,
        cGetPage,
        loadPage,
        loadPageWithRemovePrevious,
        loadPageWithRemoveAllPrevious,
        backTo,
        getController;
export 'x_logger.dart' show XLogger;
export 'x_share_pref.dart' show BaseXSharePref, X;
