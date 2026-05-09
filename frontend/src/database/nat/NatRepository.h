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

    // Lấy danh sách các Rule NAT PAT (Overload)
    QVariantList getNatPatRules(const QString &host);

    // Lấy danh sách các Pool NAT Dynamic
    QVariantList getNatDynamicPools(const QString &host);

    // Lấy danh sách các cấu hình NAT Static
    QVariantList getNatStaticEntries(const QString &host);

    // Trả về lỗi gần nhất nếu truy vấn thất bại
    QString lastError() const;

private:
    QSqlDatabase m_db;
    QString m_lastError;
};

#endif // NATREPOSITORY_H