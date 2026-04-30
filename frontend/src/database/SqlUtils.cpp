#include "SqlUtils.h"

#include <QMetaType>
#include <QVariant>

namespace SqlUtils {

// splitSqlStatements removed; initialization moved to external Python script.

void bindNullableString(QSqlQuery &query, const QString &value)
{
    if (value.trimmed().isEmpty()) {
        query.addBindValue(QVariant(QMetaType::fromType<QString>()));
    } else {
        query.addBindValue(value);
    }
}

void bindNullableIntFromString(QSqlQuery &query, const QString &value)
{
    bool ok = false;
    int result = value.toInt(&ok);

    if (ok) {
        query.addBindValue(result);
    } else {
        query.addBindValue(QVariant(QMetaType::fromType<int>()));
    }
}

} // namespace SqlUtils
