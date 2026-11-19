// Agent Island — live progress around your Mac's notch.
// Reads $ISLAND_HOME/jobs/*.json (default ~/.island) and renders the active job.
// Click-through, never takes focus, quits itself after 45 s with no jobs.
import AppKit
import SwiftUI

struct Job: Identifiable, Equatable, Decodable {
    var id: String
    var title: String
    var sub: String?
    var progress: Double      // 0...1, negative = unknown
    var current: Double?
    var total: Double?
    var status: String        // queued / running / done / failed (stalled is derived)
    var started: Double
    var updated: Double
    var eta: Double?
}

let env = ProcessInfo.processInfo.environment
let zh = (env["ISLAND_LANG"] ?? Locale.preferredLanguages.first ?? "en").hasPrefix("zh")   // ISLAND_LANG=en/zh overrides the system language
func L(_ z: String, _ e: String) -> String { zh ? z : e }

final class Store: ObservableObject {
    @Published var jobs: [Job] = []
    let dir: URL = {
        if let h = env["ISLAND_HOME"], !h.isEmpty { return URL(fileURLWithPath: (h as NSString).expandingTildeInPath).appendingPathComponent("jobs") }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".island/jobs")
    }()
    var idleSince = Date()
    var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    func tick() {
        let fm = FileManager.default
        let now = Date().timeIntervalSince1970
        var out: [Job] = []
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension == "json" {
                guard let d = try? Data(contentsOf: f), var j = try? JSONDecoder().decode(Job.self, from: d) else { continue }
                let live = j.status == "running" || j.status == "queued"
                if !live && now - j.updated > 6 { try? fm.removeItem(at: f); continue }      // finished jobs linger 6 s
                if j.status == "running" && now - j.updated > 180 { j.status = "stalled" }   // no heartbeat for 3 min
                if j.status == "stalled" && now - j.updated > 1800 { try? fm.removeItem(at: f); continue }
                out.append(j)
            }
        }
        out.sort { $0.started < $1.started }
        if out != jobs {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { jobs = out }
        }
        if out.isEmpty {
            if env["ISLAND_KEEPALIVE"] == nil && Date().timeIntervalSince(idleSince) > 45 { NSApp.terminate(nil) }
        } else {
            idleSince = Date()
        }
    }
}

func shortEta(_ s: Double?) -> String? {
    guard let s = s, s.isFinite, s > 0 else { return nil }
    let n = Int(s.rounded())
    if n >= 3600 { return "\(n / 3600)h\(String(format: "%02d", n % 3600 / 60))" }
    return "\(n / 60):\(String(format: "%02d", n % 60))"
}

let aurora: [Color] = [Color(red: 0.42, green: 0.80, blue: 1.0), Color(red: 0.66, green: 0.70, blue: 1.0), Color(red: 1.0, green: 0.70, blue: 0.88)]
let mint: [Color] = [Color(red: 0.30, green: 0.92, blue: 0.62), Color(red: 0.62, green: 1.0, blue: 0.82)]
let coral: [Color] = [Color(red: 1.0, green: 0.40, blue: 0.38), Color(red: 1.0, green: 0.62, blue: 0.5)]

