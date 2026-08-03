import Foundation

nonisolated enum LoginErrorClassifier {
    private static let otpTerms = ["otp", "totp", "one-time", "one time", "2fa", "mfa"]

    static func isOTPChallenge(statusCode: Int, responseBody: String, otpProvided: Bool) -> Bool {
        guard statusCode == 401, !otpProvided else { return false }
        let body = responseBody.lowercased()
        return otpTerms.contains(where: body.contains) || body.contains("\"invalid_client\"")
    }

    static func publicMessage(statusCode: Int?, responseBody: String, otpProvided: Bool) -> String {
        guard let statusCode else {
            return "Не удалось подключиться к серверу. Проверьте соединение"
        }
        if statusCode == 401, otpProvided {
            return "Неверный код OTP. Проверьте код в приложении-аутентификаторе"
        }
        if statusCode == 401 {
            return "Неверное имя пользователя или пароль"
        }
        if responseBody.localizedCaseInsensitiveContains("timeout") {
            return "Сервер не ответил вовремя. Попробуйте ещё раз"
        }
        return "Не удалось выполнить вход. Попробуйте ещё раз"
    }
}
