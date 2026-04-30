#include "RoutingStaticRepository.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QMap>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QSet>
#include <QTextStream>

RoutingStaticRepository::RoutingStaticRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

QString RoutingStaticRepository::lastError() const
{
    return m_lastError;
}

void RoutingStaticRepository::setLastError(const QString &message)
{
    m_lastError = message;
}

QVariantMap RoutingStaticRepository::getByHost(const QString &host)
{
    QVariantMap result;
    result["ok"] = false;
    result["message"] = QStringLiteral("Unknown error");
    result["default_route"] = QString();
    result["routes"] = QVariantList();

    const QString normalizedHost = host.trimmed();
    if (normalizedHost.isEmpty()) {
        result["message"] = QStringLiteral("Host is empty");
        return result;
    }

    if (!m_db.isOpen()) {
        result["message"] = QStringLiteral("Database is not open");
        return result;
    }

    QSqlQuery defaultQuery(m_db);
    defaultQuery.prepare(
        "SELECT id, next_hop_ip, success "
        "FROM static_default_routes "
        "WHERE host = ? "
        "AND success != -1 "
        "ORDER BY id DESC LIMIT 1;"
    );
    defaultQuery.addBindValue(normalizedHost);

    if (!defaultQuery.exec()) {
        result["message"] = defaultQuery.lastError().text();
        return result;
    }

    if (defaultQuery.next()) {
        result["default_route_id"] = defaultQuery.value(0).toInt();
        result["default_route"] = defaultQuery.value(1).toString();
        result["default_route_success"] = defaultQuery.value(2).toInt();
    } else {
        result["default_route_id"] = 0;
        result["default_route_success"] = 0;
    }

    QVariantList routes;
    QSqlQuery routesQuery(m_db);
    routesQuery.prepare(
        "SELECT id, network, subnet_mask, next_hop, ad, success "
        "FROM static_routes "
        "WHERE host = ? "
        "AND success != -1 "
        "ORDER BY id ASC;"
    );
    routesQuery.addBindValue(normalizedHost);

    if (!routesQuery.exec()) {
        result["message"] = routesQuery.lastError().text();
        return result;
    }

    while (routesQuery.next()) {
        QVariantMap row;
        row["id"] = routesQuery.value(0).toInt();
        row["network"] = routesQuery.value(1).toString();
        row["mask"] = routesQuery.value(2).toString();
        row["nexthop"] = routesQuery.value(3).toString();
        row["ad"] = routesQuery.value(4).toInt();
        row["success"] = routesQuery.value(5).toInt();
        routes.append(row);
    }

    result["ok"] = true;
    result["message"] = QStringLiteral("Loaded static/default routes");
    result["routes"] = routes;
    return result;
}