/// The pill's outline: down the left side, along the bottom, up the right side. Progress is drawn on it.
struct NotchOutline: Shape {
    var r: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX + r, y: rect.maxY), radius: r)
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - r), radius: r)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// The little orb on the left: a slowly flowing gradient; a check when done, a cross when failed.
struct Orb: View {
    var status: String
    var body: some View {
        ZStack {
            if status == "done" {
                Circle().fill(LinearGradient(colors: mint, startPoint: .top, endPoint: .bottom))
                Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundStyle(.black)
            } else if status == "failed" {
                Circle().fill(LinearGradient(colors: coral, startPoint: .top, endPoint: .bottom))
                Image(systemName: "xmark").font(.system(size: 7.5, weight: .black)).foregroundStyle(.black)
            } else if status == "stalled" {
                Circle().fill(Color.white.opacity(0.16))
                Image(systemName: "pause.fill").font(.system(size: 6.5, weight: .bold)).foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.4))
            } else {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Circle().fill(AngularGradient(colors: aurora + [aurora[0]], center: .center, angle: .degrees(t * 70)))
                        Circle().fill(RadialGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0)], center: UnitPoint(x: 0.34 + 0.08 * sin(t * 1.7), y: 0.30 + 0.08 * cos(t * 1.3)), startRadius: 0, endRadius: 6.5))
                    }
                    .scaleEffect(1 + 0.07 * sin(t * 2.6))
                    .shadow(color: aurora[1].opacity(0.9), radius: 4)
                }
            }
        }
        .frame(width: 13, height: 13)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: status)
    }
}

/// A stick figure that runs upside-down on the progress band: feet on the pill's bottom edge, body hanging
/// below it, so it never covers the text. It stays at the head of the progress and proves the job is alive.
struct Runner: View {
    var p: Double            // 0...1 along the outline, negative = unknown
    var status: String
    var w: CGFloat           // pill size and corner radius
    var h: CGFloat
    var r: CGFloat

    /// x of a fraction of the outline, clamped to the straight bottom edge
    func xAt(_ f: Double) -> CGFloat {
        let side = h - r, arc = CGFloat.pi * r / 2, bottom = w - 2 * r
        let d = CGFloat(f) * (2 * side + 2 * arc + bottom) - side - arc
        return r + min(max(d, 3), bottom - 3)
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let done = status == "done"
            // unknown progress: follow the patrolling band
            let cyc = t.truncatingRemainder(dividingBy: 2.4) / 2.4
            let patrol = (0.5 - 0.5 * cos(cyc * 2 * Double.pi)) * 0.82 + 0.09
            let f = done ? 1.0 : (p < 0 ? patrol : p)
            let dir: CGFloat = (p < 0 && cyc > 0.5) ? -1 : 1      // faces the way it is going
            Canvas { ctx, size in
                let ph = t * 2 * Double.pi * 2.3
                let ox = size.width / 2
                // drawn upright with y pointing up from the ground, then hung below the line
                func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + CGFloat(x) * dir * 1.32, y: 1 + CGFloat(y) * 1.32) }
                var path = Path()
                func seg(_ a: (Double, Double), _ b: (Double, Double)) { path.move(to: pt(a.0, a.1)); path.addLine(to: pt(b.0, b.1)) }
                let lean = done ? 0.0 : 0.22
                let hip = (0.0, done ? 6.9 + 0.5 * abs(sin(t * 6)) : 6.3 + 0.45 * abs(sin(ph)))
                let sh = (hip.0 + 4.9 * sin(lean), hip.1 + 4.9 * cos(lean))
                let head = (sh.0 + 2.9 * sin(lean), sh.1 + 2.9 * cos(lean))
                for k in 0..<2 {
                    let q = ph + Double(k) * Double.pi
                    // legs
                    let a = done ? (k == 0 ? -0.22 : 0.22) : 0.85 * sin(q)
                    let knee = (hip.0 + 3.5 * sin(a), hip.1 - 3.5 * cos(a))
                    let b = done ? a : a - (0.2 + 1.0 * max(0, sin(q - 1.1)))
                    seg(hip, knee); seg(knee, (knee.0 + 3.5 * sin(b), knee.1 - 3.5 * cos(b)))
                    // arms: swinging opposite to the legs, or thrown up in a V when done
                    let c = done ? (k == 0 ? 2.5 : -2.5) : -0.95 * sin(q)
                    let el = (sh.0 + 2.5 * sin(c), sh.1 - 2.5 * cos(c))
                    let dd = done ? c : c + 1.15
                    seg(sh, el); seg(el, (el.0 + 2.3 * sin(dd), el.1 - 2.3 * cos(dd)))
                }
                seg(hip, sh)
                let col = done ? mint[1] : Color.white
                ctx.addFilter(.shadow(color: (done ? mint[0] : aurora[1]).opacity(0.9), radius: 2.5))
                ctx.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                let hc = pt(head.0, head.1)
                ctx.fill(Path(ellipseIn: CGRect(x: hc.x - 2.7, y: hc.y - 2.7, width: 5.4, height: 5.4)), with: .color(col))
            }
            .frame(width: 34, height: 28)
            .offset(x: xAt(f) - 17, y: h - 1.6)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .animation(.easeOut(duration: 0.8), value: p)
        .allowsHitTesting(false)
    }
}

