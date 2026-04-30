#ifndef DATABASECONNECTION_H
#define DATABASECONNECTION_H

#include <QSqlDatabase>
#include <QString>

class DatabaseConnection
{
public:
    DatabaseConnection();
    bool initializeDatabase();
    QSqlDatabase database() const;

private:
    QSqlDatabase m_db;
    QString m_connectionName;
};

#endif // DATABASECONNECTION_H
