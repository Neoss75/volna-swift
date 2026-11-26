import Foundation
import UIKit

/// Songs from a computer over Wi-Fi: works while its page in the settings is open.
@MainActor
final class WifiTransfer: ObservableObject {
    static let shared = WifiTransfer()

    enum State: Equatable {
        case off, starting, waiting, noWifi, failed
        case receiving(String, Double)
    }

    @Published private(set) var state = State.off
    @Published private(set) var address: String?
    @Published private(set) var port: UInt16?
    /// Files that came while the page was open, the newest last.
    @Published private(set) var received: [String] = []
    @Published private(set) var skipped = 0
    @Published private(set) var problems: [String] = []

    private var server: WifiServer?
    private weak var library: Library?
    private var accent = ""
    private var adding: Task<Void, Never>?
    private var watching: Task<Void, Never>?

    var running: Bool { server != nil }

    func start(_ library: Library, accent: String) async {
        guard server == nil else { return }
        self.library = library
        self.accent = accent
        state = .starting
        let s = WifiServer(folder: Library.wifiFolder, page: WifiPageHTML.make(accent: accent)) { [weak self] e in
            Task { @MainActor in self?.handle(e) }
        }
        server = s
        guard let p = await s.start() else {
            if server === s {
                server = nil
                state = .failed
            }
            return
        }
        guard server === s else { return s.stop() } // the page was closed meanwhile
        port = p
        UIApplication.shared.isIdleTimerDisabled = true
        look()
        // the phone may join another network while the page is open
        watching = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.look()
            }
        }
    }

    func stop() {
        watching?.cancel()
        server?.stop()
        server = nil
        port = nil
        address = nil
        state = .off
        received = []
        skipped = 0
        problems = []
        UIApplication.shared.isIdleTimerDisabled = false
        if adding != nil, let library {
            adding?.cancel()
            adding = nil
            Task { await library.addReceived() }
        }
    }

    private func look() {
        guard let port else { return }
        let ip = Self.wifiAddress()
        address = ip.map { "http://\($0):\(port)" }
        if case .receiving = state { return }
        state = ip == nil ? .noWifi : .waiting
    }

    private func handle(_ e: WifiServer.Event) {
        guard server != nil else { return }
        switch e {
        case .progress(let name, let done, let total):
            state = .receiving(name, total > 0 ? Double(done) / Double(total) : 1)
        case .received(let rel):
            received.append(rel)
            library?.unhideReceived(rel)
            settle()
            addSoon()
        case .skipped:
            skipped += 1
            settle()
        case .failed(let name, let reason):
            problems.append((name as NSString).lastPathComponent + ": " + reason)
            settle()
        case .stopped:
            // iOS stops the listener while the app sleeps: start again
            guard let library else { return }
            stop()
            Task { await start(library, accent: accent) }
        }
    }

    private func settle() {
        state = .waiting
        look()
    }

    /// Several files usually come one after another: the list is refreshed once they stop coming.
    private func addSoon() {
        adding?.cancel()
        adding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, let self, let library = self.library else { return }
            self.adding = nil
            await library.addReceived()
        }
    }

    /// The address of the phone in the Wi-Fi network (or in its own hotspot).
    nonisolated static func wifiAddress() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var wifi: String?, other: String?
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard let a = i.ifa_addr, a.pointee.sa_family == UInt8(AF_INET),
                  i.ifa_flags & UInt32(IFF_UP) != 0, i.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(a, socklen_t(a.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: i.ifa_name)
            let ip = host.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            if ip.hasPrefix("169.254.") { continue }
            if name == "en0" { wifi = ip } else if other == nil, name.hasPrefix("en") || name.hasPrefix("bridge") { other = ip }
        }
        return wifi ?? other
    }
}

