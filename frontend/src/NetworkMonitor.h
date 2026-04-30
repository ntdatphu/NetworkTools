#ifndef NETWORKMONITOR_H
#define NETWORKMONITOR_H

#include <QObject>
#include <QTimer>
#include <QNetworkInterface>
#include <QProcess>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

class NetworkMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool isConnected       READ isConnected      NOTIFY networkChanged)
    Q_PROPERTY(QString connectionType READ connectionType   NOTIFY networkChanged)
    Q_PROPERTY(QString networkName    READ networkName      NOTIFY networkChanged)
    Q_PROPERTY(int ramUsagePercent    READ ramUsagePercent  NOTIFY systemInfoChanged)

public:
    explicit NetworkMonitor(QObject *parent = nullptr) : QObject(parent)
    {
        connect(&m_timer, &QTimer::timeout, this, &NetworkMonitor::checkNetwork);
        m_timer.start(3000);
        checkNetwork();
    }

    bool    isConnected()    const { return m_isConnected; }
    QString connectionType() const { return m_connectionType; }
    QString networkName()    const { return m_networkName; }
    int     ramUsagePercent() const { return m_ramUsagePercent; }

signals:
    void networkChanged();
    void systemInfoChanged();

private slots:
    void checkNetwork()
    {
        bool    connected = false;
        QString type      = "none";
        QString name      = "";
        int     ramUsage  = readRamUsagePercent();

        const QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();

        for (const QNetworkInterface &iface : interfaces)
        {
            QNetworkInterface::InterfaceFlags flags = iface.flags();
            if (!(flags & QNetworkInterface::IsUp))      continue;
            if (!(flags & QNetworkInterface::IsRunning)) continue;
            if (  flags & QNetworkInterface::IsLoopBack) continue;

            bool hasValidAddress = false;
            for (const QNetworkAddressEntry &entry : iface.addressEntries())
            {
                if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol
                    && !entry.ip().isLoopback())
                {
                    hasValidAddress = true;
                    break;
                }
            }
            if (!hasValidAddress) continue;

            QString ifName = iface.name().toLower();

            if (ifName.startsWith("eth")  ||
                ifName.startsWith("en")   ||
                ifName.startsWith("eno")  ||
                ifName.startsWith("enp")  ||
                ifName.startsWith("ens")  ||
                ifName.contains("ethernet"))
            {
                connected = true;
                type      = "ethernet";
                name      = iface.humanReadableName();
                break;
            }

            if (ifName.startsWith("wlan") ||
                ifName.startsWith("wlp")  ||
                ifName.startsWith("wi")   ||
                ifName.contains("wifi")   ||
                ifName.contains("wireless"))
            {
                connected = true;
                type      = "wifi";
                name      = fetchSSID();
                // Không break — tiếp tục tìm xem có Ethernet không
            }
        }

        if (m_isConnected != connected || m_connectionType != type || m_networkName != name)
        {
            m_isConnected    = connected;
            m_connectionType = type;
            m_networkName    = name;
            emit networkChanged();
        }

        if (m_ramUsagePercent != ramUsage)
        {
            m_ramUsagePercent = ramUsage;
            emit systemInfoChanged();
        }
    }

private:
    int readRamUsagePercent()
    {
#ifdef Q_OS_WIN
        MEMORYSTATUSEX memStatus;
        memStatus.dwLength = sizeof(memStatus);
        if (GlobalMemoryStatusEx(&memStatus))
            return static_cast<int>(memStatus.dwMemoryLoad);
        return 0;
#else
        return 0;
#endif
    }

    QString fetchSSID()
    {
        QProcess process;
        process.start("netsh", QStringList() << "wlan" << "show" << "interfaces");
        process.waitForFinished(3000);

        QString output = QString::fromLocal8Bit(process.readAllStandardOutput());

        for (const QString &line : output.split("\n"))
        {
            QString trimmed = line.trimmed();

            // Tìm đúng dòng "SSID" nhưng KHÔNG phải "BSSID"
            if (trimmed.startsWith("SSID") && !trimmed.startsWith("BSSID"))
            {
                // Dòng có dạng: "SSID                   : MyHomeNetwork"
                int colonIdx = trimmed.indexOf(':');
                if (colonIdx != -1)
                    return trimmed.mid(colonIdx + 1).trimmed();
            }
        }

        return "";
    }

    QTimer  m_timer;
    bool    m_isConnected    = false;
    QString m_connectionType = "none";
    QString m_networkName    = "";
    int     m_ramUsagePercent = 0;
};

#endif // NETWORKMONITOR_H