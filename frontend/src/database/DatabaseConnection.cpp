#include "DatabaseConnection.h"
#include "SqlUtils.h"
#include "sqlite-amalgamation/sqlite3.h"

#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QMetaType>
#include <QSqlError>
#include <QSqlQuery>

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
    const QString sqlPath = QCoreApplication::applicationDirPath() + "/backend/sql";
    const bool isNewDb = !QFile::exists(dbPath);

    m_db.setDatabaseName(dbPath);

    // Initialize a new database directly from main.sql using the
    // bundled SQLite amalgamation – no Python interpreter required.
    if (isNewDb) {
        const QString mainSqlPath = sqlPath + "/main.sql";
        QFile sqlFile(mainSqlPath);
        if (!sqlFile.exists()) {
            qWarning() << "main.sql not found:" << mainSqlPath;
            return false;
        }
        if (!sqlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qWarning() << "Cannot open main.sql:" << mainSqlPath;
            return false;
        }
        const QByteArray sqlContent = sqlFile.readAll();
        sqlFile.close();

        sqlite3 *rawDb = nullptr;
        const QByteArray dbPathUtf8 = dbPath.toUtf8();
        int rc = sqlite3_open(dbPathUtf8.constData(), &rawDb);
        if (rc != SQLITE_OK) {
            qWarning() << "sqlite3_open failed:" << sqlite3_errmsg(rawDb);
            sqlite3_close(rawDb);
            return false;
        }

        char *errMsg = nullptr;
        rc = sqlite3_exec(rawDb, sqlContent.constData(), nullptr, nullptr, &errMsg);
        sqlite3_close(rawDb);

        if (rc != SQLITE_OK) {
            qWarning() << "sqlite3_exec failed on main.sql:" << errMsg;
            sqlite3_free(errMsg);
            QFile::remove(dbPath);
            return false;
        }

        qDebug() << "[init_db] Database initialized from:" << mainSqlPath;
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

    if (!isNewDb) {
        if (!ensureDevicesYangcfgColumn())
            return false;
        if (!ensureYangcfgTable())
            return false;
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

    // isNewDb: schema already applied above via amalgamation.
    return true;
}

QSqlDatabase DatabaseConnection::database() const
{
    return m_db;
}
