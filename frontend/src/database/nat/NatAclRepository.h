#ifndef NATACLREPOSITORY_H
#define NATACLREPOSITORY_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QString>

class NatAclRepository : public QObject
{
    Q_OBJECT
public:
    explicit NatAclRepository(QSqlDatabase db, QObject *parent = nullptr);

    // Lấy danh sách NAT ACL theo host
    QVariantList getNatAcls(const QString &host);

    // Thêm mới một dòng NAT ACL
    bool addNatAcl(const QString &host,
                   const QString &aclName,
                   const QString &action,
                   const QString &sourceNetwork,
                   const QString &wildcard);

    // Xoá một NAT ACL dựa trên ID
    bool deleteNatAcl(int natAclId);

    // Trả về lỗi gần nhất nếu có
    QString lastError() const;

private:
    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // NATACLREPOSITORY_H