#include "InterfaceRepository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QVariant>
#include <QStringList>
#include <QDebug>

InterfaceRepository::InterfaceRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

QString InterfaceRepository::lastError() const
{
    return m_lastError;
}

QVariant InterfaceRepository::nullableString(const QVariantMap &data, const QString &key) const
{
    const QString value = data.value(key).toString().trimmed();
    return value.isEmpty() ? QVariant() : value;
}

QVariant InterfaceRepository::nullableInt(const QVariantMap &data, const QString &key) const
{
    const QString value = data.value(key).toString().trimmed();
    if (value.isEmpty())
        return QVariant();
    bool ok = false;
    const int parsed = value.toInt(&ok);
    return ok ? QVariant(parsed) : QVariant();
}

int InterfaceRepository::findInterfaceId(const QString &host, const QString &interfaceName)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT iface_id FROM interface_name "
                  "WHERE host = :host AND interface_name = :interface_name "
                  "ORDER BY iface_id DESC LIMIT 1");
    query.bindValue(":host", host);
    query.bindValue(":interface_name", interfaceName);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error selecting interface_name:" << m_lastError;
        return -1;
    }

    return query.next() ? query.value(0).toInt() : -1;
}

QVariantMap InterfaceRepository::getInterfaceById(int ifaceId)
{
    QVariantMap map;

    QSqlQuery query(m_db);
    query.prepare("SELECT i.iface_id, i.host, i.interface_name, i.ip_address, i.subnet_mask, "
                  "i.description, i.shutdown, i.success, "
                  "CASE "
                  "WHEN t.iface_id IS NOT NULL THEN 'Tunnel' "
                  "WHEN w.iface_id IS NOT NULL THEN 'WAN' "
                  "ELSE 'L3' END AS interface_kind, "
                  "l.secondary_ip, l.secondary_mask, l.mtu, l.bandwidth, l.delay, "
                  "l.speed, l.duplex, l.negotiation, l.proxy_arp, l.unreachables, l.directed_broadcast, "
                  "t.tunnel_mode, t.tunnel_src, t.tunnel_dst, t.tunnel_key, "
                  "t.keepalive_sec, t.keepalive_retry, t.ipsec_profile, "
                  "w.encap_type, w.pppoe_dialer_pool, w.ppp_auth, w.ppp_username, "
                  "w.ppp_password, w.clock_rate, w.lmi_type, "
                  "q.trust_mode, q.policy_in, q.policy_out, q.shape_rate, q.police_rate, q.police_burst, "
                  "CASE WHEN l.iface_id IS NULL THEN 0 ELSE 1 END AS has_l3, "
                  "CASE WHEN t.iface_id IS NULL THEN 0 ELSE 1 END AS has_tunnel, "
                  "CASE WHEN w.iface_id IS NULL THEN 0 ELSE 1 END AS has_wan, "
                  "CASE WHEN q.iface_id IS NULL THEN 0 ELSE 1 END AS has_qos "
                  "FROM interface_name i "
                  "LEFT JOIN router_iface_l3 l ON l.iface_id = i.iface_id "
                  "LEFT JOIN router_iface_tunnel t ON t.iface_id = i.iface_id "
                  "LEFT JOIN router_iface_wan w ON w.iface_id = i.iface_id "
                  "LEFT JOIN router_iface_qos q ON q.iface_id = i.iface_id "
                  "WHERE i.iface_id = :iface_id");
    query.bindValue(":iface_id", ifaceId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getInterfaceById:" << m_lastError;
        return map;
    }

    if (query.next()) {
        const QSqlRecord record = query.record();
        for (int i = 0; i < record.count(); ++i)
            map[record.fieldName(i)] = query.value(i);
    }

    return map;
}

