#include "DatabaseManager.h"
#include "DatabaseConnection.h"
#include "DeviceRepository.h"
#include "DhcpPoolRepository.h"
#include "routing/EigrpRoutingRepository.h"
#include "ExcludedAddressRepository.h"
#include "routing/OspfRoutingRepository.h"
#include "routing/RoutingStaticRepository.h"
#include "BackupService.h"

#include <QDebug>

DatabaseManager::DatabaseManager(QObject *parent)
    : QObject(parent)
    , m_connection(new DatabaseConnection())
    , m_deviceRepository(nullptr)
    , m_dhcpPoolRepository(nullptr)
    , m_excludedAddressRepository(nullptr)
    , m_routingStaticRepository(nullptr)
    , m_ospfRoutingRepository(nullptr)
    , m_eigrpRoutingRepository(nullptr)
    , m_backupService(new BackupService())
{
}

DatabaseManager::~DatabaseManager()
{
    delete m_deviceRepository;
    delete m_dhcpPoolRepository;
    delete m_excludedAddressRepository;
    delete m_routingStaticRepository;
    delete m_ospfRoutingRepository;
    delete m_eigrpRoutingRepository;
    delete m_backupService;
    delete m_connection;
}

bool DatabaseManager::initializeDatabase()
{
    if (!m_connection->initializeDatabase()) {
        return false;
    }

    const QSqlDatabase db = m_connection->database();
    delete m_deviceRepository;
    delete m_dhcpPoolRepository;
    delete m_excludedAddressRepository;
    delete m_routingStaticRepository;
    delete m_ospfRoutingRepository;
    delete m_eigrpRoutingRepository;

    m_deviceRepository = new DeviceRepository(db);
    m_dhcpPoolRepository = new DhcpPoolRepository(db);
    m_excludedAddressRepository = new ExcludedAddressRepository(db);
    m_routingStaticRepository = new RoutingStaticRepository(db);
    m_ospfRoutingRepository = new OspfRoutingRepository(db);
    m_eigrpRoutingRepository = new EigrpRoutingRepository(db);

    return true;
}

bool DatabaseManager::addDevice(const QString &host,
                                const QString &deviceName,
                                const QString &method,
                                const QString &portText,
                                const QString &username,
                                const QString &password)
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_deviceRepository->addDevice(host, deviceName, method, portText, username, password);
}

bool DatabaseManager::deleteDevice(const QString &host)
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_deviceRepository->deleteDevice(host);
}

bool DatabaseManager::updateDeviceSuccess(const QString &host, int success)
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_deviceRepository->updateDeviceSuccess(host, success);
}

bool DatabaseManager::updateDevice(const QString &host,
                                   const QString &deviceName,
                                   const QString &method,
                                   const QString &portText,
                                   const QString &username,
                                   const QString &password)
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_deviceRepository->updateDevice(host, deviceName, method, portText, username, password);
}

QVariantMap DatabaseManager::getDeviceByHost(const QString &host)
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return {};
    }
    return m_deviceRepository->getDeviceByHost(host);
}

QVariantList DatabaseManager::getDevices()
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return {};
    }
    return m_deviceRepository->getDevices();
}

bool DatabaseManager::createFoldersFromDevices()
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const QStringList activeHosts = m_deviceRepository->getActiveHosts();
    return m_backupService->createFoldersFromHosts(activeHosts);
}

