#include "DatabaseConnection.h"
#include "SqlUtils.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaType>
#include <QProcess>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStringList>

namespace {

QString pythonProgram(QStringList *prefixArgs)
{
#ifdef Q_OS_WIN
    if (!QStandardPaths::findExecutable("py").isEmpty()) {
        if (prefixArgs)
            *prefixArgs << "-3";
        return QStringLiteral("py");
    }
#endif

    const QStringList candidates =
#ifdef Q_OS_WIN
        {QStringLiteral("python")};
#else
        {QStringLiteral("python3"), QStringLiteral("python")};
#endif

    for (const QString &candidate : candidates) {
        if (!QStandardPaths::findExecutable(candidate).isEmpty())
            return candidate;
    }

    return QString();
}

bool runPythonKernelDbInit(const QString &dbPath)
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString kernelDir = QDir(appDir).filePath(QStringLiteral("python_app_kenel"));
    const QString mainPyPath = QDir(kernelDir).filePath(QStringLiteral("main.py"));
    const QString mainSqlPath = QDir(kernelDir).filePath(QStringLiteral("sql/main.sql"));

    if (!QFileInfo::exists(mainPyPath)) {
        qWarning() << "Python app kernel main.py not found:" << mainPyPath;
        return false;
    }

    if (!QFileInfo::exists(mainSqlPath)) {
        qWarning() << "Python app kernel main.sql not found:" << mainSqlPath;
        return false;
    }

    QStringList args;
    const QString program = pythonProgram(&args);
    if (program.isEmpty()) {
        qWarning() << "Python was not found in PATH; cannot initialize database from main.sql";
        return false;
    }

    args << mainPyPath
         << QStringLiteral("--init-db")
         << QStringLiteral("--sql") << mainSqlPath
         << QStringLiteral("--db") << dbPath;

    QProcess proc;
    proc.setWorkingDirectory(kernelDir);
    proc.start(program, args);
    if (!proc.waitForStarted(5000)) {
        qWarning() << "Failed to start Python database initializer:" << program;
        return false;
    }

    if (!proc.waitForFinished(120000)) {
        proc.kill();
        proc.waitForFinished(2000);
        qWarning() << "Python database initializer timed out";
        return false;
    }

    const QString stdOut = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    const QString stdErr = QString::fromUtf8(proc.readAllStandardError()).trimmed();
    if (!stdOut.isEmpty())
        qDebug() << "[init_db]" << stdOut;

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        qWarning() << "Python database initializer failed:" << stdErr;
        return false;
    }

    return true;
}

}

DatabaseConnection::DatabaseConnection()
    : m_connectionName("device_network_connection")
{
    if (QSqlDatabase::contains(m_connectionName)) {
        m_db = QSqlDatabase::database(m_connectionName);
    } else {
        m_db = QSqlDatabase::addDatabase("QSQLITE", m_connectionName);
    }
}

