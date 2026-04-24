#include "DhcpPoolRepository.h"
#include "SqlUtils.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

DhcpPoolRepository::DhcpPoolRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

bool DhcpPoolRepository::addDhcpPool(const QString &host,
                                     const QString &pool,
                                     const QString &network,
                                     const QString &subnetmask,
                                     const QString &defaut,
                                     const QString &dns)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in addDhcpPool";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO dhcp_pool (host, pool, network, subnetmask, defaut, dns) "
        "VALUES (?, ?, ?, ?, ?, ?);"
    );

    query.addBindValue(host.trimmed());
    query.addBindValue(pool.trimmed());
    query.addBindValue(network.trimmed());
    query.addBindValue(subnetmask.trimmed());
    query.addBindValue(defaut.trimmed());
    query.addBindValue(dns.trimmed());

    if (!query.exec()) {
        qWarning() << "addDhcpPool failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DhcpPoolRepository::deleteDhcpPool(int dhcpId)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in deleteDhcpPool";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM dhcp_pool WHERE dhcp_id = ?;");
    query.addBindValue(dhcpId);

    if (!query.exec()) {
        qWarning() << "deleteDhcpPool failed:" << query.lastError().text();
        return false;
    }

    return true;
}

QVariantList DhcpPoolRepository::getDhcpPools(const QString &host)
{
    QVariantList list;

    if (!m_db.isOpen()) {
        qWarning() << "Database not open in getDhcpPools";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "SELECT dhcp_id, pool, network, subnetmask, defaut, dns "
        "FROM dhcp_pool WHERE host = ? ORDER BY dhcp_id ASC;"
    );
    query.addBindValue(host.trimmed());

    if (!query.exec()) {
        qWarning() << "getDhcpPools failed:" << query.lastError().text();
        return list;
    }

    while (query.next()) {
        QVariantMap row;
        row["dhcp_id"] = query.value("dhcp_id").toInt();
        row["pool"] = query.value("pool").toString();
        row["network"] = query.value("network").toString();
        row["subnetmask"] = query.value("subnetmask").toString();
        row["defaut"] = query.value("defaut").toString();
        row["dns"] = query.value("dns").toString();
        list.append(row);
    }

    return list;
}
