#include "EigrpRoutingRepository.h"

#include <QHostAddress>
#include <QMap>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>

namespace {
bool isValidIpv4(const QString &value)
{
    QHostAddress address;
    return address.setAddress(value.trimmed()) && address.protocol() == QAbstractSocket::IPv4Protocol;
}

QString networkKey(const QString &network, const QString &wildcard)
{
    return network.trimmed() + "|" + wildcard.trimmed();
}

QString networkKey(const QString &network, const QString &wildcard, const QString &interfaceName)
{
    return network.trimmed() + "|" + wildcard.trimmed() + "|" + interfaceName.trimmed();
}

QVariant nullableInt(int value)
{
    return value > 0 ? QVariant(value) : QVariant(QMetaType::fromType<int>());
}

QVariant nullableString(const QString &value)
{
    const QString trimmed = value.trimmed();
    return trimmed.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(trimmed);
}

int optionalInt(const QVariantMap &map, const QString &key)
{
    bool ok = false;
    const int value = map.value(key).toString().trimmed().toInt(&ok);
    return ok ? value : map.value(key).toInt();
}

QString actionCfgForProcess(const QVariantMap &process)
{
    const QString value = process.value("action_Cfg").toString().trimmed();
    if (value.length() == 7)
        return value;
    return QStringLiteral("1111111");
}
}

EigrpRoutingRepository::EigrpRoutingRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

QString EigrpRoutingRepository::lastError() const
{
    return m_lastError;
}

void EigrpRoutingRepository::setLastError(const QString &message)
{
    m_lastError = message;
}

bool EigrpRoutingRepository::isValidMetricWeights(const QString &metricWeights) const
{
    const QStringList parts = metricWeights.trimmed().split(" ", Qt::SkipEmptyParts);
    if (parts.size() != 6)
        return false;

    bool ok = false;
    if (parts.at(0).toInt(&ok) != 0 || !ok)
        return false;

    for (int i = 1; i < parts.size(); ++i) {
        const int value = parts.at(i).toInt(&ok);
        if (!ok || value < 0 || value > 255)
            return false;
    }

    return true;
}