QVariantList InterfaceRepository::getRouterInterfaces(const QString &host)
{
    QVariantList list;
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return list;
    }

    QSqlQuery query(m_db);
    query.prepare("SELECT i.iface_id FROM interface_name i "
                  "WHERE i.host = :host "
                  "ORDER BY i.interface_name COLLATE NOCASE");
    query.bindValue(":host", host);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing getRouterInterfaces:" << m_lastError;
        return list;
    }

    while (query.next())
        list.append(getInterfaceById(query.value(0).toInt()));

    return list;
}

QVariantMap InterfaceRepository::getRouterInterfaceByName(const QString &host, const QString &interfaceName)
{
    m_lastError.clear();
    const int ifaceId = findInterfaceId(host, interfaceName.trimmed());
    return ifaceId < 0 ? QVariantMap() : getInterfaceById(ifaceId);
}

bool InterfaceRepository::saveL3Details(int ifaceId, const QVariantMap &data)
{
    QSqlQuery query(m_db);
    query.prepare("INSERT INTO router_iface_l3 "
                  "(iface_id, secondary_ip, secondary_mask, mtu, bandwidth, delay, "
                  "speed, duplex, negotiation, proxy_arp, unreachables, directed_broadcast) "
                  "VALUES (:iface_id, :secondary_ip, :secondary_mask, :mtu, :bandwidth, :delay, "
                  ":speed, :duplex, :negotiation, :proxy_arp, :unreachables, :directed_broadcast) "
                  "ON CONFLICT(iface_id) DO UPDATE SET "
                  "secondary_ip = excluded.secondary_ip, secondary_mask = excluded.secondary_mask, "
                  "mtu = excluded.mtu, bandwidth = excluded.bandwidth, delay = excluded.delay, "
                  "speed = excluded.speed, duplex = excluded.duplex, negotiation = excluded.negotiation, "
                  "proxy_arp = excluded.proxy_arp, unreachables = excluded.unreachables, "
                  "directed_broadcast = excluded.directed_broadcast");
    query.bindValue(":iface_id", ifaceId);
    query.bindValue(":secondary_ip", nullableString(data, "secondary_ip"));
    query.bindValue(":secondary_mask", nullableString(data, "secondary_mask"));
    query.bindValue(":mtu", nullableInt(data, "mtu").isNull() ? 1500 : nullableInt(data, "mtu"));
    query.bindValue(":bandwidth", nullableInt(data, "bandwidth"));
    query.bindValue(":delay", nullableInt(data, "delay"));
    query.bindValue(":speed", data.value("speed", "auto").toString());
    query.bindValue(":duplex", data.value("duplex", "auto").toString());
    query.bindValue(":negotiation", data.value("negotiation", true).toBool() ? 1 : 0);
    query.bindValue(":proxy_arp", data.value("proxy_arp", true).toBool() ? 1 : 0);
    query.bindValue(":unreachables", data.value("unreachables", true).toBool() ? 1 : 0);
    query.bindValue(":directed_broadcast", data.value("directed_broadcast", false).toBool() ? 1 : 0);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing saveL3Details:" << m_lastError;
        return false;
    }
    return true;
}