bool DatabaseManager::addYangcfg(const QString &host,
                                 const QString &username,
                                 const QString &password,
                                 int success)
{
    if (!m_deviceRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_deviceRepository->addYangcfg(host, username, password, success);
}

bool DatabaseManager::addDhcpPool(const QString &host,
                                  const QString &pool,
                                  const QString &network,
                                  const QString &subnetmask,
                                  const QString &defaut,
                                  const QString &dns)
{
    if (!m_dhcpPoolRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_dhcpPoolRepository->addDhcpPool(host, pool, network, subnetmask, defaut, dns);
}

bool DatabaseManager::deleteDhcpPool(int dhcpId)
{
    if (!m_dhcpPoolRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_dhcpPoolRepository->deleteDhcpPool(dhcpId);
}

QVariantList DatabaseManager::getDhcpPools(const QString &host)
{
    if (!m_dhcpPoolRepository) {
        qWarning() << "Database repositories are not initialized";
        return {};
    }
    return m_dhcpPoolRepository->getDhcpPools(host);
}

bool DatabaseManager::addExcludedAddress(const QString &host,
                                         const QString &startIp,
                                         const QString &endIp)
{
    if (!m_excludedAddressRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_excludedAddressRepository->addExcludedAddress(host, startIp, endIp);
}

bool DatabaseManager::deleteExcludedAddress(int exId)
{
    if (!m_excludedAddressRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    return m_excludedAddressRepository->deleteExcludedAddress(exId);
}

QVariantList DatabaseManager::getExcludedAddresses(const QString &host)
{
    if (!m_excludedAddressRepository) {
        qWarning() << "Database repositories are not initialized";
        return {};
    }
    return m_excludedAddressRepository->getExcludedAddresses(host);
}

QVariantMap DatabaseManager::getStaticRouting(const QString &host)
{
    if (!m_routingStaticRepository) {
        qWarning() << "Database repositories are not initialized";
        return {{"ok", false}, {"message", "Routing repository not initialized"}};
    }
    return m_routingStaticRepository->getByHost(host);
}

bool DatabaseManager::saveStaticRouting(const QString &host,
                                        const QString &defaultRoute,
                                        const QVariantList &routes)
{
    if (!m_routingStaticRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const bool ok = m_routingStaticRepository->saveByHost(host, defaultRoute, routes);
    if (!ok) {
        qWarning() << "saveStaticRouting failed:" << m_routingStaticRepository->lastError();
    }
    return ok;
}

bool DatabaseManager::clearStaticRouting(const QString &host)
{
    if (!m_routingStaticRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const bool ok = m_routingStaticRepository->clearByHost(host);
    if (!ok) {
        qWarning() << "clearStaticRouting failed:" << m_routingStaticRepository->lastError();
    }
    return ok;
}

QVariantMap DatabaseManager::getOspfRouting(const QString &host)
{
    if (!m_ospfRoutingRepository) {
        qWarning() << "Database repositories are not initialized";
        return {{"ok", false}, {"message", "OSPF repository not initialized"}};
    }
    return m_ospfRoutingRepository->getByHost(host);
}

bool DatabaseManager::saveOspfRouting(const QString &host,
                                      const QVariantList &processes)
{
    if (!m_ospfRoutingRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const bool ok = m_ospfRoutingRepository->saveByHost(host, processes);
    if (!ok) {
        qWarning() << "saveOspfRouting failed:" << m_ospfRoutingRepository->lastError();
    }
    return ok;
}

bool DatabaseManager::clearOspfRouting(const QString &host)
{
    if (!m_ospfRoutingRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const bool ok = m_ospfRoutingRepository->clearByHost(host);
    if (!ok) {
        qWarning() << "clearOspfRouting failed:" << m_ospfRoutingRepository->lastError();
    }
    return ok;
}

QVariantMap DatabaseManager::getEigrpRouting(const QString &host)
{
    if (!m_eigrpRoutingRepository) {
        qWarning() << "Database repositories are not initialized";
        return {{"ok", false}, {"message", "EIGRP repository not initialized"}};
    }
    return m_eigrpRoutingRepository->getByHost(host);
}

bool DatabaseManager::saveEigrpRouting(const QString &host,
                                       const QVariantList &processes)
{
    if (!m_eigrpRoutingRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const bool ok = m_eigrpRoutingRepository->saveByHost(host, processes);
    if (!ok) {
        qWarning() << "saveEigrpRouting failed:" << m_eigrpRoutingRepository->lastError();
    }
    return ok;
}

bool DatabaseManager::clearEigrpRouting(const QString &host)
{
    if (!m_eigrpRoutingRepository) {
        qWarning() << "Database repositories are not initialized";
        return false;
    }
    const bool ok = m_eigrpRoutingRepository->clearByHost(host);
    if (!ok) {
        qWarning() << "clearEigrpRouting failed:" << m_eigrpRoutingRepository->lastError();
    }
    return ok;
}
