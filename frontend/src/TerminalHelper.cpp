#include "TerminalHelper.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

#include <iostream>

TerminalHelper::TerminalHelper(QObject *parent)
    : QObject(parent)
{
}

void TerminalHelper::openTerminal()
{
#ifdef Q_OS_WIN
    if (!QProcess::startDetached("wt.exe")) {
        QProcess::startDetached("cmd.exe");
    }
#else
    QProcess::startDetached("x-terminal-emulator");
#endif
}

void TerminalHelper::pingHost(const QString &ip)
{
#ifdef Q_OS_WIN
    const QString cmd = "ping " + ip;
    const bool ok = QProcess::startDetached(
        "wt.exe",
        QStringList() << "cmd" << "/k" << cmd
    );

    if (!ok) {
        QProcess::startDetached(
            "cmd.exe",
            QStringList() << "/k" << cmd
        );
    }
#else
    const QString cmd = "ping " + ip;
    QProcess::startDetached("x-terminal-emulator", QStringList() << "-e" << cmd);
#endif
}

void TerminalHelper::printConnect()
{
    std::cout << "connect" << std::endl;
}

QVariantMap TerminalHelper::ensurePythonLoginDeps()
{
    QVariantMap out;

    if (m_pythonDepsChecked && !m_cachedPythonExecutable.isEmpty()) {
        out["ok"] = true;
        out["message"] = "Python environment already checked.";
        return out;
    }

    const QString appDir = QCoreApplication::applicationDirPath();

    QString resolvedPython;
    QString resolveMessage;
    if (resolvePythonFromVenvFile(appDir, &resolvedPython, &resolveMessage)) {
        QString verifyMessage;
        if (verifyRequiredImports(resolvedPython, &verifyMessage)) {
            m_cachedPythonExecutable = resolvedPython;
            m_pythonDepsChecked = true;
            out["ok"] = true;
            out["message"] = "Using existing virtual environment from venv_path.txt.";
            return out;
        }
    }

    QString pythonCmd;
    if (!hasSystemPython(&pythonCmd)) {
        out["ok"] = false;
        out["message"] = "Python is not available in PATH. Please install Python 3 before setup.";
        return out;
    }

    if (!hasUv()) {
        out["ok"] = false;
        out["message"] = "uv is not available in PATH. Please install uv before setup.";
        return out;
    }

    QString setupOut;
    QString setupErr;
    int setupExitCode = -1;
    if (!runSetupScript(appDir, &setupOut, &setupErr, &setupExitCode) || setupExitCode != 0) {
        out["ok"] = false;
        if (!setupErr.isEmpty()) {
            out["message"] = setupErr;
        } else if (!setupOut.isEmpty()) {
            out["message"] = setupOut;
        } else {
            out["message"] = "Failed to run setup_venv script.";
        }
        return out;
    }

    if (!resolvePythonFromVenvFile(appDir, &resolvedPython, &resolveMessage)) {
        out["ok"] = false;
        out["message"] = resolveMessage;
        return out;
    }

    QString verifyMessage;
    if (!verifyRequiredImports(resolvedPython, &verifyMessage)) {
        out["ok"] = false;
        out["message"] = verifyMessage;
        return out;
    }

    m_cachedPythonExecutable = resolvedPython;
    m_pythonDepsChecked = true;
    out["ok"] = true;
    out["message"] = "Python environment prepared via setup_venv and venv_path.txt.";
    return out;
}

