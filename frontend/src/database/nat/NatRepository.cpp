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

QVariantList NatRepository::getNatInterfaces(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT i.*, n.nat_name "
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

QVariantList NatRepository::getNatPatRules(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT r.*, n.nat_name, a.acl_name "
                  "FROM nat_overload_interface_rules r "
                  "JOIN NAT_DB n ON r.nat_id = n.nat_id "
                  "LEFT JOIN NAT_ACL_DB a ON r.nat_acl_id = a.nat_acl_id "
                  "WHERE n.host = :host");
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

QVariantList NatRepository::getNatDynamicPools(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT p.*, n.nat_name "
                  "FROM nat_pools p "
                  "JOIN NAT_DB n ON p.nat_id = n.nat_id "
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

QVariantList NatRepository::getNatStaticEntries(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT s.*, n.nat_name "
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