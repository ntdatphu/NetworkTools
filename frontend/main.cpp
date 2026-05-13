#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>

#include "src/database/DatabaseManager.h"
#include "src/TerminalHelper.h"
#include "src/NetworkMonitor.h"


int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setOrganizationName("3TM");
    app.setOrganizationDomain("ptit.edu.vn");
    app.setApplicationName("NetworkTools");

    // ── App Icon ─────────────────────────────────────────────────────────────
    QIcon appIcon;
    appIcon.addFile(":/qt/qml/NetworkTools/resources/icons/logo.png"); // Fallback cho Linux
    appIcon.addFile(":/qt/qml/NetworkTools/resources/icons/logo.svg"); // Ưu tiên cho chất lượng Vector
    app.setWindowIcon(appIcon);
    // QGuiApplication::setDesktopFileName("networktools");

    DatabaseManager dbManager;
    dbManager.initializeDatabase();

    QQmlApplicationEngine engine;
    TerminalHelper cli;
    NetworkMonitor networkMonitor;

    engine.rootContext()->setContextProperty("dbManager", &dbManager);
    engine.rootContext()->setContextProperty("cli", &cli);
    engine.rootContext()->setContextProperty("networkMonitor", &networkMonitor);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("NetworkTools", "Main");

    return app.exec();
}