#ifndef TERMINALHELPER_H
#define TERMINALHELPER_H

#include <QObject>
#include <QVariantMap>
#include <QStringList>

class TerminalHelper : public QObject
{
    Q_OBJECT
public:
    explicit TerminalHelper(QObject *parent = nullptr);

    Q_INVOKABLE void openTerminal();
    Q_INVOKABLE void pingHost(const QString &ip);
    Q_INVOKABLE void printConnect();
    Q_INVOKABLE QVariantMap ensurePythonLoginDeps();
    Q_INVOKABLE QVariantMap connectHostAndSync(const QString &host);

private:
    bool m_pythonDepsChecked = false;
    QString m_cachedPythonExecutable;

    bool runProcess(const QString &program,
                    const QStringList &args,
                    const QString &workingDir,
                    int timeoutMs,
                    QString *stdoutText,
                    QString *stderrText,
                    int *exitCode) const;
    bool hasSystemPython(QString *foundProgram = nullptr) const;
    bool hasUv() const;
    bool resolvePythonFromVenvFile(const QString &appDir,
                                   QString *pythonExecutable,
                                   QString *message) const;
    bool runSetupScript(const QString &appDir,
                        QString *stdoutText,
                        QString *stderrText,
                        int *exitCode) const;
    bool verifyRequiredImports(const QString &pythonExecutable,
                               QString *message) const;
};

#endif // TERMINALHELPER_H
