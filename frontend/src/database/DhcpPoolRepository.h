#ifndef DHCPPOOLREPOSITORY_H
#define DHCPPOOLREPOSITORY_H

#include <QSqlDatabase>
#include <QVariantList>
#include <QString>

class DhcpPoolRepository
{
public:
    explicit DhcpPoolRepository(const QSqlDatabase &database);

    bool addDhcpPool(const QString &host,
                     const QString &pool,
                     const QString &network,
                     const QString &subnetmask,
                     const QString &defaut,
                     const QString &dns,
                     const QString &lease);

    bool updateDhcpPool(int dhcpId,
                        const QString &pool,
                        const QString &network,
                        const QString &subnetmask,
                        const QString &defaut,
                        const QString &dns,
                        const QString &lease);
    bool deleteDhcpPool(int dhcpId);
    QVariantList getDhcpPools(const QString &host);

private:
    QSqlDatabase m_db;
};

#endif // DHCPPOOLREPOSITORY_H