bool InterfaceRepository::saveTunnelDetails(int ifaceId, const QVariantMap &data)
{
    QSqlQuery query(m_db);
    query.prepare("INSERT INTO router_iface_tunnel "
                  "(iface_id, tunnel_mode, tunnel_src, tunnel_dst, tunnel_key, "
                  "keepalive_sec, keepalive_retry, ipsec_profile) "
                  "VALUES (:iface_id, :tunnel_mode, :tunnel_src, :tunnel_dst, :tunnel_key, "
                  ":keepalive_sec, :keepalive_retry, :ipsec_profile) "
                  "ON CONFLICT(iface_id) DO UPDATE SET "
                  "tunnel_mode = excluded.tunnel_mode, tunnel_src = excluded.tunnel_src, "
                  "tunnel_dst = excluded.tunnel_dst, tunnel_key = excluded.tunnel_key, "
                  "keepalive_sec = excluded.keepalive_sec, keepalive_retry = excluded.keepalive_retry, "
                  "ipsec_profile = excluded.ipsec_profile");
    query.bindValue(":iface_id", ifaceId);
    query.bindValue(":tunnel_mode", data.value("tunnel_mode", "gre").toString());
    query.bindValue(":tunnel_src", data.value("tunnel_src").toString().trimmed());
    query.bindValue(":tunnel_dst", data.value("tunnel_dst").toString().trimmed());
    query.bindValue(":tunnel_key", nullableInt(data, "tunnel_key"));
    query.bindValue(":keepalive_sec", nullableInt(data, "keepalive_sec"));
    query.bindValue(":keepalive_retry", nullableInt(data, "keepalive_retry"));
    query.bindValue(":ipsec_profile", nullableString(data, "ipsec_profile"));

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing saveTunnelDetails:" << m_lastError;
        return false;
    }
    return true;
}

bool InterfaceRepository::saveWanDetails(int ifaceId, const QVariantMap &data)
{
    QSqlQuery query(m_db);
    query.prepare("INSERT INTO router_iface_wan "
                  "(iface_id, encap_type, pppoe_dialer_pool, ppp_auth, ppp_username, "
                  "ppp_password, clock_rate, lmi_type) "
                  "VALUES (:iface_id, :encap_type, :pppoe_dialer_pool, :ppp_auth, :ppp_username, "
                  ":ppp_password, :clock_rate, :lmi_type) "
                  "ON CONFLICT(iface_id) DO UPDATE SET "
                  "encap_type = excluded.encap_type, pppoe_dialer_pool = excluded.pppoe_dialer_pool, "
                  "ppp_auth = excluded.ppp_auth, ppp_username = excluded.ppp_username, "
                  "ppp_password = excluded.ppp_password, clock_rate = excluded.clock_rate, "
                  "lmi_type = excluded.lmi_type");
    query.bindValue(":iface_id", ifaceId);
    query.bindValue(":encap_type", data.value("encap_type", "none").toString());
    query.bindValue(":pppoe_dialer_pool", nullableInt(data, "pppoe_dialer_pool"));
    query.bindValue(":ppp_auth", nullableString(data, "ppp_auth"));
    query.bindValue(":ppp_username", nullableString(data, "ppp_username"));
    query.bindValue(":ppp_password", nullableString(data, "ppp_password"));
    query.bindValue(":clock_rate", nullableInt(data, "clock_rate"));
    query.bindValue(":lmi_type", nullableString(data, "lmi_type"));

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing saveWanDetails:" << m_lastError;
        return false;
    }
    return true;
}

bool InterfaceRepository::saveQosDetails(int ifaceId, const QVariantMap &data)
{
    if (!data.value("enable_qos", false).toBool()) {
        QSqlQuery removeQuery(m_db);
        removeQuery.prepare("DELETE FROM router_iface_qos WHERE iface_id = :iface_id");
        removeQuery.bindValue(":iface_id", ifaceId);
        if (!removeQuery.exec()) {
            m_lastError = removeQuery.lastError().text();
            return false;
        }
        return true;
    }

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO router_iface_qos "
                  "(iface_id, trust_mode, policy_in, policy_out, shape_rate, police_rate, police_burst) "
                  "VALUES (:iface_id, :trust_mode, :policy_in, :policy_out, :shape_rate, :police_rate, :police_burst) "
                  "ON CONFLICT(iface_id) DO UPDATE SET "
                  "trust_mode = excluded.trust_mode, policy_in = excluded.policy_in, "
                  "policy_out = excluded.policy_out, shape_rate = excluded.shape_rate, "
                  "police_rate = excluded.police_rate, police_burst = excluded.police_burst");
    query.bindValue(":iface_id", ifaceId);
    query.bindValue(":trust_mode", data.value("trust_mode", "none").toString());
    query.bindValue(":policy_in", nullableString(data, "policy_in"));
    query.bindValue(":policy_out", nullableString(data, "policy_out"));
    query.bindValue(":shape_rate", nullableInt(data, "shape_rate"));
    query.bindValue(":police_rate", nullableInt(data, "police_rate"));
    query.bindValue(":police_burst", nullableInt(data, "police_burst"));

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing saveQosDetails:" << m_lastError;
        return false;
    }
    return true;
}

