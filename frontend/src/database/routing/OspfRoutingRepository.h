#ifndef OSPFROUTINGREPOSITORY_H
#define OSPFROUTINGREPOSITORY_H

#include <QList>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class OspfRoutingRepository
{
public:
    explicit OspfRoutingRepository(const QSqlDatabase &database);

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
    bool markAreaRangesByProcessIds(const QList<int> &processIds, int success);
    bool updateProcessOptions(int ospfId,
                              int processId,
                              const QString &routerId,
                              int referenceBandwidth,
                              int passiveDefault,
                              int defaultOriginate,
                              int defaultOriginateAlways);
    int insertProcess(const QString &host,
                      int processId,
                      const QString &routerId,
                      int referenceBandwidth,
                      int passiveDefault,
                      int defaultOriginate,
                      int defaultOriginateAlways,
                      int success);
    bool insertNetwork(int ospfId,
                       const QString &network,
                       const QString &wildcard,
                       const QString &area,
                       int success);
    bool saveDistance(int ospfId, const QVariantMap &distance);
    bool saveTuning(int ospfId, const QVariantMap &tuning);
    bool saveAreas(int ospfId, const QVariantList &areas);
    bool saveRedistribute(int ospfId, const QVariantList &items);
    bool savePassiveInterfaces(int ospfId, const QVariantList &items);
    bool saveInterfaceSettings(int ospfId, const QVariantList &items);
    void setLastError(const QString &message);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // OSPFROUTINGREPOSITORY_H
