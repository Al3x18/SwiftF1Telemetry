# SwiftUI Integration Examples

Quick SwiftUI examples for `SwiftF1Telemetry`, with minimal code.

## 1) Fastest lap for one driver

This is the smallest useful flow: load a fixed session, fetch one driver's fastest lap, then read telemetry points.

```swift
import Observation
import SwiftF1Telemetry

@MainActor
@Observable
final class SimpleTelemetryViewModel {
    var isLoading = false
    var errorMessage: String?
    var sampleCount: Int?

    private let client = F1Client()

    func load() async {
        isLoading = true
        errorMessage = nil
        sampleCount = nil
        defer { isLoading = false }

        do {
            let session = try await client.session(
                year: 2024,
                meeting: "Monza",
                session: .qualifying
            )

            guard let lap = try await session.fastestLap(driver: "16") else {
                errorMessage = "No fastest lap found."
                return
            }

            let telemetry = try await session.telemetry(for: lap)
            sampleCount = telemetry.samples.count
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
```

```swift
import SwiftUI

struct SimpleTelemetryView: View {
    @State private var vm = SimpleTelemetryViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Button("Load Monza Q fastest lap (#16)") {
                Task { await vm.load() }
            }
            .disabled(vm.isLoading)

            if vm.isLoading { ProgressView("Loading...") }
            if let count = vm.sampleCount { Text("Samples: \(count)") }
            if let error = vm.errorMessage { Text(error).foregroundStyle(.red) }
        }
        .padding()
    }
}
```

## 2) Minimal comparison (two drivers)

```swift
let comparison = try await session.compareFastestLaps(
    referenceDriver: "16",
    comparedDriver: "55"
)

let deltaPoints = comparison.deltaSeriesByDistance()
```

Use `deltaPoints` directly in a line chart.

## 3) Tiny chart example

```swift
import Charts
import SwiftUI

struct DeltaChartView: View {
    let delta: [DistancePoint]

    var body: some View {
        Chart(delta) { point in
            LineMark(
                x: .value("Distance", point.x),
                y: .value("Delta", point.y)
            )
        }
        .frame(height: 200)
    }
}
```

## Practical tips

- Start with fixed values (`year`, `meeting`, `session`, `driver`) and add pickers later.
- Keep async loading inside a `@MainActor` view model.
- Show 3 states in UI: loading, success, error.
- Add cache config only when you need it:

```swift
var config = F1Client.Configuration.default
config.cacheMode = .minimum
let client = F1Client(configuration: config)
```
