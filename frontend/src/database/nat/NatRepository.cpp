#include "NatRepository.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QDebug>

NatRepository::NatRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

QString NatRepository::lastError() const
{
    return m_lastError;
}

QVariantList NatRepository::getNatInterfaces(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        qWarning() << "NatRepository:" << m_lastError;
        return list;
    }

    QSqlQuery query(m_db);
    // TODO: Thay đổi "nat_interfaces" thành tên bảng thực tế của bạn nếu cần
    query.prepare("SELECT * FROM nat_interfaces WHERE host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatInterfaces:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

QVariantList NatRepository::getNatPatRules(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    // TODO: Thay đổi "nat_pat" thành tên bảng thực tế của bạn nếu cần
    query.prepare("SELECT * FROM nat_pat WHERE host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatPatRules:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

QVariantList NatRepository::getNatDynamicPools(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    // TODO: Thay đổi "nat_pool" thành tên bảng thực tế của bạn nếu cần
    query.prepare("SELECT * FROM nat_pool WHERE host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatDynamicPools:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}

QVariantList NatRepository::getNatStaticEntries(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    // TODO: Thay đổi "nat_static" thành tên bảng thực tế của bạn nếu cần
    query.prepare("SELECT * FROM nat_static WHERE host = :host");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getNatStaticEntries:" << m_lastError;
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            map[record.fieldName(i)] = query.value(i);
        }
        list.append(map);
    }

    return list;
}