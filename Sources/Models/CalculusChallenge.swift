import Foundation

/// Offline, multiple-choice calculus prompts used as an optional wake-up
/// confirmation. The question content is stored as LaTeX source and rendered
/// by the popup without a network dependency.
struct CalculusChallenge: Identifiable {
    enum Kind {
        case integral
        case series

        var titleKey: String {
            switch self {
            case .integral: return "Integral"
            case .series: return "Series convergence"
            }
        }
    }

    struct Choice: Identifiable {
        let id: Int
        let latex: String?
        let textKey: String?
    }

    let id: String
    let kind: Kind
    let promptLatex: String
    let choices: [Choice]
    let correctIndex: Int
    let explanationLatex: String
    let hintLatex: String

    static func random() -> CalculusChallenge {
        bank.randomElement() ?? bank[0]
    }

    private static let bank: [CalculusChallenge] = [
        CalculusChallenge(
            id: "integral-1",
            kind: .integral,
            promptLatex: "\\int 2x(x^2+1)^3\\,dx",
            choices: formulaChoices([
                "\\frac{(x^2+1)^4}{4}+C",
                "2(x^2+1)^4+C",
                "\\frac{(x^2+1)^3}{3}+C",
                "\\ln(x^2+1)+C"
            ]),
            correctIndex: 0,
            explanationLatex: "u=x^2+1,\\quad du=2x\\,dx,\\quad \\int u^3du=\\frac{u^4}{4}+C",
            hintLatex: "u=x^2+1"
        ),
        CalculusChallenge(
            id: "integral-2",
            kind: .integral,
            promptLatex: "\\int \\frac{3x^2}{(x^3+4)^2}\\,dx",
            choices: formulaChoices([
                "-\\frac{1}{x^3+4}+C",
                "\\frac{1}{x^3+4}+C",
                "-\\frac{3}{(x^3+4)^2}+C",
                "\\ln(x^3+4)+C"
            ]),
            correctIndex: 0,
            explanationLatex: "u=x^3+4,\\quad du=3x^2\\,dx,\\quad \\int u^{-2}du=-u^{-1}+C",
            hintLatex: "u=x^3+4"
        ),
        CalculusChallenge(
            id: "integral-3",
            kind: .integral,
            promptLatex: "\\int \\cos(5x)\\,dx",
            choices: formulaChoices([
                "\\sin(5x)+C",
                "\\frac{1}{5}\\sin(5x)+C",
                "5\\sin(5x)+C",
                "-\\frac{1}{5}\\cos(5x)+C"
            ]),
            correctIndex: 1,
            explanationLatex: "u=5x,\\quad du=5\\,dx,\\quad \\int \\cos(u)\\,\\frac{du}{5}=\\frac{1}{5}\\sin(u)+C",
            hintLatex: "u=5x"
        ),
        CalculusChallenge(
            id: "series-1",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}\\frac{(-1)^{n+1}}{n^2}",
            choices: textChoices(["Converges absolutely", "Converges conditionally", "Diverges", "Geometric series"]),
            correctIndex: 0,
            explanationLatex: "\\sum\\frac{1}{n^2}\\text{ is a }p\\text{-series with }p=2>1,\\text{ so the series converges absolutely.}",
            hintLatex: "Compare the absolute values with \\sum\\frac{1}{n^2}."
        ),
        CalculusChallenge(
            id: "series-2",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}\\frac{3n+1}{n^2+2}",
            choices: textChoices(["Converges absolutely", "Converges conditionally", "Diverges by limit comparison", "Converges by the ratio test"]),
            correctIndex: 2,
            explanationLatex: "\\lim_{n\\to\\infty}\\frac{(3n+1)/(n^2+2)}{1/n}=3,\\text{ and }\\sum\\frac{1}{n}\\text{ diverges, so the series diverges by limit comparison.}",
            hintLatex: "Use limit comparison with \\sum\\frac{1}{n}."
        ),
        CalculusChallenge(
            id: "series-3",
            kind: .series,
            promptLatex: "\\sum_{n=0}^{\\infty}\\left(\\frac{2}{3}\\right)^n",
            choices: textChoices(["Converges", "Diverges", "Converges conditionally", "Cannot be determined"]),
            correctIndex: 0,
            explanationLatex: "|r|=\\frac{2}{3}<1,\\text{ so the geometric series converges.}",
            hintLatex: "Identify the common ratio and compare its absolute value with 1."
        ),
        CalculusChallenge(
            id: "series-4",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}\\frac{1}{n^{3/2}}",
            choices: textChoices(["Converges by the p-series test", "Diverges by the p-series test", "Converges conditionally", "Diverges by the ratio test"]),
            correctIndex: 0,
            explanationLatex: "p=\\frac{3}{2}>1,\\text{ so the }p\\text{-series converges.}",
            hintLatex: "For a \\text{p-series, convergence occurs when }p>1."
        ),
        CalculusChallenge(
            id: "series-5",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}\\frac{1}{n\\ln n}\\quad(n\\ge 2)",
            choices: textChoices(["Converges by the integral test", "Diverges by the integral test", "Converges geometrically", "Converges conditionally"]),
            correctIndex: 1,
            explanationLatex: "\\int_2^\\infty\\frac{dx}{x\\ln x}=\\left[\\ln(\\ln x)\\right]_2^\\infty\\text{ diverges.}",
            hintLatex: "Try \\text{u}=\\ln x\\text{ in the improper integral."
        ),
        CalculusChallenge(
            id: "series-6",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}(-1)^{n+1}\\frac{1}{n}",
            choices: textChoices(["Converges absolutely", "Converges conditionally", "Diverges", "Is geometric"]),
            correctIndex: 1,
            explanationLatex: "\\sum\\frac{1}{n}\\text{ diverges, but the alternating series test gives convergence; therefore it is conditional.}",
            hintLatex: "The harmonic series diverges, while its alternating version converges."
        ),
        CalculusChallenge(
            id: "series-7",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}\\frac{n!}{3^n}",
            choices: textChoices(["Converges by the ratio test", "Diverges by the ratio test", "Converges conditionally", "Converges by comparison"]),
            correctIndex: 1,
            explanationLatex: "\\lim_{n\\to\\infty}\\frac{a_{n+1}}{a_n}=\\lim\\frac{n+1}{3}=\\infty>1,\\text{ so the series diverges.}",
            hintLatex: "Compute \\frac{a_{n+1}}{a_n}."
        ),
        CalculusChallenge(
            id: "series-8",
            kind: .series,
            promptLatex: "\\sum_{n=1}^{\\infty}\\frac{n^2+1}{n^3+4}",
            choices: textChoices(["Converges by direct comparison", "Diverges by limit comparison", "Converges conditionally", "Converges by the alternating series test"]),
            correctIndex: 1,
            explanationLatex: "\\lim_{n\\to\\infty}\\frac{(n^2+1)/(n^3+4)}{1/n}=1,\\text{ and }\\sum\\frac{1}{n}\\text{ diverges.}",
            hintLatex: "Compare with \\sum\\frac{1}{n}."
        )
    ]

    private static func formulaChoices(_ values: [String]) -> [Choice] {
        values.enumerated().map { Choice(id: $0.offset, latex: $0.element, textKey: nil) }
    }

    private static func textChoices(_ values: [String]) -> [Choice] {
        values.enumerated().map { Choice(id: $0.offset, latex: nil, textKey: $0.element) }
    }
}
