pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick

QtObject {
    function resource(relativePath) {
        if (typeof AppPaths === "undefined" || AppPaths === null)
            return ""
        try {
            return AppPaths.resource(relativePath)
        } catch (error) {
            return ""
        }
    }
}
