#ifndef ROUTEMAPREPOSITORY_H
#define ROUTEMAPREPOSITORY_H

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>

class RouteMapRepository : public QObject
{
    Q_OBJECT
public:
    explicit RouteMapRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVariantList getRouteMapEntries(const QString &host);
    bool addRouteMapEntry(const QString &host,
                          const QString &routeMapName,
                          const QString &description,
                          int sequence,
                          const QString &action,
                          const QString &natAclName);
    bool deleteRouteMapEntry(int entryId);

    QString lastError() const;

private:
    int getOrCreateRouteMapId(const QString &host,
                              const QString &routeMapName,
                              const QString &description);
    int findNatAclId(const QString &host, const QString &natAclName);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // ROUTEMAPREPOSITORY_H