bool RoutingStaticRepository::saveByHost(const QString &host,
                                         const QString &defaultRoute,
                                         const QVariantList &routes)
{
    setLastError(QString());

    const QString normalizedHost = host.trimmed();
    const QString normalizedDefault = defaultRoute.trimmed();

    if (normalizedHost.isEmpty()) {
        setLastError(QStringLiteral("Host is empty"));
        return false;
    }

    if (!m_db.isOpen()) {
        setLastError(QStringLiteral("Database is not open"));
        return false;
    }

    if (!m_db.transaction()) {
        setLastError(m_db.lastError().text());
        return false;
    }

    int currentDefaultId = 0;
    int currentDefaultSuccess = 0;
    QString currentDefaultNextHop;
    QSqlQuery currentDefaultQuery(m_db);
    currentDefaultQuery.prepare(
        "SELECT id, next_hop_ip, success "
        "FROM static_default_routes "
        "WHERE host = ? "
        "AND success != -1 "
        "ORDER BY id DESC LIMIT 1;"
    );
    currentDefaultQuery.addBindValue(normalizedHost);
    if (!currentDefaultQuery.exec()) {
        setLastError(currentDefaultQuery.lastError().text());
        m_db.rollback();
        return false;
    }
    if (currentDefaultQuery.next()) {
        currentDefaultId = currentDefaultQuery.value(0).toInt();
        currentDefaultNextHop = currentDefaultQuery.value(1).toString().trimmed();
        currentDefaultSuccess = currentDefaultQuery.value(2).toInt();
    }

    if (normalizedDefault.isEmpty()) {
        if (!markDefaultByHost(normalizedHost, -1)) {
            m_db.rollback();
            return false;
        }
    } else if (currentDefaultId == 0) {
        if (!insertDefault(normalizedHost, normalizedDefault, 0)) {
            m_db.rollback();
            return false;
        }
    } else if (currentDefaultNextHop != normalizedDefault) {
        if (!markDefaultByHost(normalizedHost, -1)) {
            m_db.rollback();
            return false;
        }
        if (!insertDefault(normalizedHost, normalizedDefault, 0)) {
            m_db.rollback();
            return false;
        }
    } else if (currentDefaultSuccess != 0) {
        if (!markDefaultByHost(normalizedHost, 0)) {
            m_db.rollback();
            return false;
        }
    }

    QMap<int, QVariantMap> activeRowsById;
    QList<int> activeIdsInDb;
    QSqlQuery activeStaticQuery(m_db);
    activeStaticQuery.prepare(
        "SELECT id, network, subnet_mask, next_hop, ad "
        "FROM static_routes "
        "WHERE host = ? "
        "AND success != -1;"
    );
    activeStaticQuery.addBindValue(normalizedHost);
    if (!activeStaticQuery.exec()) {
        setLastError(activeStaticQuery.lastError().text());
        m_db.rollback();
        return false;
    }

    while (activeStaticQuery.next()) {
        const int id = activeStaticQuery.value(0).toInt();
        QVariantMap row;
        row["id"] = id;
        row["network"] = activeStaticQuery.value(1).toString();
        row["mask"] = activeStaticQuery.value(2).toString();
        row["nexthop"] = activeStaticQuery.value(3).toString();
        row["ad"] = activeStaticQuery.value(4).toInt();
        activeRowsById.insert(id, row);
        activeIdsInDb.append(id);
    }

    QSet<int> activeIdsInPayload;
    for (const QVariant &routeVar : routes) {
        const QVariantMap route = routeVar.toMap();
        const int id = route.value("id").toInt();
        if (id > 0)
            activeIdsInPayload.insert(id);
    }

    QList<int> removedIds;
    QVariantList removedRows;
    for (int id : activeIdsInDb) {
        if (!activeIdsInPayload.contains(id)) {
            removedIds.append(id);
            removedRows.append(activeRowsById.value(id));
        }
    }

    if (!removedIds.isEmpty() && !markStaticByIds(removedIds, -1)) {
        m_db.rollback();
        return false;
    }

    for (const QVariant &routeVar : routes) {
        const QVariantMap route = routeVar.toMap();
        const QString network = route.value("network").toString().trimmed();
        const QString mask = route.value("mask").toString().trimmed();
        const QString nextHop = route.value("nexthop").toString().trimmed();
        const int existingId = route.value("id").toInt();
        const bool edited = route.value("edited").toBool();

        if (network.isEmpty() && mask.isEmpty() && nextHop.isEmpty()) {
            continue;
        }

        if (network.isEmpty() || mask.isEmpty() || nextHop.isEmpty()) {
            setLastError(QStringLiteral("Static route must include network, mask, and next-hop"));
            m_db.rollback();
            return false;
        }

        int ad = route.value("ad").toInt();
        if (ad < 1 || ad > 255) {
            ad = 1;
        }

        if (existingId > 0) {
            if (edited) {
                if (activeRowsById.contains(existingId)) {
                    removedRows.append(activeRowsById.value(existingId));
                }
                if (!markStaticByIds({existingId}, -1)) {
                    m_db.rollback();
                    return false;
                }
                if (!insertStatic(normalizedHost, network, mask, nextHop, ad, 0)) {
                    m_db.rollback();
                    return false;
                }
            }
            continue;
        }

        if (!insertStatic(normalizedHost, network, mask, nextHop, ad, 0)) {
            m_db.rollback();
            return false;
        }
    }

    if (!removedRows.isEmpty() && !appendRemovedStaticRowsToText(normalizedHost, removedRows)) {
        m_db.rollback();
        return false;
    }

    if (!m_db.commit()) {
        setLastError(m_db.lastError().text());
        m_db.rollback();
        return false;
    }

    return true;
}

