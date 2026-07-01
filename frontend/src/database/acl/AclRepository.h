#ifndef ACLREPOSITORY_H
#define ACLREPOSITORY_H

#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class AclRepository
{
public:
    explicit AclRepository(const QSqlDatabase &database);

    QVariantList getByHost(const QString &host, const QString &aclType = QString());
    bool saveAcl(const QVariantMap &acl);
    bool deleteAcl(int aclId);
    bool clearByHost(const QString &host);

    QString lastError() const;

private:
    bool markAcl(int aclId, int success);
    bool markAclChildren(int aclId, int success);
    bool updateAclDescription(int aclId, const QString &description);
    bool insertRule(int aclId, const QString &aclType, const QVariantMap &rule);
    QVariantList getRules(int aclId, const QString &aclType);
    QVariantList getBindings(int aclId);
    void setLastError(const QString &message);
    static QString normalizeAclType(const QString &aclType);

    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // ACLREPOSITORY_H
