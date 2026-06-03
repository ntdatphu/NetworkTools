#ifndef EIGRPROUTINGREPOSITORY_H
#define EIGRPROUTINGREPOSITORY_H

#include <QList>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class EigrpRoutingRepository
{
public:
    explicit EigrpRoutingRepository(const QSqlDatabase &database);

    QVariantMap getByHost(const QString &host);
    bool saveByHost(const QString &host, const QVariantList &processes);
    bool clearByHost(const QString &host);

    QString lastError() const;

private:
    bool markProcessesByIds(const QList<int> &processIds, int success);
    bool markProcessesByHost(const QString &host, int success);
    bool markNetworksByIds(const QList<int> &networkIds, int success);
    bool markNetworksByProcessIds(const QList<int> &processIds, int success);
    bool markChildRowsByProcessIds(const QString &table, const QList<int> &processIds, int success);
    bool markKeyChainsByHost(const QString &host, int success);
    bool updateProcessOptions(int eigrpId,
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
                              const QString &actionCfg);
    int insertProcess(const QString &host,
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
                      int success);
    bool insertNetwork(int eigrpId,
                       const QString &network,
                       const QString &wildcard,
                       const QString &interfaceName,
                       int success);
    bool saveNetworks(int eigrpId, const QVariantList &items);
    bool saveInterfaceSettings(int eigrpId, const QVariantList &items);
    bool savePassiveInterfaces(int eigrpId, const QVariantList &items);
    bool saveDistributeLists(int eigrpId, const QVariantList &items);
    bool saveOffsetLists(int eigrpId, const QVariantList &items);
    bool saveRedistribute(int eigrpId, const QVariantList &items);
    bool saveKeyChains(const QString &host, const QVariantList &items);
    bool isValidMetricWeights(const QString &metricWeights) const;
    void setLastError(const QString &message);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // EIGRPROUTINGREPOSITORY_H
