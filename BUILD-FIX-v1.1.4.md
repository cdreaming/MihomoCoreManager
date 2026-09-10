# v1.1.4 build fix

The v1.1.3 GitHub Actions log failed in `OverviewView.swift` because SwiftUI does
not provide a `frame(width:minHeight:alignment:)` overload.

Fixed:

```swift
.frame(width: 334)
.frame(minHeight: 336, alignment: .top)
```

A validation gate now scans Swift sources for mixed fixed-size (`width` /
`height`) and flexible (`minWidth`, `maxWidth`, `minHeight`, etc.) arguments in
the same `.frame(...)` call.
