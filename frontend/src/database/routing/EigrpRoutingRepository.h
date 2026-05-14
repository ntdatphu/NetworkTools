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
    bool updateProcessOptions(int eigrpId,
                              int autoSummary,
                              int passiveDefault,
                              const QString &metricWeights,
                              int distanceInternal,
                              int distanceExternal,
                              int action);
    int insertProcess(const QString &host,
                      int asNumber,
                      const QString &routerId,
                      int autoSummary,
                      int passiveDefault,
                      const QString &metricWeights,
                      int distanceInternal,
                      int distanceExternal,
                      int action,
                      int success);
    bool insertNetwork(int eigrpId,
                       const QString &network,
                       const QString &wildcard,
                       int success);
    bool isValidMetricWeights(const QString &metricWeights) const;
    void setLastError(const QString &message);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // EIGRPROUTINGREPOSITORY_H