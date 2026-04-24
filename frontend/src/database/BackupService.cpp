#include "BackupService.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>

bool BackupService::createFoldersFromHosts(const QStringList &hosts)
{
    const QString backupPath = QCoreApplication::applicationDirPath() + "/backup";
    QDir baseDir;

    if (!baseDir.mkpath(backupPath)) {
        qWarning() << "Cannot create backup directory:" << backupPath;
        return false;
    }

    for (const QString &host : hosts) {
        const QString trimmedHost = host.trimmed();
        if (trimmedHost.isEmpty())
            continue;

        const QString fullPath = QDir(backupPath).filePath(trimmedHost);
        if (!baseDir.mkpath(fullPath)) {
            qWarning() << "Failed to create folder:" << fullPath;
        }
    }

    return true;
}
