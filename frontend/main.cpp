#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>

#include "src/database/DatabaseManager.h"
#include "src/terminalhelper.h"
#include "src/NetworkMonitor.h"


int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setOrganizationName("3TM");
    app.setOrganizationDomain("ptit.edu.vn");
    app.setApplicationName("NetworkTools");

    app.setWindowIcon(QIcon(":/qt/qml/NetworkUI/resources/icons/logo.svg"));

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
    engine.loadFromModule("NetworkUI", "Main");

    return app.exec();
}