bool RoutingStaticRepository::clearByHost(const QString &host)
{
    setLastError(QString());

    const QString normalizedHost = host.trimmed();
    if (normalizedHost.isEmpty()) {
        setLastError(QStringLiteral("Host is empty"));
        return false;
    }

    if (!m_db.isOpen()) {
        setLastError(QStringLiteral("Database is not open"));
        return false;
    }

    if (!m_db.transaction()) {
        setLastError(m_db.lastError().text());
        return false;
    }

    if (!markDefaultByHost(normalizedHost, -1)) {
        m_db.rollback();
        return false;
    }

    QSqlQuery selectIdsQuery(m_db);
    selectIdsQuery.prepare(
        "SELECT id "
        "FROM static_routes "
        "WHERE host = ? "
        "AND success != -1;"
    );
    selectIdsQuery.addBindValue(normalizedHost);
    if (!selectIdsQuery.exec()) {
        setLastError(selectIdsQuery.lastError().text());
        m_db.rollback();
        return false;
    }

    QList<int> ids;
    while (selectIdsQuery.next()) {
        ids.append(selectIdsQuery.value(0).toInt());
    }

    if (!ids.isEmpty() && !markStaticByIds(ids, -1)) {
        m_db.rollback();
        return false;
    }

    if (!m_db.commit()) {
        setLastError(m_db.lastError().text());
        m_db.rollback();
        return false;
    }

    return true;
}

bool RoutingStaticRepository::markDefaultByHost(const QString &host, int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE static_default_routes "
        "SET success = ? "
        "WHERE host = ? "
        "AND success != -1;"
    );
    query.addBindValue(success);
    query.addBindValue(host);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool RoutingStaticRepository::markStaticByIds(const QList<int> &ids, int success)
{
    if (ids.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE static_routes "
        "SET success = ? "
        "WHERE id = ? "
        "AND success != -1;"
    );

    for (int id : ids) {
        query.addBindValue(success);
        query.addBindValue(id);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        query.finish();
    }

    return true;
}

bool RoutingStaticRepository::insertDefault(const QString &host,
                                            const QString &nextHop,
                                            int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO static_default_routes (host, next_hop_ip, success) "
        "VALUES (?, ?, ?);"
    );
    query.addBindValue(host);
    query.addBindValue(nextHop);
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool RoutingStaticRepository::insertStatic(const QString &host,
                                           const QString &network,
                                           const QString &mask,
                                           const QString &nextHop,
                                           int ad,
                                           int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO static_routes (host, network, subnet_mask, next_hop, ad, success) "
        "VALUES (?, ?, ?, ?, ?, ?);"
    );
    query.addBindValue(host);
    query.addBindValue(network);
    query.addBindValue(mask);
    query.addBindValue(nextHop);
    query.addBindValue(ad);
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool RoutingStaticRepository::appendRemovedStaticRowsToText(const QString &host,
                                                            const QVariantList &removedRows)
{
    if (removedRows.isEmpty())
        return true;

    QString safeHost = host;
    safeHost.replace(QRegularExpression("[^A-Za-z0-9._-]"), "_");
    if (safeHost.isEmpty()) {
        safeHost = QStringLiteral("unknown_host");
    }

    const QString outputDirPath = QCoreApplication::applicationDirPath() + "/script";
    QDir outputDir(outputDirPath);
    if (!outputDir.exists() && !outputDir.mkpath(".")) {
        setLastError(QStringLiteral("Cannot create script output directory"));
        return false;
    }

    const QString outputFilePath = outputDir.filePath("static_removed_" + safeHost + ".txt");
    QFile file(outputFilePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        setLastError(QStringLiteral("Cannot open removed static output file: ") + outputFilePath);
        return false;
    }

    QTextStream out(&file);
    for (const QVariant &rowVar : removedRows) {
        const QVariantMap row = rowVar.toMap();
        const QString network = row.value("network").toString().trimmed();
        const QString mask = row.value("mask").toString().trimmed();
        const QString nextHop = row.value("nexthop").toString().trimmed();
        int ad = row.value("ad").toInt();
        if (ad < 1 || ad > 255)
            ad = 1;

        if (network.isEmpty() || mask.isEmpty() || nextHop.isEmpty())
            continue;

        out << "no " << network << " " << mask << " " << nextHop << " " << ad << "\n";
    }

    file.close();
    return true;
}
