#ifndef DEVICEREPOSITORY_H
#define DEVICEREPOSITORY_H

#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QString>

class DeviceRepository
{
public:
    explicit DeviceRepository(const QSqlDatabase &database);

    bool addDevice(const QString &host,
                   const QString &deviceName,
                   const QString &method,
                   const QString &portText,
                   const QString &username,
                   const QString &password);

    bool deleteDevice(const QString &host);
    bool updateDeviceSuccess(const QString &host, int success);
    bool addYangcfg(const QString &host,
                    const QString &username,
                    const QString &password,
                    int success);
    bool updateDevice(const QString &host,
                      const QString &deviceName,
                      const QString &method,
                      const QString &portText,
                      const QString &username,
                      const QString &password);

    QVariantMap getDeviceByHost(const QString &host);
    QVariantList getDevices();
    QStringList getActiveHosts();

private:
    QSqlDatabase m_db;
};

#endif // DEVICEREPOSITORY_H
