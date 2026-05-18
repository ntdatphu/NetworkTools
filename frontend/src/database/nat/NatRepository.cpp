#include "NatRepository.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QDebug>

NatRepository::NatRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

QString NatRepository::lastError() const
{
    return m_lastError;
}

int NatRepository::getOrCreateNatId(const QString &host, const QString &natName, const QString &natType)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT nat_id FROM NAT_DB WHERE host = :host AND nat_name = :nat_name");
    query.bindValue(":host", host);
    query.bindValue(":nat_name", natName);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error selecting NAT_DB:" << m_lastError;
        return -1;
    }
    if (query.next()) {
        return query.value(0).toInt();
    }

    query.prepare("INSERT INTO NAT_DB (nat_name, nat_type, host) "
                  "VALUES (:nat_name, :nat_type, :host)");
    query.bindValue(":nat_name", natName);
    query.bindValue(":nat_type", natType);
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error inserting NAT_DB:" << m_lastError;
        return -1;
    }

    return query.lastInsertId().toInt();
}

int NatRepository::findNatAclId(const QString &host, const QString &aclName)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT nat_acl_id FROM NAT_ACL_DB "
                  "WHERE host = :host AND acl_name = :acl_name");
    query.bindValue(":host", host);
    query.bindValue(":acl_name", aclName);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error selecting NAT_ACL_DB:" << m_lastError;
        return -1;
    }
    return query.next() ? query.value(0).toInt() : -1;
}

int NatRepository::findNatPoolId(const QString &host, const QString &poolName)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT p.pool_id "
                  "FROM nat_pools p "
                  "JOIN NAT_DB n ON p.nat_id = n.nat_id "
                  "WHERE n.host = :host AND p.pool_name = :pool_name");
    query.bindValue(":host", host);
    query.bindValue(":pool_name", poolName);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error selecting nat_pools:" << m_lastError;
        return -1;
    }
    return query.next() ? query.value(0).toInt() : -1;
}

QVariantList NatRepository::getNatInterfaces(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT i.id AS nat_intf_id, i.interface_name, i.nat_role AS direction, "
                  "i.nat_role, i.success, n.nat_id, n.nat_name "
                  "FROM nat_interfaces i "
                  "JOIN NAT_DB n ON i.nat_id = n.nat_id "
                  "WHERE n.host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatInterfaces:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

bool NatRepository::addNatInterface(const QString &host,
                                    const QString &interfaceName,
                                    const QString &direction)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }
    if (direction != "inside" && direction != "outside") {
        m_lastError = "NAT interface direction must be inside or outside.";
        return false;
    }

    m_db.transaction();
    const int natId = getOrCreateNatId(host, "nat_interfaces", "dynamic");
    if (natId < 0) {
        m_db.rollback();
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO nat_interfaces (nat_id, interface_name, nat_role) "
                  "VALUES (:nat_id, :interface_name, :nat_role)");
    query.bindValue(":nat_id", natId);
    query.bindValue(":interface_name", interfaceName);
    query.bindValue(":nat_role", direction);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatInterface:" << m_lastError;
        m_db.rollback();
        return false;
    }

    return m_db.commit();
}

bool NatRepository::deleteNatInterface(int natInterfaceId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM nat_interfaces WHERE id = :id");
    query.bindValue(":id", natInterfaceId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteNatInterface:" << m_lastError;
        return false;
    }

    return true;
}

QVariantList NatRepository::getNatPatRules(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT r.id AS nat_pat_id, a.acl_name, 'Interface' AS source_type, "
                  "r.outside_interface AS source_value, r.overload, r.description, "
                  "r.success, n.nat_id, n.nat_name "
                  "FROM nat_overload_interface_rules r "
                  "JOIN NAT_DB n ON r.nat_id = n.nat_id "
                  "JOIN NAT_ACL_DB a ON r.nat_acl_id = a.nat_acl_id "
                  "WHERE n.host = :host "
                  "UNION ALL "
                  "SELECT -r.id AS nat_pat_id, a.acl_name, 'Pool' AS source_type, "
                  "p.pool_name AS source_value, r.overload, r.description, "
                  "r.success, n.nat_id, n.nat_name "
                  "FROM nat_dynamic_rules r "
                  "JOIN NAT_DB n ON r.nat_id = n.nat_id "
                  "JOIN NAT_ACL_DB a ON r.nat_acl_id = a.nat_acl_id "
                  "JOIN nat_pools p ON r.pool_id = p.pool_id "
                  "WHERE n.host = :host AND r.overload = 1");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatPatRules:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

