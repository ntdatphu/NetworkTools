#include "OspfRoutingRepository.h"

#include <QHostAddress>
#include <QMap>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>

namespace {
bool isValidIpv4(const QString &value)
{
    QHostAddress address;
    return address.setAddress(value.trimmed()) && address.protocol() == QAbstractSocket::IPv4Protocol;
}

QString networkKey(const QString &network, const QString &wildcard, const QString &area)
{
    return network.trimmed() + "|" + wildcard.trimmed() + "|" + area.trimmed();
}

QVariant nullableInt(int value)
{
    return value > 0 ? QVariant(value) : QVariant(QMetaType::fromType<int>());
}

int optionalInt(const QVariantMap &map, const QString &key)
{
    bool ok = false;
    const int value = map.value(key).toString().trimmed().toInt(&ok);
    if (ok)
        return value;
    return map.value(key).toInt();
}

QVariant optionalIntVariant(const QVariantMap &map, const QString &key)
{
    const int value = optionalInt(map, key);
    return nullableInt(value);
}
}

OspfRoutingRepository::OspfRoutingRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

QString OspfRoutingRepository::lastError() const
{
    return m_lastError;
}

void OspfRoutingRepository::setLastError(const QString &message)
{
    m_lastError = message;
}

QVariantMap OspfRoutingRepository::getByHost(const QString &host)
{
    QVariantMap result;
    result["ok"] = false;
    result["message"] = QStringLiteral("Unknown error");
    result["processes"] = QVariantList();

    const QString normalizedHost = host.trimmed();
    if (normalizedHost.isEmpty()) {
        result["message"] = QStringLiteral("Host is empty");
        return result;
    }

    if (!m_db.isOpen()) {
        result["message"] = QStringLiteral("Database is not open");
        return result;
    }

    QSqlQuery processQuery(m_db);
    processQuery.prepare(
        "SELECT ospf_id, process_id, router_id, reference_bandwidth, "
        "passive_default, default_originate, default_originate_always, success "
        "FROM ospf_processes "
        "WHERE host = ? "
        "AND success != -1 "
        "ORDER BY ospf_id ASC;"
        );
    processQuery.addBindValue(normalizedHost);

    if (!processQuery.exec()) {
        result["message"] = processQuery.lastError().text();
        return result;
    }

    QVariantList processes;
    while (processQuery.next()) {
        const int ospfId = processQuery.value(0).toInt();

        QVariantMap process;
        process["ospf_id"]                  = ospfId;
        process["process_id"]               = processQuery.value(1).toInt();
        process["router_id"]                = processQuery.value(2).toString();
        process["reference_bandwidth"]      = processQuery.value(3).toInt();
        process["passive_default"]          = processQuery.value(4).toInt();
        process["default_originate"]        = processQuery.value(5).toInt();
        process["default_originate_always"] = processQuery.value(6).toInt();
        process["success"]                  = processQuery.value(7).toInt();

        QSqlQuery networkQuery(m_db);
        networkQuery.prepare(
            "SELECT id, network, wildcard, area, success "
            "FROM ospf_networks "
            "WHERE ospf_id = ? "
            "AND success != -1 "
            "ORDER BY id ASC;"
            );
        networkQuery.addBindValue(ospfId);
        if (!networkQuery.exec()) {
            result["message"] = networkQuery.lastError().text();
            return result;
        }

        QVariantList networks;
        while (networkQuery.next()) {
            QVariantMap network;
            network["id"]      = networkQuery.value(0).toInt();
            network["network"] = networkQuery.value(1).toString();
            network["wildcard"]= networkQuery.value(2).toString();
            network["area"]    = networkQuery.value(3).toString();
            network["success"] = networkQuery.value(4).toInt();
            networks.append(network);
        }

        process["networks"] = networks;

        QSqlQuery distanceQuery(m_db);
        distanceQuery.prepare(
            "SELECT external, intra_area, inter_area, success "
            "FROM ospf_distance "
            "WHERE ospf_id = ? AND success != -1;"
            );
        distanceQuery.addBindValue(ospfId);
        if (!distanceQuery.exec()) {
            result["message"] = distanceQuery.lastError().text();
            return result;
        }
        QVariantMap distance;
        if (distanceQuery.next()) {
            distance["external"] = distanceQuery.value(0).toInt();
            distance["intra_area"] = distanceQuery.value(1).toInt();
            distance["inter_area"] = distanceQuery.value(2).toInt();
            distance["success"] = distanceQuery.value(3).toInt();
        }
        process["distance"] = distance;

        QSqlQuery areaQuery(m_db);
        areaQuery.prepare(
            "SELECT id, area_id, area_type, no_summary, authentication, success "
            "FROM ospf_areas "
            "WHERE ospf_id = ? AND success != -1 "
            "ORDER BY id ASC;"
            );
        areaQuery.addBindValue(ospfId);
        if (!areaQuery.exec()) {
            result["message"] = areaQuery.lastError().text();
            return result;
        }
        QVariantList areas;
        while (areaQuery.next()) {
            const int areaDbId = areaQuery.value(0).toInt();
            QVariantMap area;
            area["id"] = areaDbId;
            area["area_id"] = areaQuery.value(1).toInt();
            area["area_type"] = areaQuery.value(2).toString();
            area["no_summary"] = areaQuery.value(3).toInt();
            area["authentication"] = areaQuery.value(4).toString();
            area["success"] = areaQuery.value(5).toInt();

            QSqlQuery rangeQuery(m_db);
            rangeQuery.prepare(
                "SELECT id, ip, mask, advertise, cost, success "
                "FROM ospf_area_ranges "
                "WHERE area_db_id = ? AND success != -1 "
                "ORDER BY id ASC;"
                );
            rangeQuery.addBindValue(areaDbId);
            if (!rangeQuery.exec()) {
                result["message"] = rangeQuery.lastError().text();
                return result;
            }
            QVariantList ranges;
            while (rangeQuery.next()) {
                QVariantMap range;
                range["id"] = rangeQuery.value(0).toInt();
                range["ip"] = rangeQuery.value(1).toString();
                range["mask"] = rangeQuery.value(2).toString();
                range["advertise"] = rangeQuery.value(3).toInt();
                range["cost"] = rangeQuery.value(4).toInt();
                range["success"] = rangeQuery.value(5).toInt();
                ranges.append(range);
            }
            area["ranges"] = ranges;
            areas.append(area);
        }
        process["areas"] = areas;

        QSqlQuery redistributeQuery(m_db);
        redistributeQuery.prepare(
            "SELECT id, protocol, process_id, subnets, metric, metric_type, route_map, success "
            "FROM ospf_redistribute "
            "WHERE ospf_id = ? AND success != -1 "
            "ORDER BY id ASC;"
            );
        redistributeQuery.addBindValue(ospfId);
        if (!redistributeQuery.exec()) {
            result["message"] = redistributeQuery.lastError().text();
            return result;
        }
        QVariantList redistribute;
        while (redistributeQuery.next()) {
            QVariantMap item;
            item["id"] = redistributeQuery.value(0).toInt();
            item["protocol"] = redistributeQuery.value(1).toString();
            item["process_id"] = redistributeQuery.value(2).toInt();
            item["subnets"] = redistributeQuery.value(3).toInt();
            item["metric"] = redistributeQuery.value(4).toInt();
            item["metric_type"] = redistributeQuery.value(5).toInt();
            item["route_map"] = redistributeQuery.value(6).toString();
            item["success"] = redistributeQuery.value(7).toInt();
            redistribute.append(item);
        }
        process["redistribute"] = redistribute;

        QSqlQuery passiveQuery(m_db);
        passiveQuery.prepare(
            "SELECT id, interface_name, passive, success "
            "FROM ospf_passive_interfaces "
            "WHERE ospf_id = ? AND success != -1 "
            "ORDER BY id ASC;"
            );
        passiveQuery.addBindValue(ospfId);
        if (!passiveQuery.exec()) {
            result["message"] = passiveQuery.lastError().text();
            return result;
        }
        QVariantList passiveInterfaces;
        while (passiveQuery.next()) {
            QVariantMap item;
            item["id"] = passiveQuery.value(0).toInt();
            item["interface_name"] = passiveQuery.value(1).toString();
            item["passive"] = passiveQuery.value(2).toInt();
            item["success"] = passiveQuery.value(3).toInt();
            passiveInterfaces.append(item);
        }
        process["passive_interfaces"] = passiveInterfaces;

        QSqlQuery tuningQuery(m_db);
        tuningQuery.prepare(
            "SELECT maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay, "
            "lsa_delay, lsa_min_delay, lsa_max_delay, success "
            "FROM ospf_tuning "
            "WHERE ospf_id = ? AND success != -1;"
            );
        tuningQuery.addBindValue(ospfId);
        if (!tuningQuery.exec()) {
            result["message"] = tuningQuery.lastError().text();
            return result;
        }
        QVariantMap tuning;
        if (tuningQuery.next()) {
            tuning["maximum_paths"] = tuningQuery.value(0).toInt();
            tuning["max_lsa"] = tuningQuery.value(1).toInt();
            tuning["spf_delay"] = tuningQuery.value(2).toInt();
            tuning["spf_min_delay"] = tuningQuery.value(3).toInt();
            tuning["spf_max_delay"] = tuningQuery.value(4).toInt();
            tuning["lsa_delay"] = tuningQuery.value(5).toInt();
            tuning["lsa_min_delay"] = tuningQuery.value(6).toInt();
            tuning["lsa_max_delay"] = tuningQuery.value(7).toInt();
            tuning["success"] = tuningQuery.value(8).toInt();
        }
        process["tuning"] = tuning;

        QSqlQuery interfaceQuery(m_db);
        interfaceQuery.prepare(
            "SELECT id, interface_name, area, cost, hello_interval, dead_interval, "
            "mtu_ignore, bfd, network_type, auth_type, success "
            "FROM ospf_interface_settings "
            "WHERE ospf_id = ? AND success != -1 "
            "ORDER BY id ASC;"
            );
        interfaceQuery.addBindValue(ospfId);
        if (!interfaceQuery.exec()) {
            result["message"] = interfaceQuery.lastError().text();
            return result;
        }
        QVariantList interfaceSettings;
        while (interfaceQuery.next()) {
            QVariantMap item;
            item["id"] = interfaceQuery.value(0).toInt();
            item["interface_name"] = interfaceQuery.value(1).toString();
            item["area"] = interfaceQuery.value(2).toInt();
            item["cost"] = interfaceQuery.value(3).toInt();
            item["hello_interval"] = interfaceQuery.value(4).toInt();
            item["dead_interval"] = interfaceQuery.value(5).toInt();
            item["mtu_ignore"] = interfaceQuery.value(6).toInt();
            item["bfd"] = interfaceQuery.value(7).toInt();
            item["network_type"] = interfaceQuery.value(8).toString();
            item["auth_type"] = interfaceQuery.value(9).toString();
            item["success"] = interfaceQuery.value(10).toInt();
            interfaceSettings.append(item);
        }
        process["interface_settings"] = interfaceSettings;

        processes.append(process);
    }

    result["ok"] = true;
    result["message"] = QStringLiteral("Loaded OSPF routing");
    result["processes"] = processes;
    return result;
}

