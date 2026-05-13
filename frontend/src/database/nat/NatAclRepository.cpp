#include "NatAclRepository.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QDebug>
#include <QVariant>

NatAclRepository::NatAclRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

QString NatAclRepository::lastError() const
{
    return m_lastError;
}

QVariantList NatAclRepository::getNatAcls(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "NatAclRepository:" << m_lastError;
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT a.nat_acl_id, a.acl_name, r.action, r.source AS source_network, r.wildcard "
                  "FROM NAT_ACL_DB a "
                  "JOIN nat_standard_acl_rules r ON a.nat_acl_id = r.nat_acl_id "
                  "WHERE a.host = :host AND a.acl_type = 'standard'");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatAcls:" << m_lastError;
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

bool NatAclRepository::addNatAcl(const QString &host,
                                 const QString &aclName,
                                 const QString &action,
                                 const QString &sourceNetwork,
                                 const QString &wildcard)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "NatAclRepository:" << m_lastError;
        return false;
    }

    m_db.transaction();

    QSqlQuery query(m_db);

    // 1. Insert vào NAT_ACL_DB
    query.prepare("INSERT INTO NAT_ACL_DB (acl_name, acl_type, host) "
                  "VALUES (:acl_name, 'standard', :host)");
    query.bindValue(":acl_name", aclName);
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatAcl (NAT_ACL_DB):" << m_lastError;
        m_db.rollback();
        return false;
    }

    int natAclId = query.lastInsertId().toInt();

    query.prepare("INSERT INTO nat_standard_acl_rules (nat_acl_id, action, source, wildcard) "
                  "VALUES (:nat_acl_id, :action, :source, :wildcard)");
    query.bindValue(":nat_acl_id", natAclId);
    query.bindValue(":action", action);
    query.bindValue(":source", sourceNetwork);
    query.bindValue(":wildcard", wildcard);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatAcl (nat_standard_acl_rules):" << m_lastError;
        m_db.rollback();
        return false;
    }

    m_db.commit();
    return true;
}

bool NatAclRepository::deleteNatAcl(int natAclId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "NatAclRepository:" << m_lastError;
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM NAT_ACL_DB WHERE nat_acl_id = :id");
    query.bindValue(":id", natAclId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteNatAcl:" << m_lastError;
        return false;
    }

    return true;
}