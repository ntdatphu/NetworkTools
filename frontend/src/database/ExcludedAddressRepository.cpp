#include "ExcludedAddressRepository.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

ExcludedAddressRepository::ExcludedAddressRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

bool ExcludedAddressRepository::addExcludedAddress(const QString &host,
                                                   const QString &startIp,
                                                   const QString &endIp)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in addExcludedAddress";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO excluded_address (host, start_ip, end_ip) "
        "VALUES (?, ?, ?);"
    );
    query.addBindValue(host.trimmed());
    query.addBindValue(startIp.trimmed());
    query.addBindValue(endIp.trimmed());

    if (!query.exec()) {
        qWarning() << "addExcludedAddress failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool ExcludedAddressRepository::deleteExcludedAddress(int exId)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in deleteExcludedAddress";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("UPDATE excluded_address SET success = -1 WHERE ex_id = ?;");
    query.addBindValue(exId);

    if (!query.exec()) {
        qWarning() << "deleteExcludedAddress failed:" << query.lastError().text();
        return false;
    }

    return true;
}

QVariantList ExcludedAddressRepository::getExcludedAddresses(const QString &host)
{
    QVariantList list;

    if (!m_db.isOpen()) {
        qWarning() << "Database not open in getExcludedAddresses";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "SELECT ex_id, start_ip, end_ip, success "
        "FROM excluded_address WHERE host = ? AND COALESCE(success, 0) <> -1 ORDER BY ex_id ASC;"
    );
    query.addBindValue(host.trimmed());

    if (!query.exec()) {
        qWarning() << "getExcludedAddresses failed:" << query.lastError().text();
        return list;
    }

    while (query.next()) {
        QVariantMap row;
        row["ex_id"] = query.value("ex_id").toInt();
        row["start_ip"] = query.value("start_ip").toString();
        row["end_ip"] = query.value("end_ip").toString();
        row["success"] = query.value("success").toInt();
        list.append(row);
    }

    return list;
}
