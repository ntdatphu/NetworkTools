#include "AclRepository.h"

#include <QMetaType>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStringList>
#include <QVariant>

namespace {
QVariant nullStringIfEmpty(const QString &value)
{
    const QString trimmed = value.trimmed();
    return trimmed.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(trimmed);
}

QVariant nullIntIfInvalid(const QVariant &value)
{
    bool ok = false;
    const int parsed = value.toInt(&ok);
    return ok && parsed > 0 ? QVariant(parsed) : QVariant(QMetaType::fromType<int>());
}

QVariantMap rowToMap(QSqlQuery &query)
{
    QVariantMap row;
    const QSqlRecord record = query.record();
    for (int i = 0; i < record.count(); ++i)
        row[record.fieldName(i)] = query.value(i);
    return row;
}
}

AclRepository::AclRepository(const QSqlDatabase &database)
    : m_db(database)
{
}

QString AclRepository::lastError() const
{
    return m_lastError;
}

void AclRepository::setLastError(const QString &message)
{
    m_lastError = message;
}

QString AclRepository::normalizeAclType(const QString &aclType)
{
    const QString trimmed = aclType.trimmed().toLower();
    if (trimmed == "standard")
        return QStringLiteral("standard");
    if (trimmed == "extended")
        return QStringLiteral("extended");
    if (trimmed == "dynamic")
        return QStringLiteral("dynamic");
    if (trimmed == "reflexive")
        return QStringLiteral("reflexive");
    if (trimmed == "mac")
        return QStringLiteral("mac");
    return QString();
}

QVariantList AclRepository::getByHost(const QString &host, const QString &aclType)
{
    QVariantList list;
    setLastError(QString());

    const QString normalizedHost = host.trimmed();
    const QString normalizedType = normalizeAclType(aclType);
    if (normalizedHost.isEmpty()) {
        setLastError(QStringLiteral("Host is empty"));
        return list;
    }

    if (!m_db.isOpen()) {
        setLastError(QStringLiteral("Database is not open"));
        return list;
    }

    QSqlQuery query(m_db);
    QString sql = QStringLiteral(
        "SELECT Acl_id, acl_name, acl_type, host, description, success, action_Cfg "
        "FROM ACL_DB "
        "WHERE host = ? AND success != -1 ");
    if (!normalizedType.isEmpty())
        sql += QStringLiteral("AND lower(acl_type) = ? ");
    sql += QStringLiteral("ORDER BY acl_name COLLATE NOCASE, Acl_id DESC;");

    query.prepare(sql);
    query.addBindValue(normalizedHost);
    if (!normalizedType.isEmpty())
        query.addBindValue(normalizedType);

    if (!query.exec()) {
        setLastError(query.lastError().text());
        return list;
    }

    while (query.next()) {
        QVariantMap acl = rowToMap(query);
        const int aclId = acl.value("Acl_id").toInt();
        const QString type = normalizeAclType(acl.value("acl_type").toString());
        acl["rules"] = getRules(aclId, type);
        acl["bindings"] = getBindings(aclId);
        list.append(acl);
    }

    return list;
}

QVariantList AclRepository::getRules(int aclId, const QString &aclType)
{
    QVariantList rules;
    QSqlQuery query(m_db);

    if (aclType == "standard") {
        query.prepare("SELECT id, sequence, action, source, wildcard, success "
                      "FROM standard_acl_rules WHERE acl_id = ? AND success != -1 ORDER BY sequence, id;");
    } else if (aclType == "extended") {
        query.prepare("SELECT id, sequence, action, protocol, source, src_wildcard, src_port, "
                      "destination, dst_wildcard, dst_port, success "
                      "FROM extended_acl_rules WHERE acl_id = ? AND success != -1 ORDER BY sequence, id;");
    } else if (aclType == "dynamic") {
        query.prepare("SELECT id, sequence, action, protocol, source, src_wildcard, src_port, "
                      "destination, dst_wildcard, dst_port, dynamic_name, timeout_seconds, success "
                      "FROM dynamic_acl_rules WHERE acl_id = ? AND success != -1 ORDER BY sequence, id;");
    } else if (aclType == "reflexive") {
        query.prepare("SELECT id, sequence, action, protocol, source, src_wildcard, src_port, "
                      "destination, dst_wildcard, dst_port, reflect_name, timeout_seconds, success "
                      "FROM reflexive_acl_rules WHERE acl_id = ? AND success != -1 ORDER BY sequence, id;");
    } else if (aclType == "mac") {
        query.prepare("SELECT id, sequence, action, src_mac, src_mask, dst_mac, dst_mask, ethertype, success "
                      "FROM mac_acl_rules WHERE acl_id = ? AND success != -1 ORDER BY sequence, id;");
    } else {
        return rules;
    }

    query.addBindValue(aclId);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return rules;
    }

    while (query.next())
        rules.append(rowToMap(query));
    return rules;
}