bool NatRepository::addNatPatRule(const QString &host,
                                  const QString &aclName,
                                  const QString &sourceType,
                                  const QString &sourceValue,
                                  bool overload)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    const int natAclId = findNatAclId(host, aclName);
    if (natAclId < 0) {
        if (m_lastError.isEmpty()) {
            m_lastError = QString("NAT ACL not found: %1").arg(aclName);
        }
        qWarning() << "Error executing addNatPatRule:" << m_lastError;
        return false;
    }

    m_db.transaction();

    QSqlQuery query(m_db);
    if (sourceType == "Interface") {
        const int natId = getOrCreateNatId(host, "nat_overload", "overload");
        if (natId < 0) {
            m_db.rollback();
            return false;
        }

        query.prepare("INSERT INTO nat_overload_interface_rules "
                      "(nat_id, nat_acl_id, outside_interface, overload) "
                      "VALUES (:nat_id, :nat_acl_id, :outside_interface, :overload)");
        query.bindValue(":nat_id", natId);
        query.bindValue(":nat_acl_id", natAclId);
        query.bindValue(":outside_interface", sourceValue);
        query.bindValue(":overload", overload ? 1 : 0);
    } else if (sourceType == "Pool") {
        const int poolId = findNatPoolId(host, sourceValue);
        if (poolId < 0) {
            if (m_lastError.isEmpty()) {
                m_lastError = QString("NAT pool not found: %1").arg(sourceValue);
            }
            qWarning() << "Error executing addNatPatRule:" << m_lastError;
            m_db.rollback();
            return false;
        }

        const int natId = getOrCreateNatId(host, "nat_dynamic", "dynamic");
        if (natId < 0) {
            m_db.rollback();
            return false;
        }

        query.prepare("INSERT INTO nat_dynamic_rules "
                      "(nat_id, nat_acl_id, pool_id, overload) "
                      "VALUES (:nat_id, :nat_acl_id, :pool_id, :overload)");
        query.bindValue(":nat_id", natId);
        query.bindValue(":nat_acl_id", natAclId);
        query.bindValue(":pool_id", poolId);
        query.bindValue(":overload", overload ? 1 : 0);
    } else {
        m_lastError = "PAT source type must be Interface or Pool.";
        m_db.rollback();
        return false;
    }

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatPatRule:" << m_lastError;
        m_db.rollback();
        return false;
    }

    return m_db.commit();
}

bool NatRepository::deleteNatPatRule(int natPatId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    QSqlQuery query(m_db);
    if (natPatId < 0) {
        query.prepare("DELETE FROM nat_dynamic_rules WHERE id = :id");
        query.bindValue(":id", -natPatId);
    } else {
        query.prepare("DELETE FROM nat_overload_interface_rules WHERE id = :id");
        query.bindValue(":id", natPatId);
    }

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteNatPatRule:" << m_lastError;
        return false;
    }

    return true;
}