bool DatabaseConnection::initializeDatabase()
{
    const QString dbPath = QCoreApplication::applicationDirPath() + "/device_network.db";
    const bool isNewDb = !QFile::exists(dbPath);

    m_db.setDatabaseName(dbPath);

    // The SQL-to-DB bootstrap is delegated to the Python app kernel.
    // Runtime database access still goes through Qt's QSQLITE driver.
    if (isNewDb) {
        if (!runPythonKernelDbInit(dbPath)) {
            QFile::remove(dbPath);
            return false;
        }
    }

    if (!m_db.open()) {
        qWarning() << "Cannot open database:" << m_db.lastError().text();
        return false;
    }

    QSqlQuery pragma(m_db);
    if (!pragma.exec("PRAGMA foreign_keys = ON;")) {
        qWarning() << "Failed to enable foreign_keys:" << pragma.lastError().text();
        return false;
    }

    // Keep schema compatible for existing databases when new columns are introduced.
    auto ensureDevicesYangcfgColumn = [this]() -> bool {
        QSqlQuery infoQuery(m_db);
        if (!infoQuery.exec("PRAGMA table_info(devices);")) {
            qWarning() << "Failed to inspect devices schema:" << infoQuery.lastError().text();
            return false;
        }

        bool hasYangcfg = false;
        while (infoQuery.next()) {
            if (infoQuery.value("name").toString() == "yangcfg") {
                hasYangcfg = true;
                break;
            }
        }

        if (hasYangcfg)
            return true;

        QSqlQuery alterQuery(m_db);
        if (!alterQuery.exec("ALTER TABLE devices ADD COLUMN yangcfg INTEGER DEFAULT 0;")) {
            qWarning() << "Failed to add devices.yangcfg column:" << alterQuery.lastError().text();
            return false;
        }

        return true;
    };

    auto ensureYangcfgTable = [this]() -> bool {
        QSqlQuery createQuery(m_db);
        if (!createQuery.exec(
                "CREATE TABLE IF NOT EXISTS yangcfg ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "host TEXT NOT NULL, "
                "username TEXT, "
                "password TEXT, "
                "success INTEGER DEFAULT 0, "
                "FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE ON DELETE CASCADE"
                ");"
            )) {
            qWarning() << "Failed to ensure yangcfg table:" << createQuery.lastError().text();
            return false;
        }

        return true;
    };

    auto ensureColumn = [this](const QString &tableName,
                               const QString &columnName,
                               const QString &alterSql) -> bool {
        QSqlQuery infoQuery(m_db);
        if (!infoQuery.exec(QStringLiteral("PRAGMA table_info(%1);").arg(tableName))) {
            qWarning() << "Failed to inspect" << tableName << "schema:" << infoQuery.lastError().text();
            return false;
        }

        bool hasColumn = false;
        while (infoQuery.next()) {
            if (infoQuery.value("name").toString() == columnName) {
                hasColumn = true;
                break;
            }
        }

        if (hasColumn)
            return true;

        QSqlQuery alterQuery(m_db);
        if (!alterQuery.exec(alterSql)) {
            qWarning() << "Failed to add" << tableName + "." + columnName << ":" << alterQuery.lastError().text();
            return false;
        }

        return true;
    };

    auto ensureRouteMapTables = [this]() -> bool {
        QSqlQuery routeMapQuery(m_db);
        if (!routeMapQuery.exec(
                "CREATE TABLE IF NOT EXISTS route_map_db ("
                "route_map_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "route_map_name TEXT NOT NULL, "
                "host TEXT NOT NULL, "
                "description TEXT, "
                "success INTEGER DEFAULT 0, "
                "UNIQUE (host, route_map_name), "
                "FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE"
                ");"
            )) {
            qWarning() << "Failed to ensure route_map_db table:" << routeMapQuery.lastError().text();
            return false;
        }

        QSqlQuery entryQuery(m_db);
        if (!entryQuery.exec(
                "CREATE TABLE IF NOT EXISTS route_map_entries ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "route_map_id INTEGER NOT NULL, "
                "sequence INTEGER NOT NULL, "
                "action TEXT NOT NULL CHECK(action IN ('permit','deny')), "
                "nat_acl_id INTEGER, "
                "success INTEGER DEFAULT 0, "
                "UNIQUE (route_map_id, sequence), "
                "FOREIGN KEY (route_map_id) REFERENCES route_map_db(route_map_id) ON DELETE CASCADE, "
                "FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id)"
                ");"
            )) {
            qWarning() << "Failed to ensure route_map_entries table:" << entryQuery.lastError().text();
            return false;
        }

        return true;
    };

    auto ensureDhcpHelperTable = [this]() -> bool {
        QSqlQuery helperQuery(m_db);
        if (!helperQuery.exec(
                "CREATE TABLE IF NOT EXISTS router_iface_helper ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "iface_id INTEGER NOT NULL, "
                "helper_ip TEXT NOT NULL, "
                "success INTEGER DEFAULT 0 CHECK(success IN (-1,0,1)), "
                "UNIQUE(iface_id, helper_ip), "
                "FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id) ON UPDATE CASCADE ON DELETE CASCADE"
                ");"
            )) {
            qWarning() << "Failed to ensure router_iface_helper table:" << helperQuery.lastError().text();
            return false;
        }

        return true;
    };

    auto ensureDhcpTables = [this]() -> bool {
        QSqlQuery poolQuery(m_db);
        if (!poolQuery.exec(
                "CREATE TABLE IF NOT EXISTS dhcp_pool ("
                "dhcp_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "host TEXT NOT NULL, "
                "pool TEXT NOT NULL, "
                "network TEXT NOT NULL, "
                "subnetmask TEXT NOT NULL, "
                "defaut TEXT, "
                "dns TEXT, "
                "lease TEXT DEFAULT '1', "
                "success INTEGER DEFAULT 0, "
                "action_Cfg TEXT DEFAULT '111', "
                "FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE ON DELETE CASCADE"
                ");"
            )) {
            qWarning() << "Failed to ensure dhcp_pool table:" << poolQuery.lastError().text();
            return false;
        }

        QSqlQuery excludedQuery(m_db);
        if (!excludedQuery.exec(
                "CREATE TABLE IF NOT EXISTS excluded_address ("
                "ex_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "host TEXT NOT NULL, "
                "start_ip TEXT NOT NULL, "
                "end_ip TEXT NOT NULL, "
                "success INTEGER DEFAULT 0, "
                "FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE ON DELETE CASCADE"
                ");"
            )) {
            qWarning() << "Failed to ensure excluded_address table:" << excludedQuery.lastError().text();
            return false;
        }

        return true;
    };

    if (!ensureRouteMapTables())
        return false;
    if (!ensureDhcpTables())
        return false;
    if (!ensureDhcpHelperTable())
        return false;

    if (!isNewDb) {
        if (!ensureDevicesYangcfgColumn())
            return false;
        if (!ensureYangcfgTable())
            return false;
        if (!ensureColumn("dhcp_pool",
                          "lease",
                          "ALTER TABLE dhcp_pool ADD COLUMN lease TEXT DEFAULT '1';")) {
            return false;
        }
        if (!ensureColumn("dhcp_pool",
                          "success",
                          "ALTER TABLE dhcp_pool ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("dhcp_pool",
                          "action_Cfg",
                          "ALTER TABLE dhcp_pool ADD COLUMN action_Cfg TEXT DEFAULT '111';")) {
            return false;
        }
        if (!ensureColumn("excluded_address",
                          "success",
                          "ALTER TABLE excluded_address ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("static_default_routes",
                          "success",
                          "ALTER TABLE static_default_routes ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("static_routes",
                          "success",
                          "ALTER TABLE static_routes ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("ospf_processes",
                          "success",
                          "ALTER TABLE ospf_processes ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("ospf_processes",
                          "action",
                          "ALTER TABLE ospf_processes ADD COLUMN action INTEGER DEFAULT 3;")) {
            return false;
        }
        if (!ensureColumn("ospf_networks",
                          "success",
                          "ALTER TABLE ospf_networks ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("eigrp_processes",
                          "success",
                          "ALTER TABLE eigrp_processes ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("eigrp_processes",
                          "action",
                          "ALTER TABLE eigrp_processes ADD COLUMN action INTEGER DEFAULT 3;")) {
            return false;
        }
        if (!ensureColumn("eigrp_processes",
                          "metric_weights",
                          "ALTER TABLE eigrp_processes ADD COLUMN metric_weights TEXT DEFAULT '0 1 0 1 0 0';")) {
            return false;
        }
        if (!ensureColumn("eigrp_processes",
                          "passive_default",
                          "ALTER TABLE eigrp_processes ADD COLUMN passive_default INTEGER DEFAULT 0;")) {
            return false;
        }
        if (!ensureColumn("eigrp_networks",
                          "success",
                          "ALTER TABLE eigrp_networks ADD COLUMN success INTEGER DEFAULT 0;")) {
            return false;
        }

        qDebug() << "Database already exists, skipping SQL initialization";
        return true;
    }

    return true;
}

QSqlDatabase DatabaseConnection::database() const
{
    return m_db;
}
