import QtQuick

// A wallpaper image that covers its box (crop, centred) like `awww img --resize crop`, decoded at screen width.
// Every Image in the stage uses the same sourceSize, so they all share one decoded texture.
Image {
    property int decodeWidth: 2560

    fillMode: Image.PreserveAspectCrop
    sourceSize.width: decodeWidth
    asynchronous: false
    cache: true
    smooth: true
}
