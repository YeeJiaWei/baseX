library core;

export 'base/x_base_controller.dart' show BaseXController;
export 'base/x_base_widget.dart' show BaseXWidget;
export 'app/x_constant.dart' show BaseXConstant, DefaultBaseConstant, Environment, Flavor, Position;
export 'app/x_declaration.dart'
    show
        GeneralErrorHandle,
        OnFail,
        FromJsonM,
        JSON,
        JSONLIST,
        AdditionalWidget,
        onFailed;
export 'extension/x_extension.dart'
    show
        TextUtilsStringExtension,
        GeneralUtilsObjectExtension,
        Unique,
        DateTimeExtension,
        HexColorOnNull;
export 'app/x_get_app.dart' show runXApp, baseConstant, defaultLangController;
export 'app/x_service_provider.dart' show ServiceProvider, ProviderConfig, ApiXServiceProvider;
export 'app/x_env.dart' show XEnv, XEnvironment, flavorFromEnv;
export 'navigation/x_navigation.dart'
    show
        onGetPage,
        cGetPageInitial,
        cGetPage,
        loadPage,
        loadPageWithRemovePrevious,
        loadPageWithRemoveAllPrevious,
        backTo,
        getController;
export 'logger/x_logger.dart' show XLogger;
export 'storage/x_share_pref.dart' show BaseXSharePref, X;