/// The page the browser gets. Every text comes from tr(), the page itself has none.
enum WifiPageHTML {
    @MainActor static func make(accent id: String) -> String {
        let accent = ["amber": "#FFB547", "mint": "#5FDCAE", "coral": "#FF8F70", "lavender": "#B9A3FF", "sky": "#6CC6FF", "rose": "#FF82B2"]
        let texts: [String: Any] = [
            "lang": Lang.current.rawValue,
            "accent": accent[id] ?? "#FFB547",
            "ext": WifiServer.allowed.sorted(),
            "title": tr("Волна: передача музыки"),
            "sub": tr("Файлы попадут на iPhone и сразу появятся в списке песен."),
            "drop": tr("Перетащите сюда файлы или папки с музыкой"),
            "formats": "MP3, AAC, ALAC, FLAC, WAV, AIFF, CUE, LRC",
            "files": tr("Выбрать файлы"),
            "folder": tr("Выбрать папку"),
            "note": tr("Не закрывайте на телефоне экран передачи, пока идёт отправка. Телефон и компьютер должны быть в одной сети Wi-Fi."),
            "wait": tr("ждёт"),
            "sending": tr("Отправляю: {}"),
            "done": tr("Готово"),
            "sent": tr("на телефоне"),
            "already": tr("уже было"),
            "failed": tr("не отправлено"),
            "lost": tr("нет связи с телефоном"),
            "notMusic": tr("Пропущено, не музыка: {}"),
            "have": tr("Уже на телефоне: {}"),
            "mb": tr("МБ"),
            "gb": tr("ГБ"),
            "leave": tr("Отправка ещё идёт"),
        ]
        let json = (try? JSONSerialization.data(withJSONObject: texts)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return template.replacingOccurrences(of: "__TEXTS__", with: json.replacingOccurrences(of: "</", with: "<\\/"))
    }

    private static let template = #"""
    <!doctype html>
    <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Volna</title>
    <style>
    :root{color-scheme:dark;--bg:#111318;--raise:#1c1f27;--fg:#f2f2f5;--muted:#9a9db0;--line:#2c3040;--accent:#FFB547}
    *{box-sizing:border-box}
    body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
    main{max-width:780px;margin:0 auto;padding:36px 16px 56px}
    h1{font-size:28px;margin:0 0 6px}
    .sub{color:var(--muted);margin:0 0 24px}
    #drop{border:2px dashed var(--line);border-radius:22px;padding:44px 16px;text-align:center;background:var(--raise);transition:border-color .15s,background .15s}
    #drop.over{border-color:var(--accent);background:#262a35}
    #drop b{display:block;font-size:21px;margin-bottom:6px}
    #formats{color:var(--muted);font-size:14px}
    .btns{margin-top:20px;display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
    button{font:inherit;font-weight:600;border:0;border-radius:12px;padding:10px 18px;background:var(--accent);color:#14161c;cursor:pointer}
    button.alt{background:var(--line);color:var(--fg)}
    #progress{margin-top:26px}
    .total{display:flex;justify-content:space-between;gap:12px;color:var(--muted);margin-bottom:8px}
    .total span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .bar{height:6px;background:var(--line);border-radius:3px;overflow:hidden}
    .bar i{display:block;height:100%;width:0;background:var(--accent);transition:width .2s}
    ul{list-style:none;padding:0;margin:10px 0 0}
    li{display:flex;gap:12px;align-items:center;padding:9px 0;border-bottom:1px solid var(--line)}
    li span{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    li em{font-style:normal;color:var(--muted);font-size:14px;white-space:nowrap}
    li.ok em{color:#5fdcae} li.bad em,li.bad span{color:#ff7b7b}
    h2{font-size:17px;margin:34px 0 0}
    #note{color:var(--muted);font-size:14px;margin-top:28px}
    </style></head>
    <body><main>
    <h1 id="title"></h1><p class="sub" id="sub"></p>
    <div id="drop"><b id="dropText"></b><div id="formats"></div>
    <div class="btns"><button id="pickFiles"></button><button class="alt" id="pickFolder"></button></div>
    <input id="f" type="file" multiple hidden><input id="d" type="file" webkitdirectory multiple hidden></div>
    <div id="progress" hidden><div class="total"><span id="status"></span><span id="count"></span></div><div class="bar"><i id="bar"></i></div></div>
    <ul id="queue"></ul>
    <h2 id="haveTitle"></h2><ul id="have"></ul>
    <p id="note"></p>
    </main>
    <script>
    const T = __TEXTS__;
    const $ = id => document.getElementById(id);
    document.documentElement.lang = T.lang;
    document.documentElement.style.setProperty('--accent', T.accent);
    document.title = T.title;
    $('title').textContent = T.title; $('sub').textContent = T.sub; $('dropText').textContent = T.drop;
    $('formats').textContent = T.formats; $('pickFiles').textContent = T.files; $('pickFolder').textContent = T.folder; $('note').textContent = T.note;
    const OK = new Set(T.ext), ext = n => (n.split('.').pop() || '').toLowerCase();
    const size = b => b >= 1e9 ? (b / 1e9).toFixed(1) + ' ' + T.gb : (b / 1e6).toFixed(1) + ' ' + T.mb;
    let queue = [], busy = false, have = new Map(), all = 0, done = 0, bytesAll = 0, bytesDone = 0;

    function row(ul, name, note, top) {
      const li = document.createElement('li'), s = document.createElement('span'), m = document.createElement('em');
      s.textContent = name; m.textContent = note; li.append(s, m);
      top ? ul.prepend(li) : ul.append(li);
      return li;
    }
    async function loadHave() {
      try {
        const list = await (await fetch('/list', {cache: 'no-store'})).json();
        have = new Map(list.map(x => [x.name, x.size]));
        $('haveTitle').textContent = list.length ? T.have.replace('{}', list.length) : '';
        $('have').textContent = '';
        for (const x of list.slice(-300).reverse()) row($('have'), x.name, size(x.size));
      } catch (e) {}
    }
    function update() {
      $('bar').style.width = (bytesAll ? bytesDone / bytesAll * 100 : 0) + '%';
      $('count').textContent = done + ' / ' + all;
    }
    function add(list) {
      let other = 0;
      for (const x of list) {
        if (!OK.has(ext(x.path))) { other++; continue; }
        queue.push({...x, li: row($('queue'), x.path, T.wait)});
        all++; bytesAll += x.file.size;
      }
      if (other) row($('queue'), T.notMusic.replace('{}', other), '').className = 'bad';
      $('progress').hidden = false;
      update();
      if (!busy) next();
    }
    function mark(x, cls, text) { x.li.className = cls; x.li.querySelector('em').textContent = text; }
    function next() {
      const x = queue.shift();
      if (!x) { busy = false; $('status').textContent = T.done; loadHave(); return; }
      busy = true;
      const base = bytesDone, end = () => { bytesDone = base + x.file.size; done++; update(); next(); };
      if (have.get(x.path) === x.file.size) { mark(x, 'ok', T.already); return end(); }
      $('status').textContent = T.sending.replace('{}', x.path);
      const r = new XMLHttpRequest();
      r.open('PUT', '/upload?path=' + encodeURIComponent(x.path));
      r.upload.onprogress = e => {
        if (!e.lengthComputable) return;
        x.li.querySelector('em').textContent = Math.round(e.loaded / e.total * 100) + '%';
        bytesDone = base + e.loaded; update();
      };
      r.onload = () => {
        let j = {}; try { j = JSON.parse(r.responseText); } catch (e) {}
        r.status === 200 ? mark(x, 'ok', j.skipped ? T.already : T.sent) : mark(x, 'bad', j.error || T.failed);
        end();
      };
      r.onerror = () => { mark(x, 'bad', T.lost); end(); };
      r.send(x.file);
    }
    async function walk(entry, dir, out) {
      if (entry.isFile) {
        const f = await new Promise((ok, no) => entry.file(ok, no)).catch(() => null);
        if (f) out.push({file: f, path: dir + f.name});
      } else if (entry.isDirectory) {
        const reader = entry.createReader();
        for (;;) {
          const part = await new Promise((ok, no) => reader.readEntries(ok, no)).catch(() => []);
          if (!part.length) break;
          for (const c of part) await walk(c, dir + entry.name + '/', out);
        }
      }
    }
    const drop = $('drop');
    addEventListener('dragover', e => { e.preventDefault(); drop.classList.add('over'); });
    addEventListener('dragleave', e => { if (!e.relatedTarget) drop.classList.remove('over'); });
    addEventListener('drop', async e => {
      e.preventDefault(); drop.classList.remove('over');
      const entries = [...e.dataTransfer.items].map(i => i.webkitGetAsEntry && i.webkitGetAsEntry()).filter(Boolean);
      const files = [...e.dataTransfer.files];
      if (!entries.length) return add(files.map(f => ({file: f, path: f.name})));
      const out = [];
      for (const en of entries) await walk(en, '', out);
      add(out);
    });
    $('pickFiles').onclick = () => $('f').click();
    $('pickFolder').onclick = () => $('d').click();
    $('f').onchange = e => { add([...e.target.files].map(f => ({file: f, path: f.name}))); e.target.value = ''; };
    $('d').onchange = e => { add([...e.target.files].map(f => ({file: f, path: f.webkitRelativePath || f.name}))); e.target.value = ''; };
    addEventListener('beforeunload', e => { if (busy) { e.preventDefault(); e.returnValue = T.leave; } });
    loadHave();
    </script>
    </body></html>
    """#
}
