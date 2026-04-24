#ifndef APPMENUBAR_H
#define APPMENUBAR_H

#include <QObject>
#include <QMenuBar>
#include <QMenu>
#include <QAction>
#include <QWindow>
#include <QWidget>

class AppMenuBar : public QObject
{
    Q_OBJECT

public:
    explicit AppMenuBar(QObject *parent = nullptr) : QObject(parent) {}

    // Gọi sau khi QML window đã visible để lấy HWND
    Q_INVOKABLE void attachToWindow(QWindow *window)
    {
        if (!window) return;

        // Tạo QWidget wrapper từ native window handle
        QWidget *nativeWidget = QWidget::createWindowContainer(window);

        m_menuBar = new QMenuBar(nullptr);
        buildMenus();

        // Trên Windows: embed vào native window
        // Qt tự xử lý việc đặt menu bar lên trên cùng
        m_menuBar->setParent(nativeWidget);
        m_menuBar->show();
    }

signals:
    // File
    void newDeviceRequested();
    void quitRequested();

    // View
    void toggleSidebarRequested();
    void themeChangeRequested(int mode);  // 0=system, 1=light, 2=dark

    // Device
    void addDeviceRequested();
    void refreshDevicesRequested();
    void connectAllRequested();
    void disconnectAllRequested();

    // Tools
    void openTerminalRequested();
    void showPythonStatusRequested();

    // Help
    void showAboutRequested();

private:
    QMenuBar *m_menuBar = nullptr;

    void buildMenus()
    {
        if (!m_menuBar) return;

        // ── FILE ──────────────────────────────────────
        QMenu *fileMenu = m_menuBar->addMenu(tr("&File"));

        QAction *newConn = fileMenu->addAction(tr("New Connection"));
        newConn->setShortcut(QKeySequence("Ctrl+N"));
        connect(newConn, &QAction::triggered, this, &AppMenuBar::newDeviceRequested);

        fileMenu->addSeparator();

        QAction *quit = fileMenu->addAction(tr("Quit"));
        quit->setShortcut(QKeySequence("Alt+F4"));
        connect(quit, &QAction::triggered, this, &AppMenuBar::quitRequested);

        // ── VIEW ──────────────────────────────────────
        QMenu *viewMenu = m_menuBar->addMenu(tr("&View"));

        QAction *toggleSidebar = viewMenu->addAction(tr("Toggle Sidebar"));
        toggleSidebar->setShortcut(QKeySequence("Ctrl+B"));
        connect(toggleSidebar, &QAction::triggered, this, &AppMenuBar::toggleSidebarRequested);

        viewMenu->addSeparator();

        QMenu *themeMenu = viewMenu->addMenu(tr("Theme"));

        QActionGroup *themeGroup = new QActionGroup(themeMenu);
        themeGroup->setExclusive(true);

        auto makeThemeAction = [&](const QString &label, int mode) {
            QAction *a = themeMenu->addAction(label);
            a->setCheckable(true);
            themeGroup->addAction(a);
            connect(a, &QAction::triggered, this, [this, mode]() {
                emit themeChangeRequested(mode);
            });
            return a;
        };

        makeThemeAction(tr("System Default"), 0)->setChecked(true);
        makeThemeAction(tr("Light"),          1);
        makeThemeAction(tr("Dark"),           2);

        // ── DEVICE ────────────────────────────────────
        QMenu *deviceMenu = m_menuBar->addMenu(tr("&Device"));

        QAction *addDevice = deviceMenu->addAction(tr("Add Device..."));
        addDevice->setShortcut(QKeySequence("Ctrl+Shift+N"));
        connect(addDevice, &QAction::triggered, this, &AppMenuBar::addDeviceRequested);

        QAction *refresh = deviceMenu->addAction(tr("Refresh List"));
        refresh->setShortcut(QKeySequence("F5"));
        connect(refresh, &QAction::triggered, this, &AppMenuBar::refreshDevicesRequested);

        deviceMenu->addSeparator();

        QAction *connAll = deviceMenu->addAction(tr("Connect All"));
        connAll->setEnabled(false);
        connect(connAll, &QAction::triggered, this, &AppMenuBar::connectAllRequested);

        QAction *discAll = deviceMenu->addAction(tr("Disconnect All"));
        discAll->setEnabled(false);
        connect(discAll, &QAction::triggered, this, &AppMenuBar::disconnectAllRequested);

        // ── TOOLS ─────────────────────────────────────
        QMenu *toolsMenu = m_menuBar->addMenu(tr("&Tools"));

        QAction *terminal = toolsMenu->addAction(tr("Terminal"));
        terminal->setShortcut(QKeySequence("Ctrl+Alt+T"));
        connect(terminal, &QAction::triggered, this, &AppMenuBar::openTerminalRequested);

        toolsMenu->addSeparator();

        QAction *pyStatus = toolsMenu->addAction(tr("Python Environment Status"));
        connect(pyStatus, &QAction::triggered, this, &AppMenuBar::showPythonStatusRequested);

        // ── HELP ──────────────────────────────────────
        QMenu *helpMenu = m_menuBar->addMenu(tr("&Help"));

        QAction *github = helpMenu->addAction(tr("GitHub Repository"));
        connect(github, &QAction::triggered, this, []() {
            QDesktopServices::openUrl(QUrl("https://github.com/Cherster0606/NCKH/"));
        });

        helpMenu->addSeparator();

        QAction *about = helpMenu->addAction(tr("About NetworkUI"));
        connect(about, &QAction::triggered, this, &AppMenuBar::showAboutRequested);
    }
};

#endif // APPMENUBAR_H