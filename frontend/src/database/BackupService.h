#ifndef BACKUPSERVICE_H
#define BACKUPSERVICE_H

#include <QStringList>

class BackupService
{
public:
    bool createFoldersFromHosts(const QStringList &hosts);
};

#endif // BACKUPSERVICE_H
