import SwiftUI
import WebKit

/// Small offline LaTeX subset renderer for alarm challenges. It intentionally
/// supports the notation used by the bundled calculus question bank instead
/// of loading MathJax or other remote JavaScript at alarm time.
struct LatexFormulaView: NSViewRepresentable {
    let latex: String
    var minHeight: CGFloat = 44

    static func accessibleText(for latex: String) -> String {
        latex
            .replacingOccurrences(of: "\\text{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\\frac", with: "fraction")
            .replacingOccurrences(of: "\\infty", with: "∞")
            .replacingOccurrences(of: "\\to", with: "→")
            .replacingOccurrences(of: "\\ge", with: "≥")
            .replacingOccurrences(of: "\\le", with: "≤")
            .replacingOccurrences(of: "\\sum", with: "sum")
            .replacingOccurrences(of: "\\int", with: "integral")
    }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(LatexMathRenderer.html(for: latex, minHeight: minHeight), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {}
}

private enum LatexMathRenderer {
    static func html(for latex: String, minHeight: CGFloat) -> String {
        let body = render(latex)
        return """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; background: transparent; }
        body { min-height: \(minHeight)px; display: flex; align-items: center; justify-content: center;
               color: -apple-system-label; font-family: 'CMU Serif', 'Computer Modern', 'Latin Modern Math', serif; }
        .math { font-family: 'CMU Serif', 'Computer Modern', 'Latin Modern Math', serif;
                font-size: 24px; line-height: 1.35; white-space: nowrap; }
        .frac { display: inline-flex; vertical-align: middle; flex-direction: column; text-align: center; margin: 0 3px; }
        .frac .num { border-bottom: 1px solid currentColor; padding: 0 4px 1px; }
        .frac .den { padding: 1px 4px 0; }
        sup, sub { font-size: .66em; line-height: 0; }
        .operator { font-style: normal; padding: 0 2px; }
        </style></head><body><div class="math">\(body)</div></body></html>
        """
    }

    private static func render(_ source: String) -> String {
        let chars = Array(source)
        var index = 0
        return renderSequence(chars, index: &index, stopAt: nil)
    }

    private static func renderSequence(_ chars: [Character], index: inout Int, stopAt: Character?) -> String {
        var result = ""
        while index < chars.count {
            let character = chars[index]
            if character == stopAt {
                index += 1
                break
            }
            if character == "{" {
                index += 1
                result += renderSequence(chars, index: &index, stopAt: "}")
                continue
            }
            if character == "^" || character == "_" {
                let tag = character == "^" ? "sup" : "sub"
                index += 1
                result += "<\(tag)>\(renderAtom(chars, index: &index))</\(tag)>"
                continue
            }
            if character == "\\" {
                index += 1
                let command = readCommand(chars, index: &index)
                result += renderCommand(command, chars: chars, index: &index)
                continue
            }
            result += escape(String(character))
            index += 1
        }
        return result
    }

    private static func renderAtom(_ chars: [Character], index: inout Int) -> String {
        guard index < chars.count else { return "" }
        if chars[index] == "{" {
            index += 1
            return renderSequence(chars, index: &index, stopAt: "}")
        }
        if chars[index] == "\\" {
            index += 1
            let command = readCommand(chars, index: &index)
            return renderCommand(command, chars: chars, index: &index)
        }
        let value = escape(String(chars[index]))
        index += 1
        return value
    }

    private static func readCommand(_ chars: [Character], index: inout Int) -> String {
        let start = index
        while index < chars.count, chars[index].isLetter { index += 1 }
        if start == index, index < chars.count {
            let symbol = String(chars[index])
            index += 1
            return symbol
        }
        return String(chars[start..<index])
    }

    private static func renderCommand(_ command: String, chars: [Character], index: inout Int) -> String {
        switch command {
        case "frac":
            let numerator = renderAtom(chars, index: &index)
            let denominator = renderAtom(chars, index: &index)
            return "<span class=\"frac\"><span class=\"num\">\(numerator)</span><span class=\"den\">\(denominator)</span></span>"
        case "sqrt":
            return "<span class=\"operator\">√</span>\(renderAtom(chars, index: &index))"
        case "int": return "<span class=\"operator\">∫</span>"
        case "sum": return "<span class=\"operator\">∑</span>"
        case "infty": return "∞"
        case "pi": return "π"
        case "cdot": return "·"
        case "to": return "→"
        case "ge": return "≥"
        case "le": return "≤"
        case "neq": return "≠"
        case "pm": return "±"
        case "in": return "∈"
        case "notin": return "∉"
        case "cdots": return "⋯"
        case "quad", ",", "!": return "&nbsp;"
        case "left", "right", "displaystyle": return ""
        case "text", "mathrm": return renderAtom(chars, index: &index)
        case "ln": return "ln"
        case "sin": return "sin"
        case "cos": return "cos"
        case "tan": return "tan"
        default: return escape("\\\(command)")
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