QVariantMap EigrpRoutingRepository::getByHost(const QString &host)
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

    QSqlQuery keyChainQuery(m_db);
    keyChainQuery.prepare(
        "SELECT id, chain_name, key_id, key_string, accept_lifetime, send_lifetime, success "
        "FROM eigrp_key_chains "
        "WHERE host = ? AND success != -1 "
        "ORDER BY id ASC;"
        );
    keyChainQuery.addBindValue(normalizedHost);
    if (!keyChainQuery.exec()) {
        result["message"] = keyChainQuery.lastError().text();
        return result;
    }

    QVariantList keyChains;
    while (keyChainQuery.next()) {
        QVariantMap item;
        item["id"] = keyChainQuery.value(0).toInt();
        item["chain_name"] = keyChainQuery.value(1).toString();
        item["key_id"] = keyChainQuery.value(2).toInt();
        item["key_string"] = keyChainQuery.value(3).toString();
        item["accept_lifetime"] = keyChainQuery.value(4).toString();
        item["send_lifetime"] = keyChainQuery.value(5).toString();
        item["success"] = keyChainQuery.value(6).toInt();
        keyChains.append(item);
    }

    QSqlQuery processQuery(m_db);
    processQuery.prepare(
        "SELECT eigrp_id, as_number, router_id, timers_active_time, bfd_all_interfaces, "
        "auto_summary, passive_default, metric_weights, distance_internal, distance_external, "
        "variance, maximum_paths, stub_enabled, stub_options, stub_leak_map, action, action_Cfg, success "
        "FROM eigrp_processes "
        "WHERE host = ? "
        "AND success != -1 "
        "ORDER BY eigrp_id ASC;"
        );
    processQuery.addBindValue(normalizedHost);

    if (!processQuery.exec()) {
        result["message"] = processQuery.lastError().text();
        return result;
    }

    QVariantList processes;
    while (processQuery.next()) {
        const int eigrpId = processQuery.value(0).toInt();

        QVariantMap process;
        process["eigrp_id"] = eigrpId;
        process["as_number"] = processQuery.value(1).toInt();
        process["router_id"] = processQuery.value(2).toString();
        process["timers_active_time"] = processQuery.value(3).toInt();
        process["bfd_all_interfaces"] = processQuery.value(4).toInt();
        process["auto_summary"] = processQuery.value(5).toInt();
        process["passive_default"] = processQuery.value(6).toInt();
        process["metric_weights"] = processQuery.value(7).toString();
        process["distance_internal"] = processQuery.value(8).toInt();
        process["distance_external"] = processQuery.value(9).toInt();
        process["variance"] = processQuery.value(10).toInt();
        process["maximum_paths"] = processQuery.value(11).toInt();
        process["stub_enabled"] = processQuery.value(12).toInt();
        process["stub_options"] = processQuery.value(13).toString();
        process["stub_leak_map"] = processQuery.value(14).toString();
        process["action"] = processQuery.value(15).toInt();
        process["action_Cfg"] = processQuery.value(16).toString();
        process["success"] = processQuery.value(17).toInt();

        QSqlQuery networkQuery(m_db);
        networkQuery.prepare(
            "SELECT id, network, wildcard, interface_name, success "
            "FROM eigrp_networks "
            "WHERE eigrp_id = ? "
            "AND success != -1 "
            "ORDER BY id ASC;"
            );
        networkQuery.addBindValue(eigrpId);
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
            network["interface_name"] = networkQuery.value(3).toString();
            network["success"] = networkQuery.value(4).toInt();
            networks.append(network);
        }

        process["networks"] = networks;
        process["interface_settings"] = QVariantList();
        process["passive_interfaces"] = QVariantList();
        process["distribute_lists"] = QVariantList();
        process["offset_lists"] = QVariantList();
        process["redistribute"] = QVariantList();
        process["key_chains"] = keyChains;

        const QList<QPair<QString, QString>> childQueries = {
            {"interface_settings",
             "SELECT id, interface_name, bandwidth, delay, hello_interval, hold_time, auth_key_chain, "
             "summary_ip, summary_mask, split_horizon, bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx, bfd_multiplier, success "
             "FROM eigrp_interface_settings WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;"},
            {"passive_interfaces",
             "SELECT id, interface_name, mode, success FROM eigrp_passive_interfaces WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;"},
            {"distribute_lists",
             "SELECT id, list_name, direction, interface_name, success FROM eigrp_distribute_lists WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;"},
            {"offset_lists",
             "SELECT id, list_name, direction, value, interface_name, success FROM eigrp_offset_lists WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;"},
            {"redistribute",
             "SELECT id, protocol, route_map, metric_bw, metric_delay, metric_reliability, metric_load, metric_mtu, success "
             "FROM eigrp_redistribute WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;"}
        };

        for (const auto &entry : childQueries) {
            QSqlQuery childQuery(m_db);
            childQuery.prepare(entry.second);
            childQuery.addBindValue(eigrpId);
            if (!childQuery.exec()) {
                result["message"] = childQuery.lastError().text();
                return result;
            }

            QVariantList rows;
            while (childQuery.next()) {
                QVariantMap row;
                row["id"] = childQuery.value(0).toInt();
                if (entry.first == "interface_settings") {
                    row["interface_name"] = childQuery.value(1).toString();
                    row["bandwidth"] = childQuery.value(2).toInt();
                    row["delay"] = childQuery.value(3).toInt();
                    row["hello_interval"] = childQuery.value(4).toInt();
                    row["hold_time"] = childQuery.value(5).toInt();
                    row["auth_key_chain"] = childQuery.value(6).toString();
                    row["summary_ip"] = childQuery.value(7).toString();
                    row["summary_mask"] = childQuery.value(8).toString();
                    row["split_horizon"] = childQuery.value(9).toInt();
                    row["bandwidth_percent"] = childQuery.value(10).toInt();
                    row["next_hop_self"] = childQuery.value(11).toInt();
                    row["bfd"] = childQuery.value(12).toInt();
                    row["bfd_tx"] = childQuery.value(13).toInt();
                    row["bfd_rx"] = childQuery.value(14).toInt();
                    row["bfd_multiplier"] = childQuery.value(15).toInt();
                    row["success"] = childQuery.value(16).toInt();
                } else if (entry.first == "passive_interfaces") {
                    row["interface_name"] = childQuery.value(1).toString();
                    row["mode"] = childQuery.value(2).toString();
                    row["success"] = childQuery.value(3).toInt();
                } else if (entry.first == "distribute_lists") {
                    row["list_name"] = childQuery.value(1).toString();
                    row["direction"] = childQuery.value(2).toString();
                    row["interface_name"] = childQuery.value(3).toString();
                    row["success"] = childQuery.value(4).toInt();
                } else if (entry.first == "offset_lists") {
                    row["list_name"] = childQuery.value(1).toString();
                    row["direction"] = childQuery.value(2).toString();
                    row["value"] = childQuery.value(3).toInt();
                    row["interface_name"] = childQuery.value(4).toString();
                    row["success"] = childQuery.value(5).toInt();
                } else {
                    row["protocol"] = childQuery.value(1).toString();
                    row["route_map"] = childQuery.value(2).toString();
                    row["metric_bw"] = childQuery.value(3).toInt();
                    row["metric_delay"] = childQuery.value(4).toInt();
                    row["metric_reliability"] = childQuery.value(5).toInt();
                    row["metric_load"] = childQuery.value(6).toInt();
                    row["metric_mtu"] = childQuery.value(7).toInt();
                    row["success"] = childQuery.value(8).toInt();
                }
                rows.append(row);
            }
            process[entry.first] = rows;
        }
        processes.append(process);
    }

    result["ok"] = true;
    result["message"] = QStringLiteral("Loaded EIGRP routing");
    result["processes"] = processes;
    return result;
}

