#include "DhcpPoolRepository.h"
#include "SqlUtils.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

namespace {

QString normalizeLease(const QString &lease)
{
    const QString trimmed = lease.trimmed();
    return trimmed.isEmpty() ? QStringLiteral("1") : trimmed;
}

QString buildDhcpActionCfg(bool defaultChanged, bool dnsChanged, bool leaseChanged)
{
    QString cfg;
    cfg.reserve(3);
    cfg.append(defaultChanged ? QLatin1Char('1') : QLatin1Char('0'));
    cfg.append(dnsChanged ? QLatin1Char('1') : QLatin1Char('0'));
    cfg.append(leaseChanged ? QLatin1Char('1') : QLatin1Char('0'));
    return cfg;
}

} // namespace

DhcpPoolRepository::DhcpPoolRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

bool DhcpPoolRepository::addDhcpPool(const QString &host,
                                     const QString &pool,
                                     const QString &network,
                                     const QString &subnetmask,
                                     const QString &defaut,
                                     const QString &dns,
                                     const QString &lease)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in addDhcpPool";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO dhcp_pool (host, pool, network, subnetmask, defaut, dns, lease, success, action_Cfg) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, 0, '111');"
    );

    query.addBindValue(host.trimmed());
    query.addBindValue(pool.trimmed());
    query.addBindValue(network.trimmed());
    query.addBindValue(subnetmask.trimmed());
    query.addBindValue(defaut.trimmed());
    query.addBindValue(dns.trimmed());
    query.addBindValue(normalizeLease(lease));

    if (!query.exec()) {
        qWarning() << "addDhcpPool failed:" << query.lastError().text();
        return false;
    }

    return true;
}

bool DhcpPoolRepository::updateDhcpPool(int dhcpId,
                                        const QString &pool,
                                        const QString &network,
                                        const QString &subnetmask,
                                        const QString &defaut,
                                        const QString &dns,
                                        const QString &lease)
{
    if (!m_db.isOpen()) {
        qWarning() << "Database not open in updateDhcpPool";
        return false;
    }

    QSqlQuery currentQuery(m_db);
    currentQuery.prepare(
        "SELECT host, pool, network, subnetmask, defaut, dns, lease "
        "FROM dhcp_pool WHERE dhcp_id = ? AND COALESCE(success, 0) <> -1;"
    );
    currentQuery.addBindValue(dhcpId);

    if (!currentQuery.exec()) {
        qWarning() << "updateDhcpPool select failed:" << currentQuery.lastError().text();
        return false;
    }

    if (!currentQuery.next()) {
        qWarning() << "updateDhcpPool target not found:" << dhcpId;
        return false;
    }

    const QString host = currentQuery.value("host").toString();
    const QString oldPool = currentQuery.value("pool").toString();
    const QString oldNetwork = currentQuery.value("network").toString();
    const QString oldSubnetmask = currentQuery.value("subnetmask").toString();
    const QString oldDefaut = currentQuery.value("defaut").toString();
    const QString oldDns = currentQuery.value("dns").toString();
    const QString oldLease = normalizeLease(currentQuery.value("lease").toString());

    const QString newPool = pool.trimmed();
    const QString newNetwork = network.trimmed();
    const QString newSubnetmask = subnetmask.trimmed();
    const QString newDefaut = defaut.trimmed();
    const QString newDns = dns.trimmed();
    const QString newLease = normalizeLease(lease);

    const bool identityChanged = oldPool != newPool
        || oldNetwork != newNetwork
        || oldSubnetmask != newSubnetmask;

    if (identityChanged) {
        if (!m_db.transaction()) {
            qWarning() << "updateDhcpPool transaction failed:" << m_db.lastError().text();
            return false;
        }

        QSqlQuery markQuery(m_db);
        markQuery.prepare("UPDATE dhcp_pool SET success = -1 WHERE dhcp_id = ?;");
        markQuery.addBindValue(dhcpId);
        if (!markQuery.exec()) {
            qWarning() << "updateDhcpPool mark old failed:" << markQuery.lastError().text();
            m_db.rollback();
            return false;
        }

        QSqlQuery insertQuery(m_db);
        insertQuery.prepare(
            "INSERT INTO dhcp_pool (host, pool, network, subnetmask, defaut, dns, lease, success, action_Cfg) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, 0, '111');"
        );
        insertQuery.addBindValue(host);
        insertQuery.addBindValue(newPool);
        insertQuery.addBindValue(newNetwork);
        insertQuery.addBindValue(newSubnetmask);
        insertQuery.addBindValue(newDefaut);
        insertQuery.addBindValue(newDns);
        insertQuery.addBindValue(newLease);
        if (!insertQuery.exec()) {
            qWarning() << "updateDhcpPool insert replacement failed:" << insertQuery.lastError().text();
            m_db.rollback();
            return false;
        }

        return m_db.commit();
    }

    const QString actionCfg = buildDhcpActionCfg(oldDefaut != newDefaut,
                                                 oldDns != newDns,
                                                 oldLease != newLease);

    QSqlQuery updateQuery(m_db);
    updateQuery.prepare(
        "UPDATE dhcp_pool SET defaut = ?, dns = ?, lease = ?, action_Cfg = ?, success = 0 "
        "WHERE dhcp_id = ?;"
    );
    updateQuery.addBindValue(newDefaut);
    updateQuery.addBindValue(newDns);
    updateQuery.addBindValue(newLease);
    updateQuery.addBindValue(actionCfg);
    updateQuery.addBindValue(dhcpId);

    if (!updateQuery.exec()) {
        qWarning() << "updateDhcpPool option update failed:" << updateQuery.lastError().text();
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
    query.prepare("UPDATE dhcp_pool SET success = -1 WHERE dhcp_id = ?;");
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
        "SELECT dhcp_id, pool, network, subnetmask, defaut, dns, lease, success, action_Cfg "
        "FROM dhcp_pool WHERE host = ? AND COALESCE(success, 0) <> -1 ORDER BY dhcp_id ASC;"
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
        row["lease"] = normalizeLease(query.value("lease").toString());
        row["success"] = query.value("success").toInt();
        row["action_Cfg"] = query.value("action_Cfg").toString();
        list.append(row);
    }

    return list;
}