QVariantList NatRepository::getNatDynamicPools(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT p.pool_id AS nat_dynamic_id, p.pool_id, p.pool_name, "
                  "p.start_ip, p.end_ip, p.netmask, p.prefix_length, p.success, "
                  "n.nat_id, n.nat_name, COALESCE(a.acl_name, '') AS acl_name "
                  "FROM nat_pools p "
                  "JOIN NAT_DB n ON p.nat_id = n.nat_id "
                  "LEFT JOIN nat_dynamic_rules r ON p.pool_id = r.pool_id "
                  "LEFT JOIN NAT_ACL_DB a ON r.nat_acl_id = a.nat_acl_id "
                  "WHERE n.host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatDynamicPools:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

bool NatRepository::addNatDynamicPool(const QString &host,
                                      const QString &poolName,
                                      const QString &startIp,
                                      const QString &endIp,
                                      const QString &netmask,
                                      const QString &aclName)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    m_db.transaction();
    const int natId = getOrCreateNatId(host, "nat_dynamic", "dynamic");
    if (natId < 0) {
        m_db.rollback();
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO nat_pools (nat_id, pool_name, start_ip, end_ip, netmask) "
                  "VALUES (:nat_id, :pool_name, :start_ip, :end_ip, :netmask)");
    query.bindValue(":nat_id", natId);
    query.bindValue(":pool_name", poolName);
    query.bindValue(":start_ip", startIp);
    query.bindValue(":end_ip", endIp);
    query.bindValue(":netmask", netmask);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatDynamicPool (nat_pools):" << m_lastError;
        m_db.rollback();
        return false;
    }

    const int poolId = query.lastInsertId().toInt();
    if (!aclName.trimmed().isEmpty()) {
        const int natAclId = findNatAclId(host, aclName);
        if (natAclId < 0) {
            if (m_lastError.isEmpty()) {
                m_lastError = QString("NAT ACL not found: %1").arg(aclName);
            }
            qWarning() << "Error executing addNatDynamicPool:" << m_lastError;
            m_db.rollback();
            return false;
        }

        query.prepare("INSERT INTO nat_dynamic_rules (nat_id, nat_acl_id, pool_id, overload) "
                      "VALUES (:nat_id, :nat_acl_id, :pool_id, 0)");
        query.bindValue(":nat_id", natId);
        query.bindValue(":nat_acl_id", natAclId);
        query.bindValue(":pool_id", poolId);

        if (!query.exec()) {
            m_lastError = query.lastError().text();
            qWarning() << "Error executing addNatDynamicPool (nat_dynamic_rules):" << m_lastError;
            m_db.rollback();
            return false;
        }
    }

    return m_db.commit();
}

bool NatRepository::deleteNatDynamicPool(int natDynamicId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM nat_pools WHERE pool_id = :id");
    query.bindValue(":id", natDynamicId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteNatDynamicPool:" << m_lastError;
        return false;
    }

    return true;
}

QVariantList NatRepository::getNatStaticEntries(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT s.id AS nat_static_id, s.inside_local_ip AS inside_local, "
                  "s.inside_global_ip AS inside_global, s.inside_local_ip, "
                  "s.inside_global_ip, s.protocol, s.local_port, s.global_port, "
                  "s.is_extendable, s.description, s.success, n.nat_id, n.nat_name "
                  "FROM nat_static_mappings s "
                  "JOIN NAT_DB n ON s.nat_id = n.nat_id "
                  "WHERE n.host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatStaticEntries:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

bool NatRepository::addNatStaticEntry(const QString &host,
                                      const QString &insideLocalIp,
                                      const QString &insideGlobalIp,
                                      const QString &protocol,
                                      const QString &localPort,
                                      const QString &globalPort)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    m_db.transaction();
    const int natId = getOrCreateNatId(host, "nat_static", "static");
    if (natId < 0) {
        m_db.rollback();
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO nat_static_mappings "
                  "(nat_id, inside_local_ip, inside_global_ip, protocol, local_port, global_port) "
                  "VALUES (:nat_id, :inside_local_ip, :inside_global_ip, "
                  ":protocol, :local_port, :global_port)");
    query.bindValue(":nat_id", natId);
    query.bindValue(":inside_local_ip", insideLocalIp);
    query.bindValue(":inside_global_ip", insideGlobalIp);
    query.bindValue(":protocol", protocol.trimmed().isEmpty() ? QVariant() : protocol.trimmed().toLower());
    query.bindValue(":local_port", localPort.trimmed().isEmpty() ? QVariant() : localPort.trimmed().toInt());
    query.bindValue(":global_port", globalPort.trimmed().isEmpty() ? QVariant() : globalPort.trimmed().toInt());

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatStaticEntry:" << m_lastError;
        m_db.rollback();
        return false;
    }

    return m_db.commit();
}

bool NatRepository::deleteNatStaticEntry(int natStaticId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM nat_static_mappings WHERE id = :id");
    query.bindValue(":id", natStaticId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteNatStaticEntry:" << m_lastError;
        return false;
    }

    return true;
}
