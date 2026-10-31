import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, chinese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t("System")
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }

    static var resolved: AppLanguage {
        let stored = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
        switch stored {
        case .english, .chinese: return stored
        case .system:
            return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
        }
    }
}

/// Lightweight in-app localization. The app ships English strings and a Chinese
/// translation table; technical format names (JPG, PNG, PDF…) stay unchanged.
enum L10n {
    static var isChinese: Bool { AppLanguage.resolved == .chinese }

    static func t(_ english: String) -> String {
        guard isChinese else { return english }
        return zh[english] ?? english
    }

    static func format(_ english: String, _ arguments: CVarArg...) -> String {
        String(format: t(english), arguments: arguments)
    }

    private static let zh: [String: String] = [
        // Menu
        "Convert Files…": "转换文件…",
        "Open Tool for Files…": "选择工具处理文件…",
        "File Actions…": "文件动作…",
        "Getting Started…": "使用引导…",
        "Settings…": "设置…",
        "About Open Tangerine": "关于 Open Tangerine",
        "Check for Updates on Website…": "到官网检查更新…",
        "Show Logs": "显示日志",
        "Quit Open Tangerine": "退出 Open Tangerine",
        "Open Tangerine: hold Shift while dragging a file": "Open Tangerine：拖拽文件时按住 ⇧ Shift",

        // Settings sidebar
        "General": "通用",
        "Appearance": "外观",
        "Formats": "格式",
        "Compatibility": "兼容性",
        "About": "关于",
        "A few thoughtful defaults. A smoother day.": "几个合理的默认值，让一天更顺。",
        "Make your workspace feel like yours.": "让工作区更像你自己的。",
        "Find the balance between detail and size.": "在清晰与体积之间找平衡。",
        "Every source. Every output. At a glance.": "所有输入与输出，一眼看清。",
        "Small utility. Open possibilities.": "小工具，大可能。",

        // General tab
        "Output": "输出",
        "Save converted files": "转换文件保存到",
        "Reveal results in Finder": "在访达中显示结果",
        "Start automatically at login": "登录时自动启动",
        "Sound and haptic feedback": "声音与触感反馈",
        "Float behaviour": "Float 行为",
        "System": "跟随系统",
        "Drag Modifiers": "拖拽修饰键",
        "Conversion wheel": "转换轮盘",
        "Tools wheel": "工具轮盘",
        "File actions": "文件动作",
        "Terminal app": "终端 App",
        "Language": "语言",
        "Restart the app to apply menu and guide language changes.": "重启 App 后菜单与引导的语言会完全生效。",
        "Excluded applications": "排除的应用",
        "Add Application…": "添加应用…",

        // Formats tab
        "Format settings": "格式设置",
        "%@ → %d outputs": "%@ → %d 个输出",
        "Pick a source format to see every output and the settings that affect it. The conversion wheel uses this same matrix.": "选择一个源格式，查看它的全部输出与相关设置。转换轮盘使用同一份矩阵。",
        "Image quality": "图片质量",
        "Preserve metadata when converting": "转换时保留元数据",
        "Compression preset": "压缩预设",
        "Restore Defaults": "恢复默认值",
        "Restore Compression Defaults": "恢复压缩默认值",
        "Images": "图片",
        "Compression": "压缩",
        "Metadata": "元数据",
        "Preserve metadata in conversions": "转换时保留元数据",
        "FFmpeg (optional)": "FFmpeg（可选）",
        "Office engine (optional)": "Office 引擎（可选）",
        "Auto-detect (LibreOffice.app, Homebrew soffice)": "自动检测（LibreOffice.app、Homebrew soffice）",
        "Auto-detect (Homebrew, MacPorts, /usr/local/bin)": "自动检测（Homebrew、MacPorts、/usr/local/bin）",
        "Choose…": "选择…",

        // Compatibility tab
        "Conversion compatibility": "转换兼容性",
        "Conversion compatibility description": "按源格式列出的全部输出与总数。",

        // Window chrome / common buttons
        "Cancel": "取消",
        "Done": "完成",
        "Close": "关闭",
        "Back": "上一步",
        "Continue": "继续",
        "Skip": "跳过",
        "Finish": "完成",
        "Save copy": "保存副本",

        // Onboarding
        "WELCOME": "欢迎",
        "FINISH SETUP": "完成设置",
        "Drop. Tap a key. Done.": "拖文件，按一个键，完成。",
        "Open Tangerine lives in the menu bar. Drag files in Finder, tap a modifier while you drag, and pick what you want from the wheel around your pointer.": "Open Tangerine 常驻菜单栏。在访达里拖起文件，拖动时按一个修饰键，再从指针周围的轮盘里选择要做的操作。",
        "1 · CONVERT": "1 · 转换",
        "Convert formats with ⇧ Shift.": "按住 ⇧ Shift 转换格式。",
        "Start dragging a file, then hold Shift. The wheel lists every format this file can become. Drop it on one: the converted copy is saved next to the original with a clear name.": "先拖起文件，再按住 Shift。轮盘会列出这个文件能变成的所有格式。把文件放到目标格式上，转换后的副本会以清晰的命名保存在原文件旁边。",
        "2 · TOOLS": "2 · 工具",
        "Edit files with ⌘ Command.": "按住 ⌘ Command 处理文件。",
        "Hold Command while dragging to see the tools for that file: compress, crop, trim, split, annotate, redact, merge PDFs, and more. Every tool makes a new file and leaves the original alone.": "拖动时按住 Command 查看该文件的工具：压缩、裁剪、修剪、分割、标注、涂黑、合并 PDF 等。每个工具都会生成新文件，原文件保持不变。",
        "3 · ACTIONS": "3 · 动作",
        "Act on files with ⌃ Control.": "按住 ⌃ Control 执行文件动作。",
        "Hold Control while dragging to AirDrop, Float, Copy, Move, copy a path, or open the folder in Terminal. Actions never touch your conversion allowance because there is none.": "拖动时按住 Control 可以 AirDrop、Float、复制、移动、复制路径，或在终端打开所在文件夹。开源版没有次数限制。",
        "PRIVATE BY DESIGN": "默认私密",
        "Your files never leave this Mac.": "你的文件不会离开这台 Mac。",
        "Conversions and tools run locally. There is no account, no telemetry, and no upload. Two optional local engines add coverage: FFmpeg for more media codecs and LibreOffice for Office layout fidelity.": "转换与工具全部在本机运行，无需账号、无遥测、不上传。两个可选的本地引擎可扩展能力：FFmpeg 提供更多媒体编码，LibreOffice 提供 Office 版式保真。",
        "A couple of defaults, then you're set.": "最后两个默认项，然后就可以开始。",
        "Open Tangerine stays in the menu bar and starts again after you sign in if you leave that on. You can change every option later in Settings.": "Open Tangerine 会常驻菜单栏；开启登录启动后，登录时会自动运行。之后可在设置里修改所有选项。",
        "Hold while dragging": "拖动时按住",

        // Tools
        "Compress": "压缩",
        "Edit metadata": "编辑元数据",
        "Edit photo": "编辑照片",
        "Add a background": "添加背景",
        "Crop image": "裁剪图片",
        "Redact photo": "涂黑照片",
        "Resize images": "调整尺寸",
        "Rotate & flip": "旋转与翻转",
        "Create a PDF": "创建 PDF",
        "Create a collage": "制作拼贴",
        "Trim video": "修剪视频",
        "Crop video": "裁剪视频",
        "Change video speed": "视频变速",
        "Join videos": "合并视频",
        "Save video frames": "保存视频帧",
        "Split video": "分割视频",
        "Redact video": "涂黑视频",
        "Normalize volume": "音量标准化",
        "Audio visualizer": "音频可视化",
        "Trim audio": "修剪音频",
        "Audio channels": "音频声道",
        "Bleep audio": "音频哔声",
        "Merge PDFs": "合并 PDF",
        "Organize PDF pages": "整理 PDF 页面",
        "Split PDF": "拆分 PDF",
        "Annotate photo": "标注照片",
        "Remove audio": "移除音频",
        "Extract archive": "解压归档",
        "Read QR codes": "读取二维码",

        // Wheel labels
        "COMPRESS": "压缩",
        "METADATA": "元数据",
        "EDIT": "编辑",
        "ADD BG": "加背景",
        "CROP": "裁剪",
        "REDACT": "涂黑",
        "RESIZE": "缩放",
        "ROTATE": "旋转",
        "PDF": "PDF",
        "COLLAGE": "拼贴",
        "TRIM": "修剪",
        "SPEED": "变速",
        "JOIN": "合并",
        "FRAMES": "抽帧",
        "SPLIT": "分割",
        "NORMALIZE": "标准化",
        "VISUALIZE": "可视化",
        "CHANNELS": "声道",
        "BLEEP": "哔声",
        "MERGE": "合并",
        "ORGANIZE": "整理",
        "ANNOTATE": "标注",
        "MUTE": "静音",
        "EXTRACT": "解压",
        "QR": "二维码",

        // Enum titles
        "Next to the original": "原文件旁边",
        "Downloads": "下载",
        "Desktop": "桌面",
        "Balanced": "均衡",
        "Strong": "强力",
        "Light": "浅色",
        "Dark": "深色",
        "Card": "卡片",
        "Notch pill": "刘海胶囊",
        "Pure black": "纯黑",
        "Glass": "玻璃",
        "Create a new Float": "新建 Float",
        "Add to the current Float": "加入当前 Float",
        "System default": "系统默认",
        "On your Mac": "在你的 Mac 上",
        "Your files. Your workflow.": "你的文件，你的流程。",
        "Keep Open Tangerine ready in the menu bar after you restart and sign in. Move the app to Applications before enabling.": "登录后让 Open Tangerine 仍在菜单栏待命。启用前请先把 App 移到「应用程序」。",
        "Remove Audio": "移除音频",
        "Extract": "解压",
        "Annotate": "标注",
        "Resize": "调整尺寸",

        // File actions
        "AirDrop": "AirDrop",
        "Float": "Float",
        "Copy": "复制",
        "Move": "移动",
        "Copy Path": "复制路径",
        "Terminal": "终端",
        "Reveal": "在访达中显示",
        "Duplicate": "创建副本",
        "SHA-256": "SHA-256",

        // Job titles
        "Converting to %@": "正在转换为 %@",
        "Compressing": "正在压缩",
        "Resizing": "正在调整尺寸",
        "Cropping": "正在裁剪",
        "Trimming": "正在修剪",
        "Redacting": "正在涂黑",
        "Normalizing": "正在标准化",
        "Bleeping": "正在生成哔声",
        "Merging": "正在合并",
        "Splitting": "正在拆分",
        "Organizing": "正在整理",
        "Joining": "正在合并",
        "Changing speed": "正在变速",
        "Creating visualizer": "正在生成可视化",
        "Converting channels": "正在转换声道",
        "Annotating photo": "正在标注照片",
        "Muting video": "正在移除音频",
        "Extracting archive": "正在解压",
        "Moving": "正在移动",
    ]
}
