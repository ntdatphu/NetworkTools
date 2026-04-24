#ifndef EXCLUDEDADDRESSREPOSITORY_H
#define EXCLUDEDADDRESSREPOSITORY_H

#include <QSqlDatabase>
#include <QVariantList>
#include <QString>

class ExcludedAddressRepository
{
public:
    explicit ExcludedAddressRepository(const QSqlDatabase &database);

    bool addExcludedAddress(const QString &host,
                            const QString &startIp,
                            const QString &endIp);

    bool deleteExcludedAddress(int exId);
    QVariantList getExcludedAddresses(const QString &host);

private:
    QSqlDatabase m_db;
};

#endif // EXCLUDEDADDRESSREPOSITORY_H
