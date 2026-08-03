//
//  WorkspaceBetaUITests.swift
//  WorkspaceBetaUITests
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import CryptoKit
import Foundation
import XCTest

final class WorkspaceBetaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAuthenticationFlowMatchesAndroidStructure() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--reset-authentication")
        app.launch()

        XCTAssertTrue(app.staticTexts["Вход"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Добро пожаловать"].exists)
        XCTAssertTrue(app.textFields["serverURLField"].exists)
        XCTAssertFalse(app.buttons["connectServerButton"].isEnabled)

        let publicServer = app.buttons["publicWorkspaceServer"]
        XCTAssertTrue(publicServer.exists)
        publicServer.tap()

        XCTAssertTrue(app.textFields["usernameField"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.secureTextFields["passwordField"].exists)
        XCTAssertFalse(app.buttons["signInButton"].isEnabled)
        XCTAssertTrue(app.buttons["logoutOrganizationButton"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Authentication credentials screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testClassicAuthenticatorOTPFlow() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let password = environment["CASSI_WORKSPACE_PASSWORD"],
              let otpURI = environment["CASSI_WORKSPACE_OTP_URI"]
        else {
            throw XCTSkip("Workspace credentials are required for the live OTP integration test.")
        }

        let app = XCUIApplication()
        app.launchArguments.append("--reset-authentication")
        app.launch()

        let publicServer = app.buttons["publicWorkspaceServer"]
        XCTAssertTrue(publicServer.waitForExistence(timeout: 10))
        publicServer.tap()

        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 15))
        usernameField.tap()
        usernameField.typeText("cassi")

        let passwordField = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText(password)

        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(signInButton.isEnabled)
        signInButton.tap()

        let otpField = app.textFields["otpField"]
        XCTAssertTrue(otpField.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Введите код"].exists)
        XCTAssertTrue(app.staticTexts["Введите 6-значный код из\nприложения-аутентификатора"].exists)

        let otpAttachment = XCTAttachment(screenshot: app.screenshot())
        otpAttachment.name = "Classic authenticator OTP screen"
        otpAttachment.lifetime = .keepAlways
        add(otpAttachment)

        let otp = try currentTOTP(from: otpURI)
        otpField.tap()
        otpField.typeText(otp)
        XCTAssertEqual(otpField.value as? String, otp)
        XCTAssertTrue(signInButton.isEnabled)
        signInButton.tap()

        XCTAssertTrue(app.buttons["activityTab"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["messengerTab"].exists)
        XCTAssertTrue(app.buttons["calendarTab"].exists)
        XCTAssertTrue(app.buttons["mailTab"].exists)
        XCTAssertTrue(app.buttons["profileTab"].exists)
        assertBottomNavigationVisible(app)

        XCTAssertTrue(app.staticTexts["Моя активность"].waitForExistence(timeout: 20))
        settle()
        capture(app, name: "01 My Activity")

        let starred = app.buttons["Избранное"]
        XCTAssertTrue(starred.exists)
        starred.tap()
        XCTAssertTrue(app.navigationBars["Избранное"].waitForExistence(timeout: 20))
        settle()
        capture(app, name: "02 Starred")
        app.navigationBars["Избранное"].buttons.element(boundBy: 0).tap()

        let inbox = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Входящие"))
            .firstMatch
        XCTAssertTrue(inbox.waitForExistence(timeout: 10))
        inbox.tap()
        XCTAssertTrue(app.navigationBars["Входящие"].waitForExistence(timeout: 20))
        settle()
        assertBottomNavigationVisible(app)
        capture(app, name: "03 Inbox")
        app.navigationBars["Входящие"].buttons.element(boundBy: 0).tap()

        app.buttons["messengerTab"].tap()
        XCTAssertTrue(app.navigationBars["Мессенджер"].waitForExistence(timeout: 20))
        settle()
        capture(app, name: "04 Messenger")

        let sandboxStream = app.staticTexts["песочница"].firstMatch
        XCTAssertTrue(sandboxStream.waitForExistence(timeout: 20))
        sandboxStream.tap()
        XCTAssertTrue(app.navigationBars["песочница"].waitForExistence(timeout: 20))
        settle()
        assertBottomNavigationVisible(app)
        capture(app, name: "05 Topics")
        app.navigationBars["песочница"].buttons.element(boundBy: 0).tap()

        app.buttons["calendarTab"].tap()
        XCTAssertTrue(app.otherElements["calendarComingSoon"].waitForExistence(timeout: 10))
        settle()
        capture(app, name: "06 Calendar")

        app.buttons["mailTab"].tap()
        XCTAssertTrue(app.otherElements["mailComingSoon"].waitForExistence(timeout: 10))
        settle()
        capture(app, name: "07 Mail")

        app.buttons["profileTab"].tap()
        XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 10))
        settle()
        capture(app, name: "08 Profile")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func currentTOTP(from uri: String, now: Date = .now) throws -> String {
        let components = try XCTUnwrap(URLComponents(string: uri))
        let queryItems = components.queryItems ?? []
        let secret = try XCTUnwrap(queryItems.first { $0.name == "secret" }?.value)
        let period = TimeInterval(queryItems.first { $0.name == "period" }?.value ?? "30") ?? 30
        let digits = Int(queryItems.first { $0.name == "digits" }?.value ?? "6") ?? 6
        let algorithm = queryItems.first { $0.name == "algorithm" }?.value?.uppercased() ?? "SHA1"
        XCTAssertEqual(algorithm, "SHA1")

        let key = SymmetricKey(data: try decodeBase32(secret))
        var counter = UInt64(now.timeIntervalSince1970 / period).bigEndian
        let counterData = withUnsafeBytes(of: &counter) { Data($0) }
        let digest = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let bytes = Array(digest)
        let offset = Int(bytes[bytes.count - 1] & 0x0F)
        let value = (UInt32(bytes[offset] & 0x7F) << 24) |
            (UInt32(bytes[offset + 1]) << 16) |
            (UInt32(bytes[offset + 2]) << 8) |
            UInt32(bytes[offset + 3])
        let modulus = UInt32(pow(10.0, Double(digits)))
        return String(format: "%0*u", digits, value % modulus)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertBottomNavigationVisible(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identifiers = ["activityTab", "messengerTab", "calendarTab", "mailTab", "profileTab"]
        for identifier in identifiers {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.exists, "Missing \(identifier)", file: file, line: line)
            XCTAssertTrue(button.isHittable, "\(identifier) is not hittable", file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX + 0.5, file: file, line: line)
        }
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
    }

    private func decodeBase32(_ value: String) throws -> Data {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var buffer = 0
        var bitCount = 0
        var bytes: [UInt8] = []

        for character in value.uppercased() where character != "=" && !character.isWhitespace {
            let index = try XCTUnwrap(alphabet.firstIndex(of: character))
            buffer = (buffer << 5) | index
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                bytes.append(UInt8((buffer >> bitCount) & 0xFF))
            }
        }
        return Data(bytes)
    }
}
