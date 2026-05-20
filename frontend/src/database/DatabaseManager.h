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
class InterfaceRepository;
class NatRepository;
class NatAclRepository;
class RouteMapRepository;
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

    Q_INVOKABLE QVariantList getRouterInterfaces(const QString &host);
    Q_INVOKABLE QVariantMap getRouterInterfaceByName(const QString &host,
                                                     const QString &interfaceName);
    Q_INVOKABLE bool saveRouterInterface(const QVariantMap &data);
    Q_INVOKABLE bool deleteRouterInterface(int ifaceId);

    // ── NAT ───────────────────────────────────────────────────────────
    Q_INVOKABLE QVariantList getNatInterfaces(const QString &host);
    Q_INVOKABLE bool addNatInterface(const QString &host,
                                     const QString &interfaceName,
                                     const QString &direction);
    Q_INVOKABLE bool deleteNatInterface(int natInterfaceId);

    Q_INVOKABLE QVariantList getNatPatRules(const QString &host);
    Q_INVOKABLE bool addNatPatRule(const QString &host,
                                   const QString &aclName,
                                   const QString &sourceType,
                                   const QString &sourceValue,
                                   bool overload);
    Q_INVOKABLE bool deleteNatPatRule(int natPatId);

    Q_INVOKABLE QVariantList getNatDynamicPools(const QString &host);
    Q_INVOKABLE bool addNatDynamicPool(const QString &host,
                                       const QString &poolName,
                                       const QString &startIp,
                                       const QString &endIp,
                                       const QString &netmask,
                                       const QString &aclName);
    Q_INVOKABLE bool deleteNatDynamicPool(int natDynamicId);

    Q_INVOKABLE QVariantList getNatStaticEntries(const QString &host);
    Q_INVOKABLE bool addNatStaticEntry(const QString &host,
                                       const QString &insideLocalIp,
                                       const QString &insideGlobalIp,
                                       const QString &protocol,
                                       const QString &localPort,
                                       const QString &globalPort);
    Q_INVOKABLE bool deleteNatStaticEntry(int natStaticId);

    // ── NAT ACL ───────────────────────────────────────────────────────
    Q_INVOKABLE QVariantList getNatAcls(const QString &host);
    Q_INVOKABLE bool addNatAcl(const QString &host,
                               const QString &aclName,
                               const QString &action,
                               const QString &sourceNetwork,
                               const QString &wildcard);
    Q_INVOKABLE bool deleteNatAcl(int natAclId);

    // Route Map
    Q_INVOKABLE QVariantList getNatRouteMapEntries(const QString &host);
    Q_INVOKABLE bool addNatRouteMapEntry(const QString &host,
                                         const QString &routeMapName,
                                         const QString &description,
                                         int sequence,
                                         const QString &action,
                                         const QString &natAclName);
    Q_INVOKABLE bool deleteNatRouteMapEntry(int entryId);

private:
    DatabaseConnection *m_connection;
    DeviceRepository *m_deviceRepository;
    DhcpPoolRepository *m_dhcpPoolRepository;
    ExcludedAddressRepository *m_excludedAddressRepository;
    RoutingStaticRepository *m_routingStaticRepository;
    OspfRoutingRepository *m_ospfRoutingRepository;
    EigrpRoutingRepository *m_eigrpRoutingRepository;
    InterfaceRepository *m_interfaceRepository;
    NatRepository *m_natRepository;
    NatAclRepository *m_natAclRepository;
    RouteMapRepository *m_routeMapRepository;
    BackupService *m_backupService;
};

#endif // DATABASEMANAGER_H
