#include "NatAclRepository.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QDebug>

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
    query.prepare("SELECT * FROM nat_acl WHERE host = :host");
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

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO nat_acl (host, acl_name, action, source_network, wildcard) "
                  "VALUES (:host, :acl_name, :action, :source_network, :wildcard)");
    query.bindValue(":host", host);
    query.bindValue(":acl_name", aclName);
    query.bindValue(":action", action);
    query.bindValue(":source_network", sourceNetwork);
    query.bindValue(":wildcard", wildcard);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addNatAcl:" << m_lastError;
        return false;
    }

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
    query.prepare("DELETE FROM nat_acl WHERE nat_acl_id = :id");
    query.bindValue(":id", natAclId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteNatAcl:" << m_lastError;
        return false;
    }

    return true;
}