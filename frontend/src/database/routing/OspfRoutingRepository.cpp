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
        "SELECT ospf_id, process_id, router_id, ad, default_info, auto_summary, action, success "
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
        process["ospf_id"] = ospfId;
        process["process_id"] = processQuery.value(1).toInt();
        process["router_id"] = processQuery.value(2).toString();
        process["ad"] = processQuery.value(3).toInt();
        process["default_info"] = processQuery.value(4).toInt();
        process["auto_summary"] = processQuery.value(5).toInt();
        process["action"] = processQuery.value(6).toInt();
        process["success"] = processQuery.value(7).toInt();

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
            network["id"] = networkQuery.value(0).toInt();
            network["network"] = networkQuery.value(1).toString();
            network["wildcard"] = networkQuery.value(2).toString();
            network["area"] = networkQuery.value(3).toString();
            network["success"] = networkQuery.value(4).toInt();
            networks.append(network);
        }

        process["networks"] = networks;
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
        "SELECT ospf_id, process_id, router_id, ad, default_info, auto_summary, action, success "
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
        process["ospf_id"] = ospfId;
        process["process_id"] = activeQuery.value(1).toInt();
        process["router_id"] = activeQuery.value(2).toString().trimmed();
        process["ad"] = activeQuery.value(3).toInt();
        process["default_info"] = activeQuery.value(4).toInt();
        process["auto_summary"] = activeQuery.value(5).toInt();
        process["action"] = activeQuery.value(6).toInt();
        process["success"] = activeQuery.value(7).toInt();
        activeProcessesById.insert(ospfId, process);
        activeProcessIds.append(ospfId);
    }

    QSet<int> usedProcessIds;
    QSet<int> payloadOspfIds;
    for (const QVariant &processVar : processes) {
        const QVariantMap process = processVar.toMap();
        const int ospfId = process.value("ospf_id").toInt();
        const int processId = process.value("process_id").toInt();
        const QString routerId = process.value("router_id").toString().trimmed();
        int ad = process.value("ad").toInt();
        const int defaultInfo = process.value("default_info").toBool() ? 1 : 0;
        const int autoSummary = process.value("auto_summary").toBool() ? 1 : 0;
        const QVariantList networks = process.value("networks").toList();

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

        if (ad < 1 || ad > 255)
            ad = 110;

        int validNetworkCount = 0;
        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard = network.value("wildcard").toString().trimmed();
            const QString area = network.value("area").toString().trimmed();

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
        const QVariantMap activeProcess = hasExistingProcess ? activeProcessesById.value(ospfId) : QVariantMap();
        const bool defaultChanged = hasExistingProcess
            ? activeProcess.value("default_info").toInt() != defaultInfo
            : true;
        const bool autoChanged = hasExistingProcess
            ? activeProcess.value("auto_summary").toInt() != autoSummary
            : true;
        const int action = (defaultChanged ? 2 : 0) | (autoChanged ? 1 : 0);
        bool processChanged = true;
        int targetOspfId = ospfId;

        if (hasExistingProcess) {
            processChanged = activeProcess.value("process_id").toInt() != processId
                || activeProcess.value("router_id").toString().trimmed() != routerId
                || activeProcess.value("ad").toInt() != ad;
        }

        if (hasExistingProcess && !processChanged) {
            if (!updateProcessOptions(targetOspfId, defaultInfo, autoSummary, action)) {
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
                const QString wildcard = network.value("wildcard").toString().trimmed();
                const QString area = network.value("area").toString().trimmed();

                if (networkIp.isEmpty() || wildcard.isEmpty() || area.isEmpty()) {
                    setLastError(QStringLiteral("OSPF network must include network, wildcard, and area"));
                    m_db.rollback();
                    return false;
                }

                const QString key = networkKey(networkIp, wildcard, area);
                payloadNetworkKeys.insert(key);

                if (!activeNetworkIdsByKey.contains(key) && !insertNetwork(targetOspfId, networkIp, wildcard, area, 0)) {
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

            continue;
        }

        if (hasExistingProcess) {
            if (!markNetworksByProcessIds({targetOspfId}, -1)) {
                m_db.rollback();
                return false;
            }
            if (!markProcessesByIds({targetOspfId}, -1)) {
                m_db.rollback();
                return false;
            }
        }

        targetOspfId = insertProcess(normalizedHost,
                                     processId,
                                     routerId,
                                     ad,
                                     defaultInfo,
                                     autoSummary,
                                     3,
                                     0);
        if (targetOspfId <= 0) {
            m_db.rollback();
            return false;
        }

        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard = network.value("wildcard").toString().trimmed();
            const QString area = network.value("area").toString().trimmed();

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

bool OspfRoutingRepository::updateProcessOptions(int ospfId, int defaultInfo, int autoSummary, int action)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE ospf_processes "
        "SET default_info = ?, auto_summary = ?, action = ? "
        "WHERE ospf_id = ? "
        "AND success != -1;"
    );
    query.addBindValue(defaultInfo);
    query.addBindValue(autoSummary);
    query.addBindValue(action);
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
                                         int ad,
                                         int defaultInfo,
                                         int autoSummary,
                                         int action,
                                         int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO ospf_processes (host, process_id, router_id, ad, default_info, auto_summary, action, success) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
    );
    query.addBindValue(host);
    query.addBindValue(processId);
    query.addBindValue(routerId);
    query.addBindValue(ad);
    query.addBindValue(defaultInfo);
    query.addBindValue(autoSummary);
    query.addBindValue(action);
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
        "INSERT INTO ospf_networks (ospf_id, network, wildcard, area, success) "
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