/// As tall as the notch, content on both sides of the camera, progress as a glowing band on the outline.
struct IslandView: View {
    @ObservedObject var store: Store
    var notch: CGFloat      // notch height
    var notchW: CGFloat     // notch width
    var ear: CGFloat        // how far it extends on each side

    var body: some View {
        let active = store.jobs.filter { $0.status != "queued" }
        let queued = store.jobs.count - active.count
        let j = active.first(where: { $0.status != "running" }) ?? active.first   // a job that just finished takes the stage
        VStack(spacing: 0) {
            if let j = j {
                let pct = j.progress >= 0 ? Int((min(1, j.progress) * 100).rounded(.down)) : -1
                let h = max(notch, 30) + 3
                let cols = j.status == "done" ? mint : (j.status == "failed" ? coral : aurora)
                let grad = LinearGradient(colors: cols, startPoint: .leading, endPoint: .trailing)
                let p = j.status == "done" ? 1.0 : max(0, min(1, j.progress))
                let outline = NotchOutline(r: 15)
                let more = queued + max(0, active.count - 1)
                ZStack {
                    UnevenRoundedRectangle(topLeadingRadius: notch > 0 ? 0 : 15, bottomLeadingRadius: 15, bottomTrailingRadius: 15, topTrailingRadius: notch > 0 ? 0 : 15, style: .continuous)
                        .fill(Color.black)
                        .overlay(LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.055)], startPoint: .center, endPoint: .bottom)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 15, bottomTrailingRadius: 15, topTrailingRadius: 0, style: .continuous)))
                    outline.stroke(Color.white.opacity(0.09), style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).padding(.horizontal, 0.8).padding(.bottom, 0.8)
                    if j.status == "running" && j.progress < 0 {
                        // unknown progress: a short band of light patrols the outline
                        TimelineView(.animation) { tl in
                            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                            let a = 0.5 - 0.5 * cos(t * 2 * Double.pi)
                            ZStack {
                                outline.trim(from: a * 0.82, to: a * 0.82 + 0.18).stroke(grad, style: StrokeStyle(lineWidth: 5, lineCap: .round)).blur(radius: 6).opacity(0.8)
                                outline.trim(from: a * 0.82, to: a * 0.82 + 0.18).stroke(grad, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            }
                            .padding(.horizontal, 0.8).padding(.bottom, 0.8)
                        }
                    } else {
                        // glow (the blurred layer spills slightly outside the pill) + solid line + a breathing head
                        outline.trim(from: 0, to: p).stroke(grad, style: StrokeStyle(lineWidth: 5.5, lineCap: .round)).blur(radius: 6.5).opacity(0.85)
                            .padding(.horizontal, 0.8).padding(.bottom, 0.8).animation(.easeOut(duration: 0.8), value: p)
                        outline.trim(from: 0, to: p).stroke(grad, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .padding(.horizontal, 0.8).padding(.bottom, 0.8).animation(.easeOut(duration: 0.8), value: p)
                        if j.status == "running" {
                            TimelineView(.animation) { tl in
                                let k = 0.6 + 0.4 * sin(tl.date.timeIntervalSinceReferenceDate * 4.2)
                                outline.trim(from: max(0, p - 0.012), to: p).stroke(Color.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                                    .shadow(color: .white.opacity(0.9), radius: 3 + 2.5 * k)
                                    .padding(.horizontal, 0.8).padding(.bottom, 0.8)
                            }
                            .animation(.easeOut(duration: 0.8), value: p)
                        }
                    }
                    HStack(spacing: 0) {
                        HStack(spacing: 7) {
                            Orb(status: j.status)
                            Text(j.title.replacingOccurrences(of: "　", with: " ")).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundStyle(Color.white.opacity(0.94)).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 12).padding(.trailing, 4).frame(width: ear)
                        Color.clear.frame(width: notchW)
                        HStack(spacing: 5) {
                            Spacer(minLength: 0)
                            if more > 0 {
                                Text("+\(more)").font(.system(size: 8.5, weight: .bold, design: .rounded)).foregroundStyle(Color.white.opacity(0.6))
                                    .padding(.horizontal, 4.5).padding(.vertical, 1.5).background(Capsule().fill(Color.white.opacity(0.12)))
                            }
                            if j.status == "done" {
                                Text(L("完成", "Done")).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundStyle(LinearGradient(colors: mint, startPoint: .leading, endPoint: .trailing))
                            } else if j.status == "failed" {
                                Text(L("失敗", "Failed")).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundStyle(LinearGradient(colors: coral, startPoint: .leading, endPoint: .trailing))
                            } else {
                                if let e = shortEta(j.eta) {
                                    Text(e).font(.system(size: 9.5, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Color.white.opacity(0.45))
                                }
                                if pct >= 0 {
                                    HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                                        Text("\(pct)").font(.system(size: 13.5, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText(value: Double(pct)))
                                        Text("%").font(.system(size: 8, weight: .bold, design: .rounded)).opacity(0.65)
                                    }
                                    .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.78, green: 0.84, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                                    .animation(.easeOut(duration: 0.4), value: pct)
                                }
                            }
                        }
                        .padding(.trailing, 12).padding(.leading, 4).frame(width: ear)
                    }
                    .padding(.bottom, 2)
                }
                .frame(width: notchW + ear * 2, height: h)
                .overlay(alignment: .topLeading) {
                    if (j.status == "running" || j.status == "done") && env["ISLAND_NO_RUNNER"] == nil {
                        Runner(p: j.progress, status: j.status, w: notchW + ear * 2, h: h, r: 15)
                    }
                }
                .transition(.scale(scale: 0.5, anchor: .top).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: j.status)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    let store = Store()

    func applicationDidFinishLaunching(_ n: Notification) {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first!
        var notch = screen.safeAreaInsets.top
        var notchW: CGFloat = 0
        if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea { notchW = max(0, screen.frame.width - l.width - r.width) }
        // ISLAND_NOTCH="width,height" pretends there is a notch of that size (used for the demo recording)
        if let s = env["ISLAND_NOTCH"]?.split(separator: ",").compactMap({ Double($0) }), s.count == 2 { notchW = s[0]; notch = s[1] }
        let ear: CGFloat = CGFloat(Double(env["ISLAND_EAR"] ?? "") ?? 122)
        let w: CGFloat = notchW + ear * 2 + 40, h: CGFloat = 80
        var top = notch > 0 ? screen.frame.maxY : screen.visibleFrame.maxY - 6
        var x = screen.frame.midX - w / 2
        // ISLAND_ORIGIN="x,y" puts the window's top-left there instead (y measured from the bottom, AppKit style)
        if let o = env["ISLAND_ORIGIN"]?.split(separator: ",").compactMap({ Double($0) }), o.count == 2 { x = o[0]; top = o[1] }
        panel = NSPanel(contentRect: NSRect(x: x, y: top - h, width: w, height: h), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: IslandView(store: store, notch: notch, notchW: notchW, ear: ear))
        panel.orderFrontRegardless()
        store.start()
    }
}

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let d = AppDelegate()
        app.delegate = d
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
