#include "DatabaseConnection.h"
#include "SqlUtils.h"

#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QProcess>
#include <QMetaType>
#include <QStandardPaths>
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
    const QString sqlPath = QCoreApplication::applicationDirPath() + "/backend/data.sql";
    const bool isNewDb = !QFile::exists(dbPath);

    m_db.setDatabaseName(dbPath);

    // Try to initialize DB via external Python script when creating a new DB.
    bool skipManualInit = false;
    if (isNewDb) {
        QString scriptPath;
        const QStringList candidates = {
            QCoreApplication::applicationDirPath() + "/backend/controllers/database/init_db.py",
            QCoreApplication::applicationDirPath() + "/../backend/controllers/database/init_db.py",
            QCoreApplication::applicationDirPath() + "/../../backend/controllers/database/init_db.py"
        };
        for (const QString &c : candidates) {
            if (QFile::exists(c)) { scriptPath = c; break; }
        }

        if (!scriptPath.isEmpty()) {
            qDebug() << "Found init script:" << scriptPath;
            struct InterpreterCandidate {
                QString program;
                QStringList preArgs;
            };

            const QString appDir = QCoreApplication::applicationDirPath();
            const QStringList venvCandidates = {
                // Windows venv path (kept for cross-platform builds)
                appDir + "/.venv/Scripts/python.exe",
                appDir + "/../.venv/Scripts/python.exe",
                appDir + "/../../.venv/Scripts/python.exe",
                // Unix/Linux venv path
                appDir + "/.venv/bin/python",
                appDir + "/../.venv/bin/python",
                appDir + "/../../.venv/bin/python"
            };

            QList<InterpreterCandidate> interpreters;

            for (const QString &venvPython : venvCandidates) {
                if (QFile::exists(venvPython)) {
                    interpreters.append(InterpreterCandidate{venvPython, QStringList{}});
                }
            }

            // Prefer explicit Python 3 interpreter when available.
            const QString python3Path = QStandardPaths::findExecutable("python3");
            if (!python3Path.isEmpty()) {
                interpreters.append(InterpreterCandidate{python3Path, QStringList{}});
            }

            const QString pythonPath = QStandardPaths::findExecutable("python");
            if (!pythonPath.isEmpty()) {
                interpreters.append(InterpreterCandidate{pythonPath, QStringList{}});
            }

            const QString pyLauncherPath = QStandardPaths::findExecutable("py");
            if (!pyLauncherPath.isEmpty()) {
                interpreters.append(InterpreterCandidate{pyLauncherPath, QStringList{QStringLiteral("-3")}});
            }

            // Last-resort aliases (may fail on machines with Store alias only).
            interpreters.append(InterpreterCandidate{QStringLiteral("python"), QStringList{}});
            interpreters.append(InterpreterCandidate{QStringLiteral("python3"), QStringList{}});
            interpreters.append(InterpreterCandidate{QStringLiteral("py"), QStringList{QStringLiteral("-3")}});

            bool scriptSucceeded = false;
            QStringList launchErrors;

            for (const InterpreterCandidate &candidate : interpreters) {
                QProcess proc;
                QStringList args = candidate.preArgs;
                args << scriptPath << "--sql" << sqlPath << "--db" << dbPath;

                proc.start(candidate.program, args);
                if (!proc.waitForStarted(5000)) {
                    launchErrors << (candidate.program + " (start failed)");
                    continue;
                }

                if (!proc.waitForFinished(60000)) {
                    launchErrors << (candidate.program + " (timeout)");
                    proc.kill();
                    continue;
                }

                const QByteArray stderrOut = proc.readAllStandardError();
                const QByteArray stdoutOut = proc.readAllStandardOutput();

                if (proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0) {
                    qDebug() << "init_db.py executed via" << candidate.program;
                    qDebug() << "init_db.py output:" << stdoutOut.trimmed();
                    scriptSucceeded = true;
                    break;
                }

                const QString errSummary = QStringLiteral("%1 (exit=%2) stderr=%3")
                                               .arg(candidate.program)
                                               .arg(proc.exitCode())
                                               .arg(QString::fromUtf8(stderrOut).trimmed());
                launchErrors << errSummary;
            }

            if (!scriptSucceeded) {
                qWarning() << "init_db.py failed with all interpreter candidates";
                qWarning() << "Tried:" << launchErrors;
                return false;
            }

            skipManualInit = true;
        } else {
            qWarning() << "init_db.py not found in expected backend/controllers/database locations";
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

        qDebug() << "Database already exists, skipping data.sql";
        return true;
    }

    if (isNewDb && skipManualInit) {
        qDebug() << "New DB initialized by init_db.py";
        return true;
    }

    if (isNewDb && !skipManualInit) {
        qWarning() << "No init_db.py found or initialization skipped; aborting.";
        return false;
    }

    // Existing databases reach here only when not new.
    return true;
}

QSqlDatabase DatabaseConnection::database() const
{
    return m_db;
}
