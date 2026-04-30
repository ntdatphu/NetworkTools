#ifndef ROUTINGSTATICREPOSITORY_H
#define ROUTINGSTATICREPOSITORY_H

#include <QList>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class RoutingStaticRepository
{
public:
    explicit RoutingStaticRepository(const QSqlDatabase &database);

    QVariantMap getByHost(const QString &host);
    bool saveByHost(const QString &host,
                    const QString &defaultRoute,
                    const QVariantList &routes);
    bool clearByHost(const QString &host);

    QString lastError() const;

private:
    bool markDefaultByHost(const QString &host, int success);
    bool markStaticByIds(const QList<int> &ids, int success);
    bool insertDefault(const QString &host, const QString &nextHop, int success);
    bool insertStatic(const QString &host,
                      const QString &network,
                      const QString &mask,
                      const QString &nextHop,
                      int ad,
                      int success);
    bool appendRemovedStaticRowsToText(const QString &host, const QVariantList &removedRows);
    void setLastError(const QString &message);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // ROUTINGSTATICREPOSITORY_H
