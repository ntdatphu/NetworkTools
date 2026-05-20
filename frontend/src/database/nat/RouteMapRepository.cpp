#include "RouteMapRepository.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QVariant>
#include <QVariantMap>

RouteMapRepository::RouteMapRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

QString RouteMapRepository::lastError() const
{
    return m_lastError;
}

int RouteMapRepository::getOrCreateRouteMapId(const QString &host,
                                              const QString &routeMapName,
                                              const QString &description)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT route_map_id FROM route_map_db "
                  "WHERE host = :host AND route_map_name = :route_map_name");
    query.bindValue(":host", host);
    query.bindValue(":route_map_name", routeMapName);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error selecting route_map_db:" << m_lastError;
        return -1;
    }

    if (query.next()) {
        const int routeMapId = query.value(0).toInt();
        if (!description.trimmed().isEmpty()) {
            QSqlQuery updateQuery(m_db);
            updateQuery.prepare("UPDATE route_map_db "
                                "SET description = :description "
                                "WHERE route_map_id = :route_map_id");
            updateQuery.bindValue(":description", description.trimmed());
            updateQuery.bindValue(":route_map_id", routeMapId);
            if (!updateQuery.exec()) {
                m_lastError = updateQuery.lastError().text();
                qWarning() << "Error updating route_map_db:" << m_lastError;
                return -1;
            }
        }
        return routeMapId;
    }

    query.prepare("INSERT INTO route_map_db (route_map_name, host, description) "
                  "VALUES (:route_map_name, :host, :description)");
    query.bindValue(":route_map_name", routeMapName);
    query.bindValue(":host", host);
    query.bindValue(":description", description.trimmed().isEmpty() ? QVariant() : description.trimmed());

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error inserting route_map_db:" << m_lastError;
        return -1;
    }

    return query.lastInsertId().toInt();
}

int RouteMapRepository::findNatAclId(const QString &host, const QString &natAclName)
{
    if (natAclName.trimmed().isEmpty())
        return 0;

    QSqlQuery query(m_db);
    query.prepare("SELECT nat_acl_id FROM NAT_ACL_DB "
                  "WHERE host = :host AND acl_name = :acl_name");
    query.bindValue(":host", host);
    query.bindValue(":acl_name", natAclName.trimmed());

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error selecting NAT_ACL_DB:" << m_lastError;
        return -1;
    }

    if (!query.next()) {
        m_lastError = QString("NAT ACL not found: %1").arg(natAclName);
        return -1;
    }

    return query.value(0).toInt();
}

QVariantList RouteMapRepository::getRouteMapEntries(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "RouteMapRepository:" << m_lastError;
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT e.id AS route_map_entry_id, m.route_map_id, "
                  "m.route_map_name, COALESCE(m.description, '') AS description, "
                  "e.sequence, e.action, COALESCE(a.acl_name, '') AS nat_acl_name, "
                  "e.nat_acl_id, e.success "
                  "FROM route_map_entries e "
                  "JOIN route_map_db m ON e.route_map_id = m.route_map_id "
                  "LEFT JOIN NAT_ACL_DB a ON e.nat_acl_id = a.nat_acl_id "
                  "WHERE m.host = :host "
                  "ORDER BY m.route_map_name ASC, e.sequence ASC");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getRouteMapEntries:" << m_lastError;
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

bool RouteMapRepository::addRouteMapEntry(const QString &host,
                                          const QString &routeMapName,
                                          const QString &description,
                                          int sequence,
                                          const QString &action,
                                          const QString &natAclName)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "RouteMapRepository:" << m_lastError;
        return false;
    }
    if (sequence <= 0) {
        m_lastError = "Route map sequence must be greater than 0.";
        qWarning() << "RouteMapRepository:" << m_lastError;
        return false;
    }
    if (action != "permit" && action != "deny") {
        m_lastError = "Route map action must be permit or deny.";
        qWarning() << "RouteMapRepository:" << m_lastError;
        return false;
    }

    m_db.transaction();

    const int routeMapId = getOrCreateRouteMapId(host, routeMapName.trimmed(), description);
    if (routeMapId < 0) {
        m_db.rollback();
        return false;
    }

    const int natAclId = findNatAclId(host, natAclName);
    if (natAclId < 0) {
        qWarning() << "Error executing addRouteMapEntry:" << m_lastError;
        m_db.rollback();
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO route_map_entries "
                  "(route_map_id, sequence, action, nat_acl_id) "
                  "VALUES (:route_map_id, :sequence, :action, :nat_acl_id)");
    query.bindValue(":route_map_id", routeMapId);
    query.bindValue(":sequence", sequence);
    query.bindValue(":action", action);
    query.bindValue(":nat_acl_id", natAclId == 0 ? QVariant() : natAclId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing addRouteMapEntry:" << m_lastError;
        m_db.rollback();
        return false;
    }

    return m_db.commit();
}

bool RouteMapRepository::deleteRouteMapEntry(int entryId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "RouteMapRepository:" << m_lastError;
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM route_map_entries WHERE id = :id");
    query.bindValue(":id", entryId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteRouteMapEntry:" << m_lastError;
        return false;
    }

    return true;
}
