# WebView Demo Flutter 项目

本项目是一个基于Flutter的WebView演示应用，集成了七陌云客服H5访客端功能，支持文件上传、视频下载等特性。

## 功能特性

- 基于 `webview_flutter` 插件实现WebView功能
- 支持H5页面与原生交互
- 实现了文件/图片上传功能（包括权限检查）
- 支持视频下载功能
- 集成了 `permission_handler` 插件处理Android/iOS权限
- 使用 `device_info_plus` 获取设备信息
- 自定义了 `file_picker` 插件以支持特定文件类型

## 集成说明

### 依赖库

项目使用了以下第三方库：

- `webview_flutter`: 官方WebView插件，用于显示网页内容
- `permission_handler`: 权限管理插件，用于处理文件上传所需的存储权限
- `device_info_plus`: 设备信息插件，用于区分Android/iOS平台及版本
- `file_picker`: 文件选择插件，用于实现WebView中的文件上传功能
- `webview_flutter_android`: WebView Android平台专用插件

### 特殊配置

1. **文件选择器定制**：由于官方 `file_picker` 插件在处理某些文件类型时存在问题，项目中使用了本地修改版的插件，路径为 `./plugin/flutter_file_picker`

2. **权限处理**：
   - Android 13以下版本需要申请 `storage` 权限
   - Android 13及以上版本上传图片需要 `photos` 权限
   - 上传文件需要 `photos`、`videos`、`audio` 权限
   - iOS平台直接调用上传功能

3. **User-Agent设置**：为了确保WebView正常工作，设置了带有Flutter标识的User-Agent

4. **JavaScript通道**：实现了 `moorJsCallBack` JavaScript通道，用于处理来自H5页面的消息，包括：
   - 权限检查 (`checkPermission`)
   - 视频下载 (`onDownloadVideo`)
   - 会话关闭事件 (`onCloseEvent`)

### 使用方法

1. 在首页输入框中输入要访问的URL地址
2. 点击"打开网页"按钮加载WebView页面
3. 在WebView页面中，可以通过右上角的刷新按钮重新加载页面

### 注意事项

- 确保网络连接正常
- 在Android设备上，首次使用文件上传功能时会请求相应权限
- 视频下载功能需要在URL参数中设置 `videoDownloadBtn=true` 才能生效