bool EigrpRoutingRepository::saveByHost(const QString &host, const QVariantList &processes)
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
        "SELECT eigrp_id, as_number, router_id, timers_active_time, bfd_all_interfaces, "
        "auto_summary, passive_default, metric_weights, distance_internal, distance_external, "
        "variance, maximum_paths, stub_enabled, stub_options, stub_leak_map, action, action_Cfg, success "
        "FROM eigrp_processes "
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
        const int eigrpId = activeQuery.value(0).toInt();
        QVariantMap process;
        process["eigrp_id"] = eigrpId;
        process["as_number"] = activeQuery.value(1).toInt();
        process["router_id"] = activeQuery.value(2).toString().trimmed();
        process["timers_active_time"] = activeQuery.value(3).toInt();
        process["bfd_all_interfaces"] = activeQuery.value(4).toInt();
        process["auto_summary"] = activeQuery.value(5).toInt();
        process["passive_default"] = activeQuery.value(6).toInt();
        process["metric_weights"] = activeQuery.value(7).toString().trimmed();
        process["distance_internal"] = activeQuery.value(8).toInt();
        process["distance_external"] = activeQuery.value(9).toInt();
        process["variance"] = activeQuery.value(10).toInt();
        process["maximum_paths"] = activeQuery.value(11).toInt();
        process["stub_enabled"] = activeQuery.value(12).toInt();
        process["stub_options"] = activeQuery.value(13).toString().trimmed();
        process["stub_leak_map"] = activeQuery.value(14).toString().trimmed();
        process["action"] = activeQuery.value(15).toInt();
        process["action_Cfg"] = activeQuery.value(16).toString().trimmed();
        process["success"] = activeQuery.value(17).toInt();
        activeProcessesById.insert(eigrpId, process);
        activeProcessIds.append(eigrpId);
    }

    QSet<int> usedAsNumbers;
    QSet<int> payloadEigrpIds;
    QVariantList keyChainsPayload;
    bool keyChainsSeen = false;
    for (const QVariant &processVar : processes) {
        const QVariantMap process = processVar.toMap();
        const int eigrpId           = process.value("eigrp_id").toInt();
        const int asNumber          = process.value("as_number").toInt();
        const QString routerId      = process.value("router_id").toString().trimmed();
        const int timersActiveTime  = process.value("timers_active_time").toInt();
        const int bfdAllInterfaces  = process.value("bfd_all_interfaces").toBool() ? 1 : 0;
        const int autoSummary       = process.value("auto_summary").toBool() ? 1 : 0;
        const int passiveDefault    = process.value("passive_default").toBool() ? 1 : 0;
        QString metricWeights       = process.value("metric_weights").toString().trimmed();
        const int distanceInternal  = process.value("distance_internal").toInt();
        const int distanceExternal  = process.value("distance_external").toInt();
        const int variance          = process.value("variance").toInt();
        const int maximumPaths      = process.value("maximum_paths").toInt();
        const int stubEnabled       = process.value("stub_enabled").toBool() ? 1 : 0;
        const QString stubOptions   = process.value("stub_options").toString().trimmed();
        const QString stubLeakMap   = process.value("stub_leak_map").toString().trimmed();
        const QString actionCfg     = actionCfgForProcess(process);
        const QVariantList networks = process.value("networks").toList();
        const QVariantList interfaceSettings = process.value("interface_settings").toList();
        const QVariantList passiveInterfaces = process.value("passive_interfaces").toList();
        const QVariantList distributeLists = process.value("distribute_lists").toList();
        const QVariantList offsetLists = process.value("offset_lists").toList();
        const QVariantList redistribute = process.value("redistribute").toList();
        const QVariantList keyChains = process.value("key_chains").toList();
        if (!keyChainsSeen && process.contains("key_chains")) {
            keyChainsPayload = keyChains;
            keyChainsSeen = true;
        }

        if (asNumber < 1 || asNumber > 65535) {
            setLastError(QStringLiteral("EIGRP AS number must be between 1 and 65535"));
            m_db.rollback();
            return false;
        }

        if (usedAsNumbers.contains(asNumber)) {
            setLastError(QStringLiteral("Duplicate EIGRP AS number in payload"));
            m_db.rollback();
            return false;
        }
        usedAsNumbers.insert(asNumber);
        if (eigrpId > 0)
            payloadEigrpIds.insert(eigrpId);

        if (!routerId.isEmpty() && !isValidIpv4(routerId)) {
            setLastError(QStringLiteral("EIGRP router-id must be a valid IPv4 address"));
            m_db.rollback();
            return false;
        }

        if (distanceInternal < 0 || distanceInternal > 255) {
            setLastError(QStringLiteral("EIGRP internal distance must be between 0 and 255"));
            m_db.rollback();
            return false;
        }

        if (distanceExternal < 0 || distanceExternal > 255) {
            setLastError(QStringLiteral("EIGRP external distance must be between 0 and 255"));
            m_db.rollback();
            return false;
        }

        if (metricWeights.isEmpty())
            metricWeights = QStringLiteral("0 1 0 1 0 0");

        if (!isValidMetricWeights(metricWeights)) {
            setLastError(QStringLiteral("EIGRP metric-weights must be in format: 0 k1 k2 k3 k4 k5"));
            m_db.rollback();
            return false;
        }

        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard  = network.value("wildcard").toString().trimmed();
            const QString interfaceName = network.value("interface_name").toString().trimmed();

            if (networkIp.isEmpty() && wildcard.isEmpty() && interfaceName.isEmpty())
                continue;

            if (networkIp.isEmpty()) {
                setLastError(QStringLiteral("EIGRP network must include network"));
                m_db.rollback();
                return false;
            }

            if (!isValidIpv4(networkIp) || (!wildcard.isEmpty() && !isValidIpv4(wildcard))) {
                setLastError(QStringLiteral("EIGRP network and wildcard must be valid IPv4 values"));
                m_db.rollback();
                return false;
            }
        }

        const bool hasExistingProcess = eigrpId > 0 && activeProcessesById.contains(eigrpId);
        const int action = 15;
        int targetEigrpId = eigrpId;

        if (hasExistingProcess) {
            if (!updateProcessOptions(targetEigrpId,
                                      asNumber,
                                      routerId,
                                      timersActiveTime,
                                      bfdAllInterfaces,
                                      autoSummary,
                                      passiveDefault,
                                      metricWeights,
                                      distanceInternal,
                                      distanceExternal,
                                      variance,
                                      maximumPaths,
                                      stubEnabled,
                                      stubOptions,
                                      stubLeakMap,
                                      action,
                                      actionCfg)) {
                m_db.rollback();
                return false;
            }

            if (!saveNetworks(targetEigrpId, networks)
                || !saveInterfaceSettings(targetEigrpId, interfaceSettings)
                || !savePassiveInterfaces(targetEigrpId, passiveInterfaces)
                || !saveDistributeLists(targetEigrpId, distributeLists)
                || !saveOffsetLists(targetEigrpId, offsetLists)
                || !saveRedistribute(targetEigrpId, redistribute)) {
                m_db.rollback();
                return false;
            }
            continue;
        }

        targetEigrpId = insertProcess(normalizedHost,
                                      asNumber,
                                      routerId,
                                      timersActiveTime,
                                      bfdAllInterfaces,
                                      autoSummary,
                                      passiveDefault,
                                      metricWeights,
                                      distanceInternal,
                                      distanceExternal,
                                      variance,
                                      maximumPaths,
                                      stubEnabled,
                                      stubOptions,
                                      stubLeakMap,
                                      action,
                                      actionCfg,
                                      0);
        if (targetEigrpId <= 0) {
            m_db.rollback();
            return false;
        }

        if (!saveNetworks(targetEigrpId, networks)
            || !saveInterfaceSettings(targetEigrpId, interfaceSettings)
            || !savePassiveInterfaces(targetEigrpId, passiveInterfaces)
            || !saveDistributeLists(targetEigrpId, distributeLists)
            || !saveOffsetLists(targetEigrpId, offsetLists)
            || !saveRedistribute(targetEigrpId, redistribute)) {
            m_db.rollback();
            return false;
        }
    }

    if (!saveKeyChains(normalizedHost, keyChainsPayload)) {
        m_db.rollback();
        return false;
    }

    QList<int> removedProcessIds;
    for (int activeProcessId : activeProcessIds) {
        if (!payloadEigrpIds.contains(activeProcessId))
            removedProcessIds.append(activeProcessId);
    }

    if (!removedProcessIds.isEmpty()) {
        if (!markNetworksByProcessIds(removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("eigrp_interface_settings"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("eigrp_passive_interfaces"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("eigrp_distribute_lists"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("eigrp_offset_lists"), removedProcessIds, -1)
            || !markChildRowsByProcessIds(QStringLiteral("eigrp_redistribute"), removedProcessIds, -1)
            || !markProcessesByIds(removedProcessIds, -1)) {
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

bool EigrpRoutingRepository::clearByHost(const QString &host)
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
        "SELECT eigrp_id "
        "FROM eigrp_processes "
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

    if (!markNetworksByProcessIds(activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("eigrp_interface_settings"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("eigrp_passive_interfaces"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("eigrp_distribute_lists"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("eigrp_offset_lists"), activeProcessIds, -1)
        || !markChildRowsByProcessIds(QStringLiteral("eigrp_redistribute"), activeProcessIds, -1)
        || !markKeyChainsByHost(normalizedHost, -1)) {
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

bool EigrpRoutingRepository::markProcessesByIds(const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE eigrp_processes "
        "SET success = ? "
        "WHERE eigrp_id = ? "
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

bool EigrpRoutingRepository::markProcessesByHost(const QString &host, int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE eigrp_processes "
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

bool EigrpRoutingRepository::markNetworksByIds(const QList<int> &networkIds, int success)
{
    if (networkIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE eigrp_networks "
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

bool EigrpRoutingRepository::markNetworksByProcessIds(const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE eigrp_networks "
        "SET success = ? "
        "WHERE eigrp_id = ? "
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

bool EigrpRoutingRepository::markChildRowsByProcessIds(const QString &table, const QList<int> &processIds, int success)
{
    if (processIds.isEmpty())
        return true;

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("UPDATE %1 SET success = ? WHERE eigrp_id = ? AND success != -1;").arg(table));
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

bool EigrpRoutingRepository::markKeyChainsByHost(const QString &host, int success)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE eigrp_key_chains SET success = ? WHERE host = ? AND success != -1;");
    query.addBindValue(success);
    query.addBindValue(host);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool EigrpRoutingRepository::updateProcessOptions(int eigrpId,
                                                  int asNumber,
                                                  const QString &routerId,
                                                  int timersActiveTime,
                                                  int bfdAllInterfaces,
                                                  int autoSummary,
                                                  int passiveDefault,
                                                  const QString &metricWeights,
                                                  int distanceInternal,
                                                  int distanceExternal,
                                                  int variance,
                                                  int maximumPaths,
                                                  int stubEnabled,
                                                  const QString &stubOptions,
                                                  const QString &stubLeakMap,
                                                  int action,
                                                  const QString &actionCfg)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE eigrp_processes "
        "SET as_number = ?, router_id = ?, timers_active_time = ?, bfd_all_interfaces = ?, "
        "auto_summary = ?, passive_default = ?, metric_weights = ?, distance_internal = ?, "
        "distance_external = ?, variance = ?, maximum_paths = ?, stub_enabled = ?, "
        "stub_options = ?, stub_leak_map = ?, action = ?, action_Cfg = ?, success = 0 "
        "WHERE eigrp_id = ? AND success != -1;"
        );
    query.addBindValue(asNumber);
    query.addBindValue(nullableString(routerId));
    query.addBindValue(nullableInt(timersActiveTime));
    query.addBindValue(bfdAllInterfaces);
    query.addBindValue(autoSummary);
    query.addBindValue(passiveDefault);
    query.addBindValue(metricWeights);
    query.addBindValue(nullableInt(distanceInternal));
    query.addBindValue(nullableInt(distanceExternal));
    query.addBindValue(nullableInt(variance));
    query.addBindValue(nullableInt(maximumPaths));
    query.addBindValue(stubEnabled);
    query.addBindValue(nullableString(stubOptions));
    query.addBindValue(nullableString(stubLeakMap));
    query.addBindValue(action);
    query.addBindValue(actionCfg);
    query.addBindValue(eigrpId);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

int EigrpRoutingRepository::insertProcess(const QString &host,
                                          int asNumber,
                                          const QString &routerId,
                                          int timersActiveTime,
                                          int bfdAllInterfaces,
                                          int autoSummary,
                                          int passiveDefault,
                                          const QString &metricWeights,
                                          int distanceInternal,
                                          int distanceExternal,
                                          int variance,
                                          int maximumPaths,
                                          int stubEnabled,
                                          const QString &stubOptions,
                                          const QString &stubLeakMap,
                                          int action,
                                          const QString &actionCfg,
                                          int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT OR REPLACE INTO eigrp_processes "
        "(host, as_number, router_id, timers_active_time, bfd_all_interfaces, auto_summary, "
        "passive_default, metric_weights, distance_internal, distance_external, variance, maximum_paths, "
        "stub_enabled, stub_options, stub_leak_map, action, action_Cfg, success) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        );
    query.addBindValue(host);
    query.addBindValue(asNumber);
    query.addBindValue(nullableString(routerId));
    query.addBindValue(nullableInt(timersActiveTime));
    query.addBindValue(bfdAllInterfaces);
    query.addBindValue(autoSummary);
    query.addBindValue(passiveDefault);
    query.addBindValue(metricWeights);
    query.addBindValue(nullableInt(distanceInternal));
    query.addBindValue(nullableInt(distanceExternal));
    query.addBindValue(nullableInt(variance));
    query.addBindValue(nullableInt(maximumPaths));
    query.addBindValue(stubEnabled);
    query.addBindValue(nullableString(stubOptions));
    query.addBindValue(nullableString(stubLeakMap));
    query.addBindValue(action);
    query.addBindValue(actionCfg);
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return 0;
    }
    return query.lastInsertId().toInt();
}

bool EigrpRoutingRepository::insertNetwork(int eigrpId,
                                           const QString &network,
                                           const QString &wildcard,
                                           const QString &interfaceName,
                                           int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT OR REPLACE INTO eigrp_networks (eigrp_id, network, wildcard, interface_name, success) "
        "VALUES (?, ?, ?, ?, ?);"
        );
    query.addBindValue(eigrpId);
    query.addBindValue(network.trimmed());
    query.addBindValue(nullableString(wildcard));
    query.addBindValue(nullableString(interfaceName));
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool EigrpRoutingRepository::saveNetworks(int eigrpId, const QVariantList &items)
{
    if (!markNetworksByProcessIds({ eigrpId }, -1))
        return false;

    QSet<QString> seen;
    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString network = item.value("network").toString().trimmed();
        const QString wildcard = item.value("wildcard").toString().trimmed();
        const QString interfaceName = item.value("interface_name").toString().trimmed();
        if (network.isEmpty())
            continue;

        const QString key = networkKey(network, wildcard, interfaceName);
        if (seen.contains(key))
            continue;
        seen.insert(key);

        if (!insertNetwork(eigrpId, network, wildcard, interfaceName, 0))
            return false;
    }
    return true;
}

bool EigrpRoutingRepository::saveInterfaceSettings(int eigrpId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("eigrp_interface_settings"), { eigrpId }, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString interfaceName = item.value("interface_name").toString().trimmed();
        if (interfaceName.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO eigrp_interface_settings "
            "(eigrp_id, interface_name, bandwidth, delay, hello_interval, hold_time, auth_key_chain, "
            "summary_ip, summary_mask, split_horizon, bandwidth_percent, next_hop_self, bfd, "
            "bfd_tx, bfd_rx, bfd_multiplier, success) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
            );
        query.addBindValue(eigrpId);
        query.addBindValue(interfaceName);
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("bandwidth"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("delay"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("hello_interval"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("hold_time"))));
        query.addBindValue(nullableString(item.value("auth_key_chain").toString()));
        query.addBindValue(nullableString(item.value("summary_ip").toString()));
        query.addBindValue(nullableString(item.value("summary_mask").toString()));
        query.addBindValue(item.contains("split_horizon") ? QVariant(item.value("split_horizon").toBool() ? 1 : 0) : QVariant(QMetaType::fromType<int>()));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("bandwidth_percent"))));
        query.addBindValue(item.value("next_hop_self").toBool() ? 1 : 0);
        query.addBindValue(item.value("bfd").toBool() ? 1 : 0);
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("bfd_tx"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("bfd_rx"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("bfd_multiplier"))));
        query.addBindValue(0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool EigrpRoutingRepository::savePassiveInterfaces(int eigrpId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("eigrp_passive_interfaces"), { eigrpId }, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString interfaceName = item.value("interface_name").toString().trimmed();
        if (interfaceName.isEmpty())
            continue;
        const QString mode = item.value("mode").toString().trimmed() == QStringLiteral("no-passive")
                                 ? QStringLiteral("no-passive")
                                 : QStringLiteral("passive");

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO eigrp_passive_interfaces (eigrp_id, interface_name, mode, success) "
            "VALUES (?, ?, ?, ?);"
            );
        query.addBindValue(eigrpId);
        query.addBindValue(interfaceName);
        query.addBindValue(mode);
        query.addBindValue(0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool EigrpRoutingRepository::saveDistributeLists(int eigrpId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("eigrp_distribute_lists"), { eigrpId }, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString listName = item.value("list_name").toString().trimmed();
        if (listName.isEmpty())
            continue;
        const QString direction = item.value("direction").toString().trimmed() == QStringLiteral("out")
                                      ? QStringLiteral("out")
                                      : QStringLiteral("in");

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO eigrp_distribute_lists (eigrp_id, list_name, direction, interface_name, success) "
            "VALUES (?, ?, ?, ?, ?);"
            );
        query.addBindValue(eigrpId);
        query.addBindValue(listName);
        query.addBindValue(direction);
        query.addBindValue(nullableString(item.value("interface_name").toString()));
        query.addBindValue(0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool EigrpRoutingRepository::saveOffsetLists(int eigrpId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("eigrp_offset_lists"), { eigrpId }, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString listName = item.value("list_name").toString().trimmed();
        const int value = optionalInt(item, QStringLiteral("value"));
        if (listName.isEmpty() || value <= 0)
            continue;
        const QString direction = item.value("direction").toString().trimmed() == QStringLiteral("out")
                                      ? QStringLiteral("out")
                                      : QStringLiteral("in");

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO eigrp_offset_lists (eigrp_id, list_name, direction, value, interface_name, success) "
            "VALUES (?, ?, ?, ?, ?, ?);"
            );
        query.addBindValue(eigrpId);
        query.addBindValue(listName);
        query.addBindValue(direction);
        query.addBindValue(value);
        query.addBindValue(nullableString(item.value("interface_name").toString()));
        query.addBindValue(0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool EigrpRoutingRepository::saveRedistribute(int eigrpId, const QVariantList &items)
{
    if (!markChildRowsByProcessIds(QStringLiteral("eigrp_redistribute"), { eigrpId }, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString protocol = item.value("protocol").toString().trimmed();
        if (protocol.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO eigrp_redistribute "
            "(eigrp_id, protocol, route_map, metric_bw, metric_delay, metric_reliability, metric_load, metric_mtu, success) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
            );
        query.addBindValue(eigrpId);
        query.addBindValue(protocol);
        query.addBindValue(nullableString(item.value("route_map").toString()));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("metric_bw"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("metric_delay"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("metric_reliability"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("metric_load"))));
        query.addBindValue(nullableInt(optionalInt(item, QStringLiteral("metric_mtu"))));
        query.addBindValue(0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool EigrpRoutingRepository::saveKeyChains(const QString &host, const QVariantList &items)
{
    if (!markKeyChainsByHost(host, -1))
        return false;

    for (const QVariant &itemVar : items) {
        const QVariantMap item = itemVar.toMap();
        const QString chainName = item.value("chain_name").toString().trimmed();
        const int keyId = optionalInt(item, QStringLiteral("key_id"));
        const QString keyString = item.value("key_string").toString().trimmed();
        if (chainName.isEmpty() || keyId <= 0 || keyString.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(
            "INSERT OR REPLACE INTO eigrp_key_chains "
            "(host, chain_name, key_id, key_string, accept_lifetime, send_lifetime, success) "
            "VALUES (?, ?, ?, ?, ?, ?, ?);"
            );
        query.addBindValue(host);
        query.addBindValue(chainName);
        query.addBindValue(keyId);
        query.addBindValue(keyString);
        query.addBindValue(nullableString(item.value("accept_lifetime").toString()));
        query.addBindValue(nullableString(item.value("send_lifetime").toString()));
        query.addBindValue(0);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}
