pragma ComponentBehavior: Bound

import QtQuick
import UI
import "../utils/ValidationUtils.js" as Validation

// UI-P0-03: Specialized network input keeps shorthand normalization out of
// feature forms. It deliberately normalizes only complete, valid shorthand;
// full validation and field-level error messages belong to the submit flow.
StandardTextField {
    id: root

    // ipv4 | subnet | wildcard
    property string inputKind: "ipv4"
    property bool normalizeOnEditingFinished: true
    signal normalizationApplied(string normalizedText)

    function normalizeNetworkText() {
        if (!normalizeOnEditingFinished)
            return

        let normalized = ""
        if (inputKind === "subnet")
            normalized = Validation.parseCidrInput(text)
        else if (inputKind === "wildcard")
            normalized = Validation.parseWildcardInput(text)

        if (normalized !== "" && normalized !== text) {
            text = normalized
            normalizationApplied(normalized)
        }
    }

    onEditingFinished: normalizeNetworkText()
}
