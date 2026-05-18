#ifndef NATREPOSITORY_H
#define NATREPOSITORY_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class NatRepository : public QObject
{
    Q_OBJECT
public:
    explicit NatRepository(QSqlDatabase db, QObject *parent = nullptr);

    // Lấy danh sách Interface được cấu hình NAT (Inside/Outside)
    QVariantList getNatInterfaces(const QString &host);
    bool addNatInterface(const QString &host,
                         const QString &interfaceName,
                         const QString &direction);
    bool deleteNatInterface(int natInterfaceId);

    // Lấy danh sách các Rule NAT PAT (Overload)
    QVariantList getNatPatRules(const QString &host);
    bool addNatPatRule(const QString &host,
                       const QString &aclName,
                       const QString &sourceType,
                       const QString &sourceValue,
                       bool overload);
    bool deleteNatPatRule(int natPatId);

    // Lấy danh sách các Pool NAT Dynamic
    QVariantList getNatDynamicPools(const QString &host);
    bool addNatDynamicPool(const QString &host,
                           const QString &poolName,
                           const QString &startIp,
                           const QString &endIp,
                           const QString &netmask,
                           const QString &aclName);
    bool deleteNatDynamicPool(int natDynamicId);

    // Lấy danh sách các cấu hình NAT Static
    QVariantList getNatStaticEntries(const QString &host);
    bool addNatStaticEntry(const QString &host,
                           const QString &insideLocalIp,
                           const QString &insideGlobalIp,
                           const QString &protocol,
                           const QString &localPort,
                           const QString &globalPort);
    bool deleteNatStaticEntry(int natStaticId);

    // Trả về lỗi gần nhất nếu truy vấn thất bại
    QString lastError() const;

private:
    int getOrCreateNatId(const QString &host, const QString &natName, const QString &natType);
    int findNatAclId(const QString &host, const QString &aclName);
    int findNatPoolId(const QString &host, const QString &poolName);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // NATREPOSITORY_H
