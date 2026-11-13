pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Свой сервер уведомлений: попапов нет вообще, всё копится в центре.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications
    readonly property int count: list && list.values ? list.values.length : 0

    function clearAll() {
        const items = list.values.slice();
        for (let i = items.length - 1; i >= 0; i--) items[i].dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        bodyMarkupSupported: false
        onNotification: n => {
            n.tracked = true;
        }
    }
}
