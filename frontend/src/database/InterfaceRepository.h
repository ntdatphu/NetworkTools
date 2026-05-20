#ifndef INTERFACEREPOSITORY_H
#define INTERFACEREPOSITORY_H

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class InterfaceRepository : public QObject
{
    Q_OBJECT
public:
    explicit InterfaceRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVariantList getRouterInterfaces(const QString &host);
    QVariantMap getRouterInterfaceByName(const QString &host, const QString &interfaceName);
    bool saveRouterInterface(const QVariantMap &data);
    bool deleteRouterInterface(int ifaceId);

    QString lastError() const;

private:
    int findInterfaceId(const QString &host, const QString &interfaceName);
    QVariantMap getInterfaceById(int ifaceId);
    bool saveL3Details(int ifaceId, const QVariantMap &data);
    bool saveTunnelDetails(int ifaceId, const QVariantMap &data);
    bool saveWanDetails(int ifaceId, const QVariantMap &data);
    bool saveQosDetails(int ifaceId, const QVariantMap &data);
    bool clearTypedDetails(int ifaceId, const QString &keepKind);
    QVariant nullableString(const QVariantMap &data, const QString &key) const;
    QVariant nullableInt(const QVariantMap &data, const QString &key) const;

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // INTERFACEREPOSITORY_H
