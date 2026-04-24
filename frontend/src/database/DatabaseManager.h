#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class DatabaseConnection;
class DeviceRepository;
class DhcpPoolRepository;
class ExcludedAddressRepository;
class RoutingStaticRepository;
class OspfRoutingRepository;
class EigrpRoutingRepository;
class BackupService;

class DatabaseManager : public QObject
{
    Q_OBJECT

public:
    explicit DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager() override;

    bool initializeDatabase();

    Q_INVOKABLE bool addDevice(const QString &host,
                               const QString &deviceName,
                               const QString &method,
                               const QString &portText,
                               const QString &username,
                               const QString &password);

    Q_INVOKABLE bool deleteDevice(const QString &host);
    Q_INVOKABLE bool updateDeviceSuccess(const QString &host, int success);

    Q_INVOKABLE bool updateDevice(const QString &host,
                                  const QString &deviceName,
                                  const QString &method,
                                  const QString &portText,
                                  const QString &username,
                                  const QString &password);

    Q_INVOKABLE QVariantMap getDeviceByHost(const QString &host);

    Q_INVOKABLE QVariantList getDevices();

    Q_INVOKABLE bool createFoldersFromDevices();

    Q_INVOKABLE bool addYangcfg(const QString &host,
                                const QString &username,
                                const QString &password,
                                int success = 0);

    // ── DHCP Pool ──────────────────────────────────────────────────────
    Q_INVOKABLE bool addDhcpPool(const QString &host,
                                 const QString &pool,
                                 const QString &network,
                                 const QString &subnetmask,
                                 const QString &defaut,
                                 const QString &dns);

    Q_INVOKABLE bool deleteDhcpPool(int dhcpId);

    Q_INVOKABLE QVariantList getDhcpPools(const QString &host);

    // ── Excluded Address ───────────────────────────────────────────────
    Q_INVOKABLE bool addExcludedAddress(const QString &host,
                                        const QString &startIp,
                                        const QString &endIp);

    Q_INVOKABLE bool deleteExcludedAddress(int exId);

    Q_INVOKABLE QVariantList getExcludedAddresses(const QString &host);

    // ── Routing Static/Default ────────────────────────────────────────
    Q_INVOKABLE QVariantMap getStaticRouting(const QString &host);
    Q_INVOKABLE bool saveStaticRouting(const QString &host,
                                       const QString &defaultRoute,
                                       const QVariantList &routes);
    Q_INVOKABLE bool clearStaticRouting(const QString &host);

    // ── Routing OSPF ──────────────────────────────────────────────────
    Q_INVOKABLE QVariantMap getOspfRouting(const QString &host);
    Q_INVOKABLE bool saveOspfRouting(const QString &host,
                                     const QVariantList &processes);
    Q_INVOKABLE bool clearOspfRouting(const QString &host);

    // ── Routing EIGRP ─────────────────────────────────────────────────
    Q_INVOKABLE QVariantMap getEigrpRouting(const QString &host);
    Q_INVOKABLE bool saveEigrpRouting(const QString &host,
                                      const QVariantList &processes);
    Q_INVOKABLE bool clearEigrpRouting(const QString &host);

private:
    DatabaseConnection *m_connection;
    DeviceRepository *m_deviceRepository;
    DhcpPoolRepository *m_dhcpPoolRepository;
    ExcludedAddressRepository *m_excludedAddressRepository;
    RoutingStaticRepository *m_routingStaticRepository;
    OspfRoutingRepository *m_ospfRoutingRepository;
    EigrpRoutingRepository *m_eigrpRoutingRepository;
    BackupService *m_backupService;
};

#endif // DATABASEMANAGER_H