bool OspfRoutingRepository::saveByHost(const QString &host, const QVariantList &processes)
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

    QMap<int, QVariantMap> activeProcessesById;
    QList<int> activeProcessIds;
    QSqlQuery activeQuery(m_db);
    activeQuery.prepare(
        "SELECT ospf_id, process_id, router_id, reference_bandwidth, "
        "passive_default, default_originate, default_originate_always, success "
        "FROM ospf_processes "
        "WHERE host = ? "
        "AND success != -1;"
        );
    activeQuery.addBindValue(normalizedHost);
    if (!activeQuery.exec()) {
        setLastError(activeQuery.lastError().text());
        m_db.rollback();
        return false;
    }

    while (activeQuery.next()) {
        const int ospfId = activeQuery.value(0).toInt();
        QVariantMap process;
        process["ospf_id"]                  = ospfId;
        process["process_id"]               = activeQuery.value(1).toInt();
        process["router_id"]                = activeQuery.value(2).toString().trimmed();
        process["reference_bandwidth"]      = activeQuery.value(3).toInt();
        process["passive_default"]          = activeQuery.value(4).toInt();
        process["default_originate"]        = activeQuery.value(5).toInt();
        process["default_originate_always"] = activeQuery.value(6).toInt();
        process["success"]                  = activeQuery.value(7).toInt();
        activeProcessesById.insert(ospfId, process);
        activeProcessIds.append(ospfId);
    }

    QSet<int> usedProcessIds;
    QSet<int> payloadOspfIds;
    for (const QVariant &processVar : processes) {
        const QVariantMap process = processVar.toMap();
        const int ospfId              = process.value("ospf_id").toInt();
        const int processId           = process.value("process_id").toInt();
        const QString routerId        = process.value("router_id").toString().trimmed();
        const int referenceBandwidth  = process.value("reference_bandwidth").toInt();
        const int passiveDefault      = process.value("passive_default").toBool() ? 1 : 0;
        const int defaultOriginate    = process.value("default_originate").toBool() ? 1 : 0;
        const int defaultOriginateAlways = process.value("default_originate_always").toBool() ? 1 : 0;
        const QVariantList networks   = process.value("networks").toList();
        const QVariantMap distance    = process.value("distance").toMap();
        const QVariantMap tuning      = process.value("tuning").toMap();
        const QVariantList areas      = process.value("areas").toList();
        const QVariantList redistribute = process.value("redistribute").toList();
        const QVariantList passiveInterfaces = process.value("passive_interfaces").toList();
        const QVariantList interfaceSettings = process.value("interface_settings").toList();

        if (processId < 1 || processId > 65535) {
            setLastError(QStringLiteral("OSPF process id must be between 1 and 65535"));
            m_db.rollback();
            return false;
        }

        if (usedProcessIds.contains(processId)) {
            setLastError(QStringLiteral("Duplicate OSPF process id in payload"));
            m_db.rollback();
            return false;
        }
        usedProcessIds.insert(processId);
        if (ospfId > 0)
            payloadOspfIds.insert(ospfId);

        if (!routerId.isEmpty() && !isValidIpv4(routerId)) {
            setLastError(QStringLiteral("OSPF router-id must be a valid IPv4 address"));
            m_db.rollback();
            return false;
        }

        if (referenceBandwidth < 0) {
            setLastError(QStringLiteral("OSPF reference-bandwidth must be a non-negative integer"));
            m_db.rollback();
            return false;
        }

        int validNetworkCount = 0;
        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard  = network.value("wildcard").toString().trimmed();
            const QString area      = network.value("area").toString().trimmed();

            if (networkIp.isEmpty() && wildcard.isEmpty() && area.isEmpty())
                continue;

            if (networkIp.isEmpty() || wildcard.isEmpty() || area.isEmpty()) {
                setLastError(QStringLiteral("OSPF network must include network, wildcard, and area"));
                m_db.rollback();
                return false;
            }

            if (!isValidIpv4(networkIp) || !isValidIpv4(wildcard)) {
                setLastError(QStringLiteral("OSPF network and wildcard must be valid IPv4 values"));
                m_db.rollback();
                return false;
            }

            ++validNetworkCount;
        }

        if (validNetworkCount == 0) {
            setLastError(QStringLiteral("Each OSPF process must contain at least one network"));
            m_db.rollback();
            return false;
        }

        const bool hasExistingProcess = ospfId > 0 && activeProcessesById.contains(ospfId);

        int targetOspfId = ospfId;

        if (hasExistingProcess) {
            if (!updateProcessOptions(targetOspfId,
                                      processId,
                                      routerId,
                                      referenceBandwidth,
                                      passiveDefault,
                                      defaultOriginate,
                                      defaultOriginateAlways)) {
                m_db.rollback();
                return false;
            }

            QMap<QString, int> activeNetworkIdsByKey;
            QSqlQuery activeNetworksQuery(m_db);
            activeNetworksQuery.prepare(
                "SELECT id, network, wildcard, area "
                "FROM ospf_networks "
                "WHERE ospf_id = ? "
                "AND success != -1;"
                );
            activeNetworksQuery.addBindValue(targetOspfId);
            if (!activeNetworksQuery.exec()) {
                setLastError(activeNetworksQuery.lastError().text());
                m_db.rollback();
                return false;
            }

            while (activeNetworksQuery.next()) {
                activeNetworkIdsByKey.insert(
                    networkKey(activeNetworksQuery.value(1).toString(),
                               activeNetworksQuery.value(2).toString(),
                               activeNetworksQuery.value(3).toString()),
                    activeNetworksQuery.value(0).toInt());
            }

            QSet<QString> payloadNetworkKeys;
            for (const QVariant &networkVar : networks) {
                const QVariantMap network = networkVar.toMap();
                const QString networkIp = network.value("network").toString().trimmed();
                const QString wildcard  = network.value("wildcard").toString().trimmed();
                const QString area      = network.value("area").toString().trimmed();

                if (networkIp.isEmpty() || wildcard.isEmpty() || area.isEmpty()) {
                    setLastError(QStringLiteral("OSPF network must include network, wildcard, and area"));
                    m_db.rollback();
                    return false;
                }

                const QString key = networkKey(networkIp, wildcard, area);
                payloadNetworkKeys.insert(key);

                if (!activeNetworkIdsByKey.contains(key)
                    && !insertNetwork(targetOspfId, networkIp, wildcard, area, 0)) {
                    m_db.rollback();
                    return false;
                }
            }

            QList<int> removedNetworkIds;
            for (auto it = activeNetworkIdsByKey.cbegin(); it != activeNetworkIdsByKey.cend(); ++it) {
                if (!payloadNetworkKeys.contains(it.key()))
                    removedNetworkIds.append(it.value());
            }

            if (!removedNetworkIds.isEmpty() && !markNetworksByIds(removedNetworkIds, -1)) {
                m_db.rollback();
                return false;
            }

            if (!saveDistance(targetOspfId, distance)
                || !saveAreas(targetOspfId, areas)
                || !saveRedistribute(targetOspfId, redistribute)
                || !savePassiveInterfaces(targetOspfId, passiveInterfaces)
                || !saveTuning(targetOspfId, tuning)
                || !saveInterfaceSettings(targetOspfId, interfaceSettings)) {
                m_db.rollback();
                return false;
            }

            continue;
        }

        targetOspfId = insertProcess(normalizedHost,
                                     processId,
                                     routerId,
                                     referenceBandwidth,
                                     passiveDefault,
                                     defaultOriginate,
                                     defaultOriginateAlways,
                                     0);
        if (targetOspfId <= 0) {
            m_db.rollback();
            return false;
        }

        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard  = network.value("wildcard").toString().trimmed();
            const QString area      = network.value("area").toString().trimmed();

            if (networkIp.isEmpty() || wildcard.isEmpty() || area.isEmpty()) {
                setLastError(QStringLiteral("OSPF network must include network, wildcard, and area"));
                m_db.rollback();
                return false;
            }

            if (!insertNetwork(targetOspfId, networkIp, wildcard, area, 0)) {
                m_db.rollback();
                return false;
            }
        }

        if (!saveDistance(targetOspfId, distance)
            || !saveAreas(targetOspfId, areas)
            || !saveRedistribute(targetOspfId, redistribute)
            || !savePassiveInterfaces(targetOspfId, passiveInterfaces)
            || !saveTuning(targetOspfId, tuning)
            || !saveInterfaceSettings(targetOspfId, interfaceSettings)) {
            m_db.rollback();
            return false;
        }
    }

    QList<int> removedProcessIds;
    for (int activeProcessId : activeProcessIds) {
        if (!payloadOspfIds.contains(activeProcessId))
            removedProcessIds.append(activeProcessId);
    }

    if (!removedProcessIds.isEmpty()) {
        if (!markNetworksByProcessIds(removedProcessIds, -1)) {
            m_db.rollback();
            return false;
        }
        if (!markAreaRangesByProcessIds(removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("ospf_distance"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("ospf_areas"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("ospf_redistribute"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("ospf_passive_interfaces"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("ospf_tuning"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("ospf_interface_settings"), removedProcessIds, -1)) {
            m_db.rollback();
            return false;
        }
        if (!markProcessesByIds(removedProcessIds, -1)) {
            m_db.rollback();
            return false;
        }
    }

    if (!m_db.commit()) {
        setLastError(m_db.lastError().text());
        m_db.rollback();
        return false;
    }

    return true;
}

bool OspfRoutingRepository::clearByHost(const QString &host)
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

    QList<int> activeProcessIds;
    QSqlQuery activeQuery(m_db);
    activeQuery.prepare(
        "SELECT ospf_id "
        "FROM ospf_processes "
        "WHERE host = ? "
        "AND success != -1;"
        );
    activeQuery.addBindValue(normalizedHost);
    if (!activeQuery.exec()) {
        setLastError(activeQuery.lastError().text());
        m_db.rollback();
        return false;
    }

    while (activeQuery.next()) {
        activeProcessIds.append(activeQuery.value(0).toInt());
    }

    if (!markNetworksByProcessIds(activeProcessIds, -1)) {
        m_db.rollback();
        return false;
    }

    if (!markAreaRangesByProcessIds(activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_distance"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_areas"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_redistribute"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_passive_interfaces"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_tuning"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_interface_settings"), activeProcessIds, -1)) {
        m_db.rollback();
        return false;
    }

    if (!markProcessesByHost(normalizedHost, -1)) {
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

bool OspfRoutingRepository::markProcessesByIds(const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_processes "
        "SET success = ? "
        "WHERE ospf_id = ? "
        "AND success != -1;"
        );

    for (int processId : processIds) {
        query.addBindValue(success);
        query.addBindValue(processId);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        query.finish();
    }

    return true;
}

bool OspfRoutingRepository::markProcessesByHost(const QString &host, int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_processes "
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

bool OspfRoutingRepository::markNetworksByIds(const QList<int> &networkIds, int success)
{
    if (networkIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_networks "
        "SET success = ? "
        "WHERE id = ? "
        "AND success != -1;"
        );

    for (int networkId : networkIds) {
        query.addBindValue(success);
        query.addBindValue(networkId);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        query.finish();
    }

    return true;
}

bool OspfRoutingRepository::markNetworksByProcessIds(const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_networks "
        "SET success = ? "
        "WHERE ospf_id = ? "
        "AND success != -1;"
        );

    for (int processId : processIds) {
        query.addBindValue(success);
        query.addBindValue(processId);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        query.finish();
    }

    return true;
}

bool OspfRoutingRepository::markChildRowsByProcessIds(const QString &table, const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("UPDATE %1 SET success = ? WHERE ospf_id = ? AND success != -1;").arg(table));
    for (int processId : processIds) {
        query.addBindValue(success);
        query.addBindValue(processId);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        query.finish();
    }
    return true;
}

bool OspfRoutingRepository::markAreaRangesByProcessIds(const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_area_ranges "
        "SET success = ? "
        "WHERE area_db_id IN (SELECT id FROM ospf_areas WHERE ospf_id = ?) "
        "AND success != -1;"
        );
    for (int processId : processIds) {
        query.addBindValue(success);
        query.addBindValue(processId);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        query.finish();
    }
    return true;
}

bool OspfRoutingRepository::updateProcessOptions(int ospfId,
                                                 int processId,
                                                 const QString &routerId,
                                                 int referenceBandwidth,
                                                 int passiveDefault,
                                                 int defaultOriginate,
                                                 int defaultOriginateAlways)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_processes "
        "SET process_id = ?, router_id = ?, reference_bandwidth = ?, "
        "passive_default = ?, default_originate = ?, default_originate_always = ?, success = 0 "
        "WHERE ospf_id = ? "
        "AND success != -1;"
        );
    query.addBindValue(processId);
    query.addBindValue(routerId);
    query.addBindValue(nullableInt(referenceBandwidth));
    query.addBindValue(passiveDefault);
    query.addBindValue(defaultOriginate);
    query.addBindValue(defaultOriginateAlways);
    query.addBindValue(ospfId);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