QVariantList AclRepository::getBindings(int aclId)
{
    QVariantList bindings;
    QSqlQuery query(m_db);
    query.prepare("SELECT b.id, b.iface_id, i.interface_name, b.direction, b.success "
                  "FROM router_iface_acl b "
                  "JOIN interface_name i ON i.iface_id = b.iface_id "
                  "WHERE b.acl_id = ? AND b.success != -1 "
                  "ORDER BY i.interface_name COLLATE NOCASE;");
    query.addBindValue(aclId);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return bindings;
    }

    while (query.next())
        bindings.append(rowToMap(query));
    return bindings;
}

bool AclRepository::saveAcl(const QVariantMap &acl)
{
    setLastError(QString());

    const QString host = acl.value("host").toString().trimmed();
    const QString aclName = acl.value("acl_name").toString().trimmed();
    const QString aclType = normalizeAclType(acl.value("acl_type").toString());
    const QString description = acl.value("description").toString().trimmed();
    const QVariantList rules = acl.value("rules").toList();
    const QVariantMap binding = acl.value("binding").toMap();
    const int requestedAclId = acl.value("acl_id").toInt();
    const bool descriptionOnly = acl.value("description_only", false).toBool();

    if (host.isEmpty() || aclName.isEmpty() || aclType.isEmpty()) {
        setLastError(QStringLiteral("Host, ACL name, and ACL type are required"));
        return false;
    }
    if (rules.isEmpty()) {
        setLastError(QStringLiteral("ACL must include at least one rule"));
        return false;
    }
    if (!m_db.isOpen()) {
        setLastError(QStringLiteral("Database is not open"));
        return false;
    }
    if (!m_db.transaction()) {
        setLastError(m_db.lastError().text());
        return false;
    }

    if (descriptionOnly && requestedAclId > 0) {
        if (!updateAclDescription(requestedAclId, description)) {
            m_db.rollback();
            return false;
        }
        if (!m_db.commit()) {
            setLastError(m_db.lastError().text());
            m_db.rollback();
            return false;
        }
        return true;
    }

    QSqlQuery markQuery(m_db);
    markQuery.prepare("SELECT Acl_id FROM ACL_DB "
                      "WHERE host = ? AND acl_name = ? AND lower(acl_type) = ? AND success != -1;");
    markQuery.addBindValue(host);
    markQuery.addBindValue(aclName);
    markQuery.addBindValue(aclType);
    if (!markQuery.exec()) {
        setLastError(markQuery.lastError().text());
        m_db.rollback();
        return false;
    }
    while (markQuery.next()) {
        const int oldAclId = markQuery.value(0).toInt();
        if (!markAcl(oldAclId, -1) || !markAclChildren(oldAclId, -1)) {
            m_db.rollback();
            return false;
        }
    }

    QSqlQuery insertAcl(m_db);
    insertAcl.prepare("INSERT INTO ACL_DB (acl_name, acl_type, host, description, success, action_Cfg) "
                      "VALUES (?, ?, ?, ?, 0, ?);");
    insertAcl.addBindValue(aclName);
    insertAcl.addBindValue(aclType);
    insertAcl.addBindValue(host);
    insertAcl.addBindValue(nullStringIfEmpty(description));
    insertAcl.addBindValue(1);
    if (!insertAcl.exec()) {
        setLastError(insertAcl.lastError().text());
        m_db.rollback();
        return false;
    }

    const int aclId = insertAcl.lastInsertId().toInt();
    for (const QVariant &ruleVar : rules) {
        if (!insertRule(aclId, aclType, ruleVar.toMap())) {
            m_db.rollback();
            return false;
        }
    }

    const int ifaceId = binding.value("iface_id").toInt();
    const QString direction = binding.value("direction").toString().trimmed().toLower();
    if (ifaceId > 0 && (direction == "in" || direction == "out")) {
        QSqlQuery bindQuery(m_db);
        bindQuery.prepare("INSERT INTO router_iface_acl (iface_id, acl_id, direction, success) "
                          "VALUES (?, ?, ?, 0) "
                          "ON CONFLICT(iface_id, direction) DO UPDATE SET "
                          "acl_id = excluded.acl_id, success = 0;");
        bindQuery.addBindValue(ifaceId);
        bindQuery.addBindValue(aclId);
        bindQuery.addBindValue(direction);
        if (!bindQuery.exec()) {
            setLastError(bindQuery.lastError().text());
            m_db.rollback();
            return false;
        }
    }

    if (!m_db.commit()) {
        setLastError(m_db.lastError().text());
        m_db.rollback();
        return false;
    }
    return true;
}

