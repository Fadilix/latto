import QtQuick
import QtQuick.Effects

// GPU blur for `layer.effect`, used for blur transitions: content blurs out as
// it leaves and sharpens as it arrives. Enable the layer only
// while blurred, so items at rest cost nothing and text stays crisp:
//
//   property real blur: 0
//   layer.enabled: blur > 0.01
//   layer.effect: BlurEffect { amount: root.blur }
MultiEffect {
    // 0 is sharp, 1 is fully blurred (about `blurMax` pixels).
    property real amount: 0

    blurEnabled: true
    blur: Math.max(0, Math.min(1, amount))
    blurMax: 32
    blurMultiplier: 0.5
}
