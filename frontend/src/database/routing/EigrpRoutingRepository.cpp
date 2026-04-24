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

    QSqlQuery processQuery(m_db);
    processQuery.prepare(
        "SELECT eigrp_id, as_number, router_id, auto_summary, passive_default, metric_weights, action, success "
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
        process["auto_summary"] = processQuery.value(3).toInt();
        process["passive_default"] = processQuery.value(4).toInt();
        process["metric_weights"] = processQuery.value(5).toString();
        process["action"] = processQuery.value(6).toInt();
        process["success"] = processQuery.value(7).toInt();

        QSqlQuery networkQuery(m_db);
        networkQuery.prepare(
            "SELECT id, network, wildcard, success "
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
            network["id"] = networkQuery.value(0).toInt();
            network["network"] = networkQuery.value(1).toString();
            network["wildcard"] = networkQuery.value(2).toString();
            network["success"] = networkQuery.value(3).toInt();
            networks.append(network);
        }

        process["networks"] = networks;
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
        "SELECT eigrp_id, as_number, router_id, auto_summary, passive_default, metric_weights, action, success "
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
        process["auto_summary"] = activeQuery.value(3).toInt();
        process["passive_default"] = activeQuery.value(4).toInt();
        process["metric_weights"] = activeQuery.value(5).toString().trimmed();
        process["action"] = activeQuery.value(6).toInt();
        process["success"] = activeQuery.value(7).toInt();
        activeProcessesById.insert(eigrpId, process);
        activeProcessIds.append(eigrpId);
    }

    QSet<int> usedAsNumbers;
    QSet<int> payloadEigrpIds;
    for (const QVariant &processVar : processes) {
        const QVariantMap process = processVar.toMap();
        const int eigrpId = process.value("eigrp_id").toInt();
        const int asNumber = process.value("as_number").toInt();
        const QString routerId = process.value("router_id").toString().trimmed();
        const int autoSummary = process.value("auto_summary").toBool() ? 1 : 0;
        const int passiveDefault = process.value("passive_default").toBool() ? 1 : 0;
        QString metricWeights = process.value("metric_weights").toString().trimmed();
        const QVariantList networks = process.value("networks").toList();

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

        if (metricWeights.isEmpty())
            metricWeights = QStringLiteral("0 1 0 1 0 0");

        if (!isValidMetricWeights(metricWeights)) {
            setLastError(QStringLiteral("EIGRP metric-weights must be in format: 0 k1 k2 k3 k4 k5"));
            m_db.rollback();
            return false;
        }

        int validNetworkCount = 0;
        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard = network.value("wildcard").toString().trimmed();

            if (networkIp.isEmpty() && wildcard.isEmpty())
                continue;

            if (networkIp.isEmpty() || wildcard.isEmpty()) {
                setLastError(QStringLiteral("EIGRP network must include network and wildcard"));
                m_db.rollback();
                return false;
            }

            if (!isValidIpv4(networkIp) || !isValidIpv4(wildcard)) {
                setLastError(QStringLiteral("EIGRP network and wildcard must be valid IPv4 values"));
                m_db.rollback();
                return false;
            }

            ++validNetworkCount;
        }

        if (validNetworkCount == 0) {
            setLastError(QStringLiteral("Each EIGRP process must contain at least one network"));
            m_db.rollback();
            return false;
        }

        const bool hasExistingProcess = eigrpId > 0 && activeProcessesById.contains(eigrpId);
        const QVariantMap activeProcess = hasExistingProcess ? activeProcessesById.value(eigrpId) : QVariantMap();
        const bool autoChanged = hasExistingProcess
            ? activeProcess.value("auto_summary").toInt() != autoSummary
            : true;
        const bool passiveChanged = hasExistingProcess
            ? activeProcess.value("passive_default").toInt() != passiveDefault
            : true;
        const int action = (autoChanged ? 2 : 0) | (passiveChanged ? 1 : 0);
        bool processChanged = true;
        int targetEigrpId = eigrpId;

        if (hasExistingProcess) {
            processChanged = activeProcess.value("as_number").toInt() != asNumber
                || activeProcess.value("router_id").toString().trimmed() != routerId
                || activeProcess.value("metric_weights").toString().trimmed() != metricWeights;
        }

        if (hasExistingProcess && !processChanged) {
            if (!updateProcessOptions(targetEigrpId,
                                      autoSummary,
                                      passiveDefault,
                                      metricWeights,
                                      action)) {
                m_db.rollback();
                return false;
            }

            QMap<QString, int> activeNetworkIdsByKey;
            QSqlQuery activeNetworksQuery(m_db);
            activeNetworksQuery.prepare(
                "SELECT id, network, wildcard "
                "FROM eigrp_networks "
                "WHERE eigrp_id = ? "
                "AND success != -1;"
            );
            activeNetworksQuery.addBindValue(targetEigrpId);
            if (!activeNetworksQuery.exec()) {
                setLastError(activeNetworksQuery.lastError().text());
                m_db.rollback();
                return false;
            }

            while (activeNetworksQuery.next()) {
                activeNetworkIdsByKey.insert(
                    networkKey(activeNetworksQuery.value(1).toString(),
                               activeNetworksQuery.value(2).toString()),
                    activeNetworksQuery.value(0).toInt());
            }

            QSet<QString> payloadNetworkKeys;
            for (const QVariant &networkVar : networks) {
                const QVariantMap network = networkVar.toMap();
                const QString networkIp = network.value("network").toString().trimmed();
                const QString wildcard = network.value("wildcard").toString().trimmed();

                if (networkIp.isEmpty() || wildcard.isEmpty()) {
                    setLastError(QStringLiteral("EIGRP network must include network and wildcard"));
                    m_db.rollback();
                    return false;
                }

                const QString key = networkKey(networkIp, wildcard);
                payloadNetworkKeys.insert(key);

                if (!activeNetworkIdsByKey.contains(key)
                    && !insertNetwork(targetEigrpId, networkIp, wildcard, 0)) {
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
            if (!markNetworksByProcessIds({targetEigrpId}, -1)) {
                m_db.rollback();
                return false;
            }
            if (!markProcessesByIds({targetEigrpId}, -1)) {
                m_db.rollback();
                return false;
            }
        }

        targetEigrpId = insertProcess(normalizedHost,
                                      asNumber,
                                      routerId,
                                      autoSummary,
                                      passiveDefault,
                                      metricWeights,
                                      3,
                                      0);
        if (targetEigrpId <= 0) {
            m_db.rollback();
            return false;
        }

        for (const QVariant &networkVar : networks) {
            const QVariantMap network = networkVar.toMap();
            const QString networkIp = network.value("network").toString().trimmed();
            const QString wildcard = network.value("wildcard").toString().trimmed();

            if (networkIp.isEmpty() || wildcard.isEmpty()) {
                setLastError(QStringLiteral("EIGRP network must include network and wildcard"));
                m_db.rollback();
                return false;
            }

            if (!insertNetwork(targetEigrpId, networkIp, wildcard, 0)) {
                m_db.rollback();
                return false;
            }
        }
    }

    QList<int> removedProcessIds;
    for (int activeProcessId : activeProcessIds) {
        if (!payloadEigrpIds.contains(activeProcessId))
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

bool EigrpRoutingRepository::updateProcessOptions(int eigrpId,
                                                  int autoSummary,
                                                  int passiveDefault,
                                                  const QString &metricWeights,
                                                  int action)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE eigrp_processes "
        "SET auto_summary = ?, passive_default = ?, metric_weights = ?, action = ? "
        "WHERE eigrp_id = ? "
        "AND success != -1;"
    );
    query.addBindValue(autoSummary);
    query.addBindValue(passiveDefault);
    query.addBindValue(metricWeights);
    query.addBindValue(action);
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
                                          int autoSummary,
                                          int passiveDefault,
                                          const QString &metricWeights,
                                          int action,
                                          int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO eigrp_processes (host, as_number, router_id, auto_summary, passive_default, metric_weights, action, success) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
    );
    query.addBindValue(host);
    query.addBindValue(asNumber);
    query.addBindValue(routerId);
    query.addBindValue(autoSummary);
    query.addBindValue(passiveDefault);
    query.addBindValue(metricWeights);
    query.addBindValue(action);
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
                                           int success)
{
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO eigrp_networks (eigrp_id, network, wildcard, success) "
        "VALUES (?, ?, ?, ?);"
    );
    query.addBindValue(eigrpId);
    query.addBindValue(network);
    query.addBindValue(wildcard);
    query.addBindValue(success);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}
