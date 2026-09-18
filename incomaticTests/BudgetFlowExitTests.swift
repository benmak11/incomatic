//
//  BudgetFlowExitTests.swift
//  incomaticTests
//
//  BudgetFlowView is presented as a fullScreenCover, which has no swipe to dismiss
//  and no system back. Every setup step therefore has to draw its own way out.
//  Only the finished shell used to, which trapped anyone on goals or expenses.
//

import SwiftUI
import XCTest
@testable import Incomatic

@MainActor
final class BudgetFlowExitTests: XCTestCase {

    /// Renders at phone width on a flat background. With empty content the exit
    /// control is the ONLY thing that can put ink on the page, so "more than one
    /// colour" is exactly the property "the user has a way out" reduces to.
    private func render<V: View>(_ view: V) throws -> UIImage {
        let renderer = ImageRenderer(content: view
            .frame(width: 390, height: 120)
            .background(Color.white))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage, "view did not render")
    }

    private func distinctColours(in image: UIImage, sampleEvery step: Int = 4) throws -> Int {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var seen = Set<UInt32>()
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let i = (y * width + x) * 4
                seen.insert(UInt32(pixels[i]) << 16 | UInt32(pixels[i + 1]) << 8 | UInt32(pixels[i + 2]))
            }
        }
        return seen.count
    }

    func test_theSetupChromeActuallyDrawsAnExit() throws {
        let image = try render(BudgetStepChrome(label: "Close", action: {}) { EmptyView() })
        XCTAssertGreaterThan(try distinctColours(in: image), 1,
                             "nothing drawn - the user would have no way to leave the step")
    }

    /// Horizontal only. The test frame centres content vertically, so y says nothing;
    /// x is what ties the control to the title it sits above (26pt inset, 30pt wide).
    func test_theExitIsInsetToMatchTheTitle() throws {
        let image = try render(BudgetStepChrome(label: "Close", action: {}) { EmptyView() })
        let cg = try XCTUnwrap(image.cgImage)
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, maxX = -1
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                if !(px[i] == 255 && px[i + 1] == 255 && px[i + 2] == 255) {
                    minX = min(minX, x); maxX = max(maxX, x)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(minX, 26, "ink starts left of the title inset")
        XCTAssertLessThanOrEqual(maxX, 56, "ink extends past the 30pt control - something else drew")
    }

}