QVariantMap TerminalHelper::connectHostAndSync(const QString &host)
{
    QVariantMap out;
    const QString cleanHost = host.trimmed();
    if (cleanHost.isEmpty()) {
        out["ok"] = false;
        out["message"] = "Host is empty.";
        return out;
    }

    const QVariantMap deps = ensurePythonLoginDeps();
    if (!deps.value("ok").toBool()) {
        out["ok"] = false;
        out["message"] = "Python dependency check failed: " + deps.value("message").toString();
        return out;
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString scriptPath = QDir(appDir).filePath("script/login/connect_selected.py");
    const QString dbPath = QDir(appDir).filePath("device_network.db");

    if (!QFileInfo::exists(scriptPath)) {
        out["ok"] = false;
        out["message"] = "Python script not found: " + scriptPath;
        return out;
    }

    if (!QFileInfo::exists(dbPath)) {
        out["ok"] = false;
        out["message"] = "Database file not found: " + dbPath;
        return out;
    }

    QString pythonExecutable = m_cachedPythonExecutable;
    if (pythonExecutable.isEmpty()) {
        QString resolveMessage;
        if (!resolvePythonFromVenvFile(appDir, &pythonExecutable, &resolveMessage)) {
            out["ok"] = false;
            out["message"] = resolveMessage;
            return out;
        }
    }

    QString stdoutText;
    QString stderrText;
    int exitCode = -1;
    runProcess(pythonExecutable,
               QStringList() << scriptPath << "--db" << dbPath << "--hosts" << cleanHost,
               QFileInfo(scriptPath).absolutePath(), 120000,
               &stdoutText, &stderrText, &exitCode);

    bool ok = (exitCode == 0);
    QString message;

    if (!stdoutText.isEmpty()) {
        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(stdoutText.toUtf8(), &parseError);
        if (parseError.error == QJsonParseError::NoError && doc.isObject()) {
            const QJsonObject root = doc.object();
            if (root.contains("ok"))
                ok = root.value("ok").toBool(ok);

            message = root.value("message").toString();

            if (!ok) {
                const QJsonArray results = root.value("results").toArray();
                for (const QJsonValue &v : results) {
                    const QJsonObject row = v.toObject();
                    if (!row.value("ok").toBool(false)) {
                        const QString hostMsg = row.value("host").toString();
                        const QString errMsg = row.value("message").toString();
                        if (!errMsg.isEmpty()) {
                            message = hostMsg.isEmpty() ? errMsg : (hostMsg + ": " + errMsg);
                            break;
                        }
                    }
                }
            }
        } else {
            message = stdoutText;
        }
    }

    out["ok"] = ok;

    if (!message.isEmpty()) {
        out["message"] = message;
    } else if (!stderrText.isEmpty()) {
        out["message"] = stderrText;
    } else if (ok) {
        out["message"] = "Connect flow completed.";
    } else {
        out["message"] = "Connect flow failed.";
    }

    return out;
}

bool TerminalHelper::runProcess(const QString &program,
                                const QStringList &args,
                                const QString &workingDir,
                                int timeoutMs,
                                QString *stdoutText,
                                QString *stderrText,
                                int *exitCode) const
{
    QProcess proc;
    if (!workingDir.isEmpty())
        proc.setWorkingDirectory(workingDir);

    proc.start(program, args);
    if (!proc.waitForStarted(5000)) {
        if (stderrText)
            *stderrText = program + " is not available";
        if (exitCode)
            *exitCode = -1;
        return false;
    }

    if (!proc.waitForFinished(timeoutMs)) {
        proc.kill();
        proc.waitForFinished(2000);
    }

    if (stdoutText)
        *stdoutText = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    if (stderrText)
        *stderrText = QString::fromUtf8(proc.readAllStandardError()).trimmed();
    if (exitCode)
        *exitCode = proc.exitCode();

    return proc.exitStatus() == QProcess::NormalExit;
}

bool TerminalHelper::hasSystemPython(QString *foundProgram) const
{
#ifdef Q_OS_WIN
    const QStringList candidates = {"py", "python"};
#else
    const QStringList candidates = {"python3", "python"};
#endif
    for (const QString &cmd : candidates) {
        if (!QStandardPaths::findExecutable(cmd).isEmpty()) {
            if (foundProgram)
                *foundProgram = cmd;
            return true;
        }
    }

    return false;
}

bool TerminalHelper::hasUv() const
{
    return !QStandardPaths::findExecutable("uv").isEmpty();
}

bool TerminalHelper::resolvePythonFromVenvFile(const QString &appDir,
                                                QString *pythonExecutable,
                                                QString *message) const
{
    const QString venvPathFile = QDir(appDir).filePath("venv_path.txt");
    QFile f(venvPathFile);
    if (!f.exists()) {
        if (message)
            *message = "venv_path.txt was not found in app directory: " + appDir;
        return false;
    }

    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (message)
            *message = "Cannot read venv_path.txt in app directory.";
        return false;
    }

    const QString venvAbs = QString::fromUtf8(f.readAll()).trimmed();
    f.close();

    if (venvAbs.isEmpty()) {
        if (message)
            *message = "venv_path.txt is empty.";
        return false;
    }

#ifdef Q_OS_WIN
    const QString candidate = QDir(venvAbs).filePath("Scripts/python.exe");
#else
    const QString candidate = QDir(venvAbs).filePath("bin/python");
#endif

    if (!QFileInfo::exists(candidate)) {
        if (message)
            *message = "Python executable from venv_path.txt was not found: " + candidate;
        return false;
    }

    if (pythonExecutable)
        *pythonExecutable = candidate;
    if (message)
        *message = "Resolved Python executable from venv_path.txt.";

    return true;
}

