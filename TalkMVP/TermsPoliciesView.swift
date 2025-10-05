import SwiftUI

struct TermsPoliciesView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var selectedSegment = 0
    
    private enum Segment: Int, CaseIterable {
        case terms
        case privacy
        
        func title(for language: LanguageManager.Language) -> String {
            switch self {
            case .terms:
                return language == .korean ? "이용 약관" : "Terms"
            case .privacy:
                return language == .korean ? "개인정보처리방침" : "Privacy"
            }
        }
    }
    
    private func localizedText(_ key: String) -> String {
        if languageManager.currentLanguage == .korean {
            switch key {
            case "Terms & Policies":
                return "약관 및 정책"
            case "TermsPlaceholder":
                return """
                본 약관은 서비스 이용에 관한 조건을 규정합니다. 사용자는 본 약관을 숙지하고 동의함으로써 서비스를 이용할 수 있습니다. 본 약관은 서비스 제공자의 권리와 의무, 이용자의 책임과 의무를 상세히 명시합니다. 서비스 이용 중 발생하는 모든 문제는 본 약관에 따릅니다.
                """
            case "PrivacyPlaceholder":
                return """
                개인정보처리방침은 이용자의 개인정보 보호를 위해 수집, 이용, 보관, 파기에 관한 원칙을 설명합니다. 우리는 이용자의 개인정보를 안전하게 관리하며, 제3자 제공 시 명확한 동의를 받습니다. 개인정보와 관련된 권리는 관련 법령에 따라 보호됩니다.
                """
            default:
                return key
            }
        } else {
            switch key {
            case "Terms & Policies":
                return "Terms & Policies"
            case "TermsPlaceholder":
                return """
                These terms govern the conditions of service use. Users must understand and agree to these terms to use the service. The terms detail the rights and obligations of the service provider and the responsibilities of the users. All issues arising during the use of the service are governed by these terms.
                """
            case "PrivacyPlaceholder":
                return """
                The privacy policy explains principles regarding collection, use, storage, and disposal of personal information to protect users. We manage users' personal data securely and obtain clear consent before providing it to third parties. Rights concerning personal information are protected by applicable laws.
                """
            default:
                return key
            }
        }
    }
    
    var body: some View {
        VStack {
            Picker("", selection: $selectedSegment) {
                ForEach(Segment.allCases, id: \.self) { segment in
                    Text(segment.title(for: languageManager.currentLanguage)).tag(segment.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 16) {
                    if selectedSegment == Segment.terms.rawValue {
                        Text(localizedText("TermsPlaceholder"))
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(localizedText("PrivacyPlaceholder"))
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(localizedText("Terms & Policies"))
    }
}

struct TermsPoliciesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TermsPoliciesView()
                .environmentObject(LanguageManager())
        }
    }
}