bool InterfaceRepository::clearTypedDetails(int ifaceId, const QString &keepKind)
{
    const QStringList tables = {
        keepKind == "L3" ? QString() : QStringLiteral("router_iface_l3"),
        keepKind == "Tunnel" ? QString() : QStringLiteral("router_iface_tunnel"),
        keepKind == "WAN" ? QString() : QStringLiteral("router_iface_wan")
    };

    for (const QString &table : tables) {
        if (table.isEmpty())
            continue;

        QSqlQuery query(m_db);
        query.prepare(QStringLiteral("DELETE FROM %1 WHERE iface_id = :iface_id").arg(table));
        query.bindValue(":iface_id", ifaceId);
        if (!query.exec()) {
            m_lastError = query.lastError().text();
            qWarning() << "Error executing clearTypedDetails:" << m_lastError;
            return false;
        }
    }
    return true;
}

bool InterfaceRepository::saveRouterInterface(const QVariantMap &data)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    const QString host = data.value("host").toString().trimmed();
    const QString interfaceName = data.value("interface_name").toString().trimmed();
    if (host.isEmpty() || interfaceName.isEmpty()) {
        m_lastError = "Host and interface name are required.";
        return false;
    }

    const QString kind = data.value("interface_kind", "L3").toString();
    m_db.transaction();

    int ifaceId = findInterfaceId(host, interfaceName);
    QSqlQuery query(m_db);
    if (ifaceId < 0) {
        query.prepare("INSERT INTO interface_name "
                      "(host, interface_name, ip_address, subnet_mask, description, shutdown) "
                      "VALUES (:host, :interface_name, :ip_address, :subnet_mask, :description, :shutdown)");
        query.bindValue(":host", host);
        query.bindValue(":interface_name", interfaceName);
    } else {
        query.prepare("UPDATE interface_name SET ip_address = :ip_address, subnet_mask = :subnet_mask, "
                      "description = :description, shutdown = :shutdown "
                      "WHERE iface_id = :iface_id");
        query.bindValue(":iface_id", ifaceId);
    }

    query.bindValue(":ip_address", nullableString(data, "ip_address"));
    query.bindValue(":subnet_mask", nullableString(data, "subnet_mask"));
    query.bindValue(":description", nullableString(data, "description"));
    query.bindValue(":shutdown", data.value("shutdown", false).toBool() ? 1 : 0);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing saveRouterInterface:" << m_lastError;
        m_db.rollback();
        return false;
    }

    if (ifaceId < 0)
        ifaceId = query.lastInsertId().toInt();

    if (!clearTypedDetails(ifaceId, kind)) {
        m_db.rollback();
        return false;
    }

    bool ok = false;
    if (kind == "Tunnel")
        ok = saveTunnelDetails(ifaceId, data);
    else if (kind == "WAN")
        ok = saveWanDetails(ifaceId, data);
    else
        ok = saveL3Details(ifaceId, data);

    if (!ok || !saveQosDetails(ifaceId, data)) {
        m_db.rollback();
        return false;
    }

    return m_db.commit();
}

bool InterfaceRepository::deleteRouterInterface(int ifaceId)
{
    m_lastError.clear();

    if (!m_db.isOpen()) {
        m_lastError = "Database is not open.";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM interface_name WHERE iface_id = :iface_id");
    query.bindValue(":iface_id", ifaceId);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qWarning() << "Error executing deleteRouterInterface:" << m_lastError;
        return false;
    }

    return true;
}
