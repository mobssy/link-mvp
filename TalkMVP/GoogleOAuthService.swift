//
//  GoogleOAuthService.swift
//  TalkMVP
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - Setup Required
// To enable Google Sign-In:
// 1. Go to https://console.cloud.google.com → APIs & Services → Credentials
// 2. Create OAuth 2.0 Client ID → Application type: iOS → enter your bundle ID
// 3. Copy the Client ID and replace the value in GoogleOAuthConfig.clientID below
// 4. In Xcode → Target → Info → URL Types, add a new URL Type:
//    URL Schemes = reversed Client ID (e.g. com.googleusercontent.apps.XXXXX-XXXXX)

enum GoogleOAuthConfig {
    // Replace with your Google OAuth 2.0 Client ID from Google Cloud Console
    static let clientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"

    static var redirectURI: String {
        clientID
            .components(separatedBy: ".")
            .reversed()
            .joined(separator: ".")
        + ":/oauth2callback"
    }

    static var isConfigured: Bool { !clientID.hasPrefix("YOUR_") }
}

struct GoogleUserInfo {
    let userId: String
    let email: String
    let displayName: String
}

enum GoogleOAuthError: LocalizedError {
    case notConfigured
    case invalidURL
    case noAuthCode
    case tokenExchangeFailed
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google 로그인 설정이 필요합니다. GoogleOAuthConfig에서 Client ID를 설정해주세요."
        case .invalidURL:
            return "잘못된 인증 URL입니다."
        case .noAuthCode:
            return "인증 코드를 받지 못했습니다."
        case .tokenExchangeFailed:
            return "토큰 교환에 실패했습니다."
        case .invalidToken:
            return "유효하지 않은 토큰입니다."
        }
    }
}

struct GoogleOAuthService {

    static func signIn() async throws -> GoogleUserInfo {
        guard GoogleOAuthConfig.isConfigured else {
            throw GoogleOAuthError.notConfigured
        }
        let codeVerifier = makeCodeVerifier()
        let codeChallenge = makeCodeChallenge(from: codeVerifier)
        let code = try await requestAuthCode(codeChallenge: codeChallenge)
        let idToken = try await exchangeCodeForIDToken(code: code, codeVerifier: codeVerifier)
        return try decodeUserInfo(from: idToken)
    }

    // MARK: - Private

    private static func requestAuthCode(codeChallenge: String) async throws -> String {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id",             value: GoogleOAuthConfig.clientID),
            .init(name: "redirect_uri",          value: GoogleOAuthConfig.redirectURI),
            .init(name: "response_type",         value: "code"),
            .init(name: "scope",                 value: "openid email profile"),
            .init(name: "code_challenge",        value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else { throw GoogleOAuthError.invalidURL }
        let scheme = GoogleOAuthConfig.redirectURI.components(separatedBy: "://").first ?? ""

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let callbackURL,
                    let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: GoogleOAuthError.noAuthCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = GoogleOAuthPresenter.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private static func exchangeCodeForIDToken(code: String, codeVerifier: String) async throws -> String {
        struct TokenResponse: Decodable {
            let idToken: String
            enum CodingKeys: String, CodingKey { case idToken = "id_token" }
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code":          code,
            "client_id":     GoogleOAuthConfig.clientID,
            "redirect_uri":  GoogleOAuthConfig.redirectURI,
            "grant_type":    "authorization_code",
            "code_verifier": codeVerifier,
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
        .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GoogleOAuthError.tokenExchangeFailed
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data).idToken
    }

    private static func decodeUserInfo(from idToken: String) throws -> GoogleUserInfo {
        let parts = idToken.components(separatedBy: ".")
        guard parts.count == 3 else { throw GoogleOAuthError.invalidToken }

        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = json["sub"] as? String
        else { throw GoogleOAuthError.invalidToken }

        return GoogleUserInfo(
            userId: sub,
            email: json["email"] as? String ?? "",
            displayName: json["name"] as? String ?? "Google User"
        )
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func makeCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationSession Presentation Context
final class GoogleOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleOAuthPresenter()
    private override init() {}

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first
        guard let scene = activeScene else {
            preconditionFailure("No window scene available")
        }
        return scene.windows.first(where: { $0.isKeyWindow }) ?? UIWindow(windowScene: scene)
    }
}