int OspfRoutingRepository::insertProcess(const QString &host,
                                         int processId,
                                         const QString &routerId,
                                         int referenceBandwidth,
                                         int passiveDefault,
                                         int defaultOriginate,
                                         int defaultOriginateAlways,
                                         int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT OR REPLACE INTO ospf_processes "
        "(host, process_id, router_id, reference_bandwidth, "
        "passive_default, default_originate, default_originate_always, success) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
        );
    query.addBindValue(host);
    query.addBindValue(processId);
    query.addBindValue(routerId);
    query.addBindValue(referenceBandwidth > 0 ? referenceBandwidth : QVariant(QMetaType::fromType<int>()));
    query.addBindValue(passiveDefault);
    query.addBindValue(defaultOriginate);
    query.addBindValue(defaultOriginateAlways);
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return 0;
    }
    return query.lastInsertId().toInt();
}

bool OspfRoutingRepository::insertNetwork(int ospfId,
                                          const QString &network,
                                          const QString &wildcard,
                                          const QString &area,
                                          int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT OR REPLACE INTO ospf_networks (ospf_id, network, wildcard, area, success) "
        "VALUES (?, ?, ?, ?, ?);"
        );
    query.addBindValue(ospfId);
    query.addBindValue(network);
    query.addBindValue(wildcard);
    query.addBindValue(area);
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool OspfRoutingRepository::saveDistance(int ospfId, const QVariantMap &distance)
{
    if (distance.isEmpty())
        return markChildRowsByProcessIds(QStringLiteral("ospf_distance"), {ospfId}, -1);

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT OR REPLACE INTO ospf_distance "
        "(ospf_id, external, intra_area, inter_area, success) "
        "VALUES (?, ?, ?, ?, 0);"
        );
    query.addBindValue(ospfId);
    query.addBindValue(optionalIntVariant(distance, QStringLiteral("external")));
    query.addBindValue(optionalIntVariant(distance, QStringLiteral("intra_area")));
    query.addBindValue(optionalIntVariant(distance, QStringLiteral("inter_area")));
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool OspfRoutingRepository::saveTuning(int ospfId, const QVariantMap &tuning)
{
    if (tuning.isEmpty())
        return markChildRowsByProcessIds(QStringLiteral("ospf_tuning"), {ospfId}, -1);

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT OR REPLACE INTO ospf_tuning "
        "(ospf_id, maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay, "
        "lsa_delay, lsa_min_delay, lsa_max_delay, success) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0);"
        );
    query.addBindValue(ospfId);
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("maximum_paths")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("max_lsa")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("spf_delay")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("spf_min_delay")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("spf_max_delay")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("lsa_delay")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("lsa_min_delay")));
    query.addBindValue(optionalIntVariant(tuning, QStringLiteral("lsa_max_delay")));
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool OspfRoutingRepository::saveAreas(int ospfId, const QVariantList &areas)
{
    if (!markAreaRangesByProcessIds({ospfId}, -1)
        || !markChildRowsByProcessIds(QStringLiteral("ospf_areas"), {ospfId}, -1)) {
        return false;
    }

    for (const QVariant &areaVar : areas) {
        const QVariantMap area = areaVar.toMap();
        const int areaId = optionalInt(area, QStringLiteral("area_id"));
        if (areaId < 0) {
            setLastError(QStringLiteral("OSPF area id must be a non-negative integer"));
            return false;
        }

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO ospf_areas "
            "(ospf_id, area_id, area_type, no_summary, authentication, success) "
            "VALUES (?, ?, ?, ?, ?, 0);"
            );
        query.addBindValue(ospfId);
        query.addBindValue(areaId);
        query.addBindValue(area.value("area_type").toString().trimmed().isEmpty()
                               ? QStringLiteral("normal")
                               : area.value("area_type").toString().trimmed());
        query.addBindValue(area.value("no_summary").toBool() ? 1 : 0);
        const QString auth = area.value("authentication").toString().trimmed();
        query.addBindValue(auth.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(auth));
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
        const int areaDbId = query.lastInsertId().toInt();

        const QVariantList ranges = area.value("ranges").toList();
        for (const QVariant &rangeVar : ranges) {
            const QVariantMap range = rangeVar.toMap();
            const QString ip = range.value("ip").toString().trimmed();
            const QString mask = range.value("mask").toString().trimmed();
            if (ip.isEmpty() || mask.isEmpty())
                continue;

            QSqlQuery rangeQuery(m_db);
            rangeQuery.prepare(
                "INSERT OR REPLACE INTO ospf_area_ranges "
                "(area_db_id, ip, mask, advertise, cost, success) "
                "VALUES (?, ?, ?, ?, ?, 0);"
                );
            rangeQuery.addBindValue(areaDbId);
            rangeQuery.addBindValue(ip);
            rangeQuery.addBindValue(mask);
            rangeQuery.addBindValue(range.value("advertise", true).toBool() ? 1 : 0);
            rangeQuery.addBindValue(optionalIntVariant(range, QStringLiteral("cost")));
            if (!rangeQuery.exec()) {
                setLastError(rangeQuery.lastError().text());
                return false;
            }
        }
    }
    return true;
}