bool AclRepository::insertRule(int aclId, const QString &aclType, const QVariantMap &rule)
{
    QSqlQuery query(m_db);
    const int sequence = rule.value("sequence").toInt();
    const QString action = rule.value("action").toString().trimmed().toLower();
    if (action != "permit" && action != "deny") {
        setLastError(QStringLiteral("ACL rule action must be permit or deny"));
        return false;
    }

    if (aclType == "standard") {
        query.prepare("INSERT INTO standard_acl_rules (acl_id, sequence, action, source, wildcard, success) "
                      "VALUES (?, ?, ?, ?, ?, 0);");
        query.addBindValue(aclId);
        query.addBindValue(sequence);
        query.addBindValue(action);
        query.addBindValue(rule.value("source").toString().trimmed().isEmpty()
                               ? QStringLiteral("any")
                               : rule.value("source").toString().trimmed());
        query.addBindValue(nullStringIfEmpty(rule.value("wildcard").toString()));
    } else if (aclType == "extended" || aclType == "dynamic" || aclType == "reflexive") {
        const bool dynamic = aclType == "dynamic";
        const bool reflexive = aclType == "reflexive";
        if (dynamic) {
            query.prepare("INSERT INTO dynamic_acl_rules "
                          "(acl_id, sequence, action, protocol, source, src_wildcard, src_port, "
                          "destination, dst_wildcard, dst_port, dynamic_name, timeout_seconds, success) "
                          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);");
        } else if (reflexive) {
            query.prepare("INSERT INTO reflexive_acl_rules "
                          "(acl_id, sequence, action, protocol, source, src_wildcard, src_port, "
                          "destination, dst_wildcard, dst_port, reflect_name, timeout_seconds, success) "
                          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);");
        } else {
            query.prepare("INSERT INTO extended_acl_rules "
                          "(acl_id, sequence, action, protocol, source, src_wildcard, src_port, "
                          "destination, dst_wildcard, dst_port, success) "
                          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);");
        }
        query.addBindValue(aclId);
        query.addBindValue(sequence);
        query.addBindValue(action);
        query.addBindValue(rule.value("protocol", "ip").toString().trimmed().toLower());
        query.addBindValue(rule.value("source").toString().trimmed().isEmpty()
                               ? QStringLiteral("any")
                               : rule.value("source").toString().trimmed());
        query.addBindValue(nullStringIfEmpty(rule.value("src_wildcard").toString()));
        query.addBindValue(nullStringIfEmpty(rule.value("src_port").toString()));
        query.addBindValue(rule.value("destination").toString().trimmed().isEmpty()
                               ? QStringLiteral("any")
                               : rule.value("destination").toString().trimmed());
        query.addBindValue(nullStringIfEmpty(rule.value("dst_wildcard").toString()));
        query.addBindValue(nullStringIfEmpty(rule.value("dst_port").toString()));
        if (dynamic)
            query.addBindValue(rule.value("dynamic_name").toString().trimmed());
        if (reflexive)
            query.addBindValue(nullStringIfEmpty(rule.value("reflect_name").toString()));
        query.addBindValue(rule.value("timeout_seconds", 300).toInt());
    } else if (aclType == "mac") {
        query.prepare("INSERT INTO mac_acl_rules "
                      "(acl_id, sequence, action, src_mac, src_mask, dst_mac, dst_mask, ethertype, success) "
                      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0);");
        query.addBindValue(aclId);
        query.addBindValue(sequence);
        query.addBindValue(action);
        query.addBindValue(rule.value("src_mac").toString().trimmed().isEmpty()
                               ? QStringLiteral("any")
                               : rule.value("src_mac").toString().trimmed());
        query.addBindValue(nullStringIfEmpty(rule.value("src_mask").toString()));
        query.addBindValue(nullStringIfEmpty(rule.value("dst_mac").toString()));
        query.addBindValue(nullStringIfEmpty(rule.value("dst_mask").toString()));
        query.addBindValue(nullStringIfEmpty(rule.value("ethertype").toString()));
    } else {
        setLastError(QStringLiteral("Unsupported ACL type"));
        return false;
    }

    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool AclRepository::deleteAcl(int aclId)
{
    setLastError(QString());
    if (aclId <= 0) {
        setLastError(QStringLiteral("Invalid ACL id"));
        return false;
    }
    if (!m_db.isOpen()) {
        setLastError(QStringLiteral("Database is not open"));
        return false;
    }
    if (!m_db.transaction()) {
        setLastError(m_db.lastError().text());
        return false;
    }
    if (!markAcl(aclId, -1) || !markAclChildren(aclId, -1)) {
        m_db.rollback();
        return false;
    }
    if (!m_db.commit()) {
        setLastError(m_db.lastError().text());
        m_db.rollback();
        return false;
    }
    return true;
}

bool AclRepository::clearByHost(const QString &host)
{
    const QVariantList acls = getByHost(host);
    if (!m_lastError.isEmpty())
        return false;

    if (!m_db.transaction()) {
        setLastError(m_db.lastError().text());
        return false;
    }
    for (const QVariant &aclVar : acls) {
        const int aclId = aclVar.toMap().value("Acl_id").toInt();
        if (!markAcl(aclId, -1) || !markAclChildren(aclId, -1)) {
            m_db.rollback();
            return false;
        }
    }
    if (!m_db.commit()) {
        setLastError(m_db.lastError().text());
        m_db.rollback();
        return false;
    }
    return true;
}

bool AclRepository::markAcl(int aclId, int success)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE ACL_DB SET success = ? WHERE Acl_id = ?;");
    query.addBindValue(success);
    query.addBindValue(aclId);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool AclRepository::markAclChildren(int aclId, int success)
{
    const QStringList tables = {
        QStringLiteral("standard_acl_rules"),
        QStringLiteral("extended_acl_rules"),
        QStringLiteral("dynamic_acl_rules"),
        QStringLiteral("reflexive_acl_rules"),
        QStringLiteral("mac_acl_rules")
    };

    for (const QString &table : tables) {
        QSqlQuery query(m_db);
        query.prepare(QStringLiteral("UPDATE %1 SET success = ? WHERE acl_id = ?;").arg(table));
        query.addBindValue(success);
        query.addBindValue(aclId);
        if (!query.exec()) {
            setLastError(query.lastError().text());
            return false;
        }
    }

    QSqlQuery bindingQuery(m_db);
    bindingQuery.prepare("UPDATE router_iface_acl SET success = ? WHERE acl_id = ?;");
    bindingQuery.addBindValue(success);
    bindingQuery.addBindValue(aclId);
    if (!bindingQuery.exec()) {
        setLastError(bindingQuery.lastError().text());
        return false;
    }
    return true;
}

bool AclRepository::updateAclDescription(int aclId, const QString &description)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE ACL_DB "
                  "SET description = ?, action_Cfg = COALESCE(action_Cfg, 0) | 1, success = 0 "
                  "WHERE Acl_id = ? AND success != -1;");
    query.addBindValue(nullStringIfEmpty(description));
    query.addBindValue(aclId);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}