bool TerminalHelper::runSetupScript(const QString &appDir,
                                    QString *stdoutText,
                                    QString *stderrText,
                                    int *exitCode) const
{
#ifdef Q_OS_WIN
    const QString script = QDir(appDir).filePath("setup_venv.bat");
    if (!QFileInfo::exists(script)) {
        if (stderrText)
            *stderrText = "setup_venv.bat not found in app directory.";
        if (exitCode)
            *exitCode = -1;
        return false;
    }

    return runProcess("cmd.exe",
                      QStringList() << "/c" << script << "packages.txt" << ".venv",
                      appDir,
                      240000,
                      stdoutText,
                      stderrText,
                      exitCode);
#else
    const QString script = QDir(appDir).filePath("setup_venv.sh");
    if (!QFileInfo::exists(script)) {
        if (stderrText)
            *stderrText = "setup_venv.sh not found in app directory.";
        if (exitCode)
            *exitCode = -1;
        return false;
    }

    return runProcess("bash",
                      QStringList() << script << "packages.txt" << ".venv",
                      appDir,
                      240000,
                      stdoutText,
                      stderrText,
                      exitCode);
#endif
}

bool TerminalHelper::verifyRequiredImports(const QString &pythonExecutable,
                                           QString *message) const
{
    const QString importCheckCode =
        "import sys\n"
        "try:\n"
        "    from importlib.util import find_spec\n"
        "except Exception as e:\n"
        "    sys.stderr.write('importlib.util missing: ' + repr(e) + '\\n')\n"
        "    sys.exit(2)\n"
        "mods=['nornir','nornir_netmiko','netmiko','napalm','jinja2','yaml','requests','urllib3']\n"
        "missing=[m for m in mods if find_spec(m) is None]\n"
        "print(','.join(missing))\n";

    QString out;
    QString err;
    int code = -1;
    if (!runProcess(pythonExecutable,
                    QStringList() << "-c" << importCheckCode,
                    QString(),
                    45000,
                    &out,
                    &err,
                    &code) || code != 0) {
        if (message)
            *message = !err.isEmpty() ? err : "Cannot verify Python packages in virtual environment.";
        return false;
    }

    const QStringList missing = out.trimmed().isEmpty()
                                    ? QStringList()
                                    : out.split(',', Qt::SkipEmptyParts);
    if (!missing.isEmpty()) {
        if (message)
            *message = "Missing Python modules after setup: " + missing.join(", ");
        return false;
    }

    if (message)
        *message = "Python modules are ready.";

    return true;
}
