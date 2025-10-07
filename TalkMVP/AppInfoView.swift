import SwiftUI

struct AppInfoView: View {
    @EnvironmentObject var languageManager: LanguageManager

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    private func localizedText(_ text: String) -> String {
        if languageManager.currentLanguage == .korean {
            switch text {
            case "App Info": return "앱 정보"
            case "About": return "정보"
            case "App Name": return "앱 이름"
            case "Version / Build": return "버전 / 빌드"
            case "Acknowledgements": return "감사의 글"
            case "Licenses": return "라이선스"
            case "Acknowledgements placeholder": return "감사의 글 자리 표시자"
            case "Licenses placeholder": return "라이선스 자리 표시자"
            default: return text
            }
        } else {
            return text
        }
    }

    var body: some View {
        Form {
            Section(header: Text(localizedText("About"))) {
                HStack {
                    Text(localizedText("App Name"))
                    Spacer()
                    Text(appName)
                }
                HStack {
                    Text(localizedText("Version / Build"))
                    Spacer()
                    Text("\(appVersion) (\(appBuild))")
                }
                Text(localizedText("Acknowledgements placeholder"))
            }
            Section(header: Text(localizedText("Licenses"))) {
                Text(localizedText("Licenses placeholder"))
            }
        }
        .navigationTitle(localizedText("App Info"))
    }
}

#Preview {
    AppInfoView()
        .environmentObject(LanguageManager())
}
