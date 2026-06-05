#ifndef DHCPHELPERREPOSITORY_H
#define DHCPHELPERREPOSITORY_H

#include <QSqlDatabase>
#include <QString>
#include <QVariantList>

class DhcpHelperRepository
{
public:
    explicit DhcpHelperRepository(const QSqlDatabase &database);

    bool addHelperAddress(int ifaceId, const QString &helperIp);
    bool deleteHelperAddress(int helperId);
    QVariantList getHelperAddresses(const QString &host);

private:
    QSqlDatabase m_db;
};

#endif // DHCPHELPERREPOSITORY_H