bool OspfRoutingRepository::saveRedistribute(int ospfId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("ospf_redistribute"), {ospfId}, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString protocol = item.value("protocol").toString().trimmed();
        if (protocol.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO ospf_redistribute "
            "(ospf_id, protocol, process_id, subnets, metric, metric_type, route_map, success) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, 0);"
            );
        query.addBindValue(ospfId);
        query.addBindValue(protocol);
        query.addBindValue(optionalIntVariant(item, QStringLiteral("process_id")));
        query.addBindValue(item.value("subnets", true).toBool() ? 1 : 0);
        query.addBindValue(optionalIntVariant(item, QStringLiteral("metric")));
        query.addBindValue(optionalIntVariant(item, QStringLiteral("metric_type")));
        const QString routeMap = item.value("route_map").toString().trimmed();
        query.addBindValue(routeMap.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(routeMap));
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool OspfRoutingRepository::savePassiveInterfaces(int ospfId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("ospf_passive_interfaces"), {ospfId}, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString interfaceName = item.value("interface_name").toString().trimmed();
        if (interfaceName.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO ospf_passive_interfaces "
            "(ospf_id, interface_name, passive, success) "
            "VALUES (?, ?, ?, 0);"
            );
        query.addBindValue(ospfId);
        query.addBindValue(interfaceName);
        query.addBindValue(item.value("passive", true).toBool() ? 1 : 0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool OspfRoutingRepository::saveInterfaceSettings(int ospfId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("ospf_interface_settings"), {ospfId}, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString interfaceName = item.value("interface_name").toString().trimmed();
        const int area = optionalInt(item, QStringLiteral("area"));
        if (interfaceName.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO ospf_interface_settings "
            "(ospf_id, interface_name, area, cost, hello_interval, dead_interval, "
            "mtu_ignore, bfd, network_type, auth_type, success) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);"
            );
        query.addBindValue(ospfId);
        query.addBindValue(interfaceName);
        query.addBindValue(area);
        query.addBindValue(optionalIntVariant(item, QStringLiteral("cost")));
        query.addBindValue(optionalIntVariant(item, QStringLiteral("hello_interval")));
        query.addBindValue(optionalIntVariant(item, QStringLiteral("dead_interval")));
        query.addBindValue(item.value("mtu_ignore").toBool() ? 1 : 0);
        query.addBindValue(item.value("bfd").toBool() ? 1 : 0);
        const QString networkType = item.value("network_type").toString().trimmed();
        const QString authType = item.value("auth_type").toString().trimmed();
        query.addBindValue(networkType.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(networkType));
        query.addBindValue(authType.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(authType));
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}
