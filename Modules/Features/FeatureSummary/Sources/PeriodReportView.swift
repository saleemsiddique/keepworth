import FeatureSupport
import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// What a period earned, spent and saved, by category.
///
/// A detail screen pushed from the summary, not a third tab. It shows the `PeriodSummary` the
/// summary already loaded, so the two cannot disagree about the month.
struct PeriodReportView: View {
    let summary: PeriodSummary
    let accountNames: [AccountID: String]
    let formatter: MoneyFormatter
    var locale: Locale = .autoupdatingCurrent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                section(
                    caption: String(localized: "report.income", bundle: .module),
                    total: summary.totalIncome,
                    totals: summary.income,
                    direction: .incoming,
                    empty: String(localized: "report.noIncome", bundle: .module)
                )

                section(
                    caption: String(localized: "report.expenses", bundle: .module),
                    total: negated(summary.totalExpenses),
                    totals: summary.expenses,
                    direction: .outgoing,
                    empty: String(localized: "report.noExpenses", bundle: .module)
                )

                saved
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin)
        }
        .background(.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(
        caption: String,
        total: Money,
        totals: [AccountTotal],
        direction: AmountDirection,
        empty: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption(caption)

            if totals.isEmpty {
                EmptyStateLine(empty)
            } else {
                LedgerRow(
                    title: caption,
                    amount: formatter.signedString(for: total),
                    direction: direction
                )
                Hairline()
                ForEach(sorted(totals), id: \.accountID) { line in
                    LedgerRow(
                        title: accountNames[line.accountID] ?? "",
                        amount: formatter.signedString(
                            for: direction == .outgoing ? negated(line.total) : line.total
                        ),
                        direction: direction
                    )
                    .padding(.leading, Spacing.screenMargin)
                    if line.accountID != sorted(totals).last?.accountID {
                        Hairline()
                    }
                }
            }
        }
    }

    /// `ink`, not the accent: what was saved is income minus expenses, not money that arrived.
    /// Painting it green would tell the user something came in that did not.
    private var saved: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption(String(localized: "report.saved", bundle: .module))
            LedgerRow(
                title: String(localized: "report.saved", bundle: .module),
                amount: formatter.signedString(for: summary.saved)
            )

            // Only when there is one. In a normal month it is zero, and a row of zero would
            // read as a figure the user has to account for.
            if !summary.openingBalances.isZero {
                Hairline()
                LedgerRow(
                    title: String(localized: "report.openingBalances", bundle: .module),
                    amount: formatter.signedString(for: summary.openingBalances)
                )
            }
        }
    }

    /// Biggest first: a report is read to find where the money went, and the answer is at the
    /// top.
    private func sorted(_ totals: [AccountTotal]) -> [AccountTotal] {
        totals.sorted { $0.total.minorUnits > $1.total.minorUnits }
    }

    /// Written the way the reader's language writes dates. `CalendarDate.description` is the
    /// schema's `yyyy-MM-dd`, which belongs in a column and not in a navigation bar.
    private var title: String {
        let style = CalendarDate.longDayStyle(in: locale)
        return String(
            localized: "report.title",
            defaultValue: "\(summary.from.formatted(style)) – \(summary.through.formatted(style))",
            bundle: .module
        )
    }

    private func negated(_ amount: Money) -> Money {
        (try? amount.negated()) ?? amount
    }
}
