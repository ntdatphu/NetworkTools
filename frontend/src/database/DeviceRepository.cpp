#include "DeviceRepository.h"
#include "SqlUtils.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

DeviceRepository::DeviceRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

bool DeviceRepository::addDevice(const QString &host,
                                 const QString &deviceName,
                                 const QString &method,
                                 const QString &portText,
                                 const QString &username,
                                 const QString &password)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open";
        return false;
    }

    if (host.trimmed().isEmpty()) {
        qWarning() << "Host cannot be empty";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO devices "
        "(host, device_name, method, portnumber, username, password) "
        "VALUES (?, ?, ?, ?, ?, ?);"
    );

    query.addBindValue(host.trimmed());
    SqlUtils::bindNullableString(query, deviceName);
    SqlUtils::bindNullableString(query, method);
    SqlUtils::bindNullableIntFromString(query, portText);
    SqlUtils::bindNullableString(query, username);
    SqlUtils::bindNullableString(query, password);

    if (!query.exec()) {
        qWarning() << "Insert device failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DeviceRepository::deleteDevice(const QString &host)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in deleteDevice";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM devices WHERE host = ?;");
    query.addBindValue(host.trimmed());

    if (!query.exec()) {
        qWarning() << "Delete device failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DeviceRepository::updateDeviceSuccess(const QString &host, int success)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in updateDeviceSuccess";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("UPDATE devices SET success = ? WHERE host = ?;");
    query.addBindValue(success);
    query.addBindValue(host.trimmed());

    if (!query.exec()) {
        qWarning() << "Update success failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DeviceRepository::addYangcfg(const QString &host,
                                  const QString &username,
                                  const QString &password,
                                  int success)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in addYangcfg";
        return false;
    }

    if (host.trimmed().isEmpty()) {
        qWarning() << "Host cannot be empty in addYangcfg";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO yangcfg (host, username, password, success) "
        "VALUES (?, ?, ?, ?);"
    );
    query.addBindValue(host.trimmed());
    SqlUtils::bindNullableString(query, username);
    SqlUtils::bindNullableString(query, password);
    query.addBindValue(success);

    if (!query.exec()) {
        qWarning() << "Insert yangcfg failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DeviceRepository::updateDevice(const QString &host,
                                    const QString &deviceName,
                                    const QString &method,
                                    const QString &portText,
                                    const QString &username,
                                    const QString &password)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in updateDevice";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE devices SET "
        "device_name = ?, method = ?, portnumber = ?, username = ?, password = ? "
        "WHERE host = ?;"
    );

    SqlUtils::bindNullableString(query, deviceName);
    SqlUtils::bindNullableString(query, method);
    SqlUtils::bindNullableIntFromString(query, portText);
    SqlUtils::bindNullableString(query, username);
    SqlUtils::bindNullableString(query, password);
    query.addBindValue(host.trimmed());

    if (!query.exec()) {
        qWarning() << "Update device failed:" << query.lastError().text();
        return false;
    }

    return true;
}

QVariantMap DeviceRepository::getDeviceByHost(const QString &host)
{
    QVariantMap result;

    if (!m_db.isOpen()) {
        qWarning() << "Database not open in getDeviceByHost";
        return result;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "SELECT host, device_name, method, portnumber, username, password "
        "FROM devices WHERE host = ?;"
    );
    query.addBindValue(host.trimmed());

    if (!query.exec() || !query.next()) {
        qWarning() << "getDeviceByHost failed for host:" << host;
        return result;
    }

    result["ip"] = query.value("host").toString();
    result["name"] = query.value("device_name").toString();
    result["protocol"] = query.value("method").toString();
    result["port"] = query.value("portnumber").toString();
    result["user"] = query.value("username").toString();
    result["pass"] = query.value("password").toString();

    return result;
}

QVariantList DeviceRepository::getDevices()
{
    QVariantList list;

    if (!m_db.isOpen()) {
        qWarning() << "Database not open in getDevices";
        return list;
    }

    QSqlQuery q(m_db);
    if (!q.exec("SELECT host, device_name, success FROM devices")) {
        qWarning() << "Select devices failed:" << q.lastError().text();
        return list;
    }

    while (q.next()) {
        int success = q.value("success").toInt();
        if (success == 3)
            continue;

        QString host = q.value("host").toString();
        QString deviceName = q.value("device_name").toString();

        QVariantMap dev;
        dev["name"] = deviceName.trimmed().isEmpty() ? host : deviceName;
        dev["ip"] = host;

        if (success == 1)
            dev["status"] = "connected";
        else if (success == 0)
            dev["status"] = "waiting";
        else if (success == -1)
            dev["status"] = "disconnected";
        else
            continue;

        dev["type"] = "Device";
        list.append(dev);
    }

    return list;
}

QStringList DeviceRepository::getActiveHosts()
{
    QStringList hosts;

    if (!m_db.isOpen()) {
        qWarning() << "Database not open in getActiveHosts";
        return hosts;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "SELECT host FROM devices "
        "WHERE success != 3 "
        "AND host IS NOT NULL "
        "AND TRIM(host) != ''"
    );

    if (!query.exec()) {
        qWarning() << "Select hosts failed:" << query.lastError().text();
        return hosts;
    }

    while (query.next()) {
        QString host = query.value(0).toString().trimmed();
        if (!host.isEmpty())
            hosts.append(host);
    }

    return hosts;
}
