#ifndef SQLUTILS_H
#define SQLUTILS_H

#include <QSqlQuery>
#include <QString>
#include <QStringList>

namespace SqlUtils {
void bindNullableString(QSqlQuery &query, const QString &value);
void bindNullableIntFromString(QSqlQuery &query, const QString &value);

} // namespace SqlUtils

#endif // SQLUTILS_H
