#include "DhcpHelperRepository.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

DhcpHelperRepository::DhcpHelperRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

bool DhcpHelperRepository::addHelperAddress(int ifaceId, const QString &helperIp)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in addHelperAddress";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO router_iface_helper (iface_id, helper_ip, success) "
        "VALUES (?, ?, 0) "
        "ON CONFLICT(iface_id, helper_ip) DO UPDATE SET success = 0;"
    );
    query.addBindValue(ifaceId);
    query.addBindValue(helperIp.trimmed());

    if (!query.exec()) {
        qWarning() << "addHelperAddress failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DhcpHelperRepository::deleteHelperAddress(int helperId)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in deleteHelperAddress";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("UPDATE router_iface_helper SET success = -1 WHERE id = ?;");
    query.addBindValue(helperId);

    if (!query.exec()) {
        qWarning() << "deleteHelperAddress failed:" << query.lastError().text();
        return false;
    }

    return true;
}

QVariantList DhcpHelperRepository::getHelperAddresses(const QString &host)
{
    QVariantList list;

    if (!m_db.isOpen()) {
        qWarning() << "Database not open in getHelperAddresses";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "SELECT h.id, h.iface_id, i.interface_name, h.helper_ip, h.success "
        "FROM router_iface_helper h "
        "JOIN interface_name i ON i.iface_id = h.iface_id "
        "WHERE i.host = ? AND COALESCE(h.success, 0) <> -1 "
        "ORDER BY i.interface_name COLLATE NOCASE, h.helper_ip COLLATE NOCASE;"
    );
    query.addBindValue(host.trimmed());

    if (!query.exec()) {
        qWarning() << "getHelperAddresses failed:" << query.lastError().text();
        return list;
    }

    while (query.next()) {
        QVariantMap row;
        row["id"] = query.value("id").toInt();
        row["iface_id"] = query.value("iface_id").toInt();
        row["interface_name"] = query.value("interface_name").toString();
        row["helper_ip"] = query.value("helper_ip").toString();
        row["success"] = query.value("success").toInt();
        list.append(row);
    }

    return list;
}
