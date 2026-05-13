#ifndef NETWORKMONITOR_H
#define NETWORKMONITOR_H

#include <QObject>
#include <QTimer>
#include <QNetworkInterface>
#include <QProcess>
#include <QFile>

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
        // Đọc thông tin bộ nhớ từ hệ thống Linux
        QFile file("/proc/meminfo");
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return 0;

        long long memTotal = 0;
        long long memAvailable = 0;

        QByteArray content = file.readAll();
        const QList<QByteArray> lines = content.split('\n'); // Thêm 'const' để tránh Qt Detach

        for (const QByteArray &line : lines)
        {
            if (line.startsWith("MemTotal:")) {
                QList<QByteArray> parts = line.split(' ');
                parts.removeAll("");
                if (parts.size() >= 2) memTotal = parts[1].toLongLong();
            } else if (line.startsWith("MemAvailable:")) {
                QList<QByteArray> parts = line.split(' ');
                parts.removeAll("");
                if (parts.size() >= 2) memAvailable = parts[1].toLongLong();
            }

            // Dừng vòng lặp sớm nếu đã tìm đủ 2 thông số cần thiết
            if (memTotal > 0 && memAvailable > 0) break;
        }

        if (memTotal > 0) {
            // %: RAM Đã dùng = ((Tổng - Trống) / Tổng) * 100
            return static_cast<int>(((memTotal - memAvailable) * 100) / memTotal);
        }

        return 0;
#endif
    }

    QString fetchSSID()
    {
#ifdef Q_OS_WIN
        QProcess process;
        process.start("netsh", QStringList() << "wlan" << "show" << "interfaces");

        // Nếu quá 3 giây mà chưa chạy xong thì ép đóng tiến trình
        if (!process.waitForFinished(3000)) {
            process.kill();
            process.waitForFinished(1000);
        }

        QString output = QString::fromLocal8Bit(process.readAllStandardOutput());
        const QStringList lines = output.split("\n"); // Trích xuất ra biến const

        for (const QString &line : lines)
        {
            QString trimmed = line.trimmed();
            if (trimmed.startsWith("SSID") && !trimmed.startsWith("BSSID"))
            {
                int colonIdx = trimmed.indexOf(':');
                if (colonIdx != -1)
                    return trimmed.mid(colonIdx + 1).trimmed();
            }
        }
        return "";
#else
        // Sử dụng NetworkManager (nmcli) trên Linux
        QProcess process;
        process.start("nmcli", QStringList() << "-t" << "-f" << "active,ssid" << "dev" << "wifi");

        // Nếu quá 3 giây mà chưa chạy xong thì ép đóng tiến trình
        if (!process.waitForFinished(3000)) {
            process.kill();
            process.waitForFinished(1000);
        }

        QString output = QString::fromUtf8(process.readAllStandardOutput());
        const QStringList lines = output.split("\n"); // Trích xuất ra biến const

        for (const QString &line : lines)
        {
            QString trimmed = line.trimmed();
            if (trimmed.startsWith("yes:"))
            {
                return trimmed.mid(4).trimmed();
            }
        }
        return "";
#endif
    }

    QTimer  m_timer;
    bool    m_isConnected    = false;
    QString m_connectionType = "none";
    QString m_networkName    = "";
    int     m_ramUsagePercent = 0;
};

#endif // NETWORKMONITOR_H