Mute 0.1.6 — Web package / 网页包

Windows 本地游玩：
1. 解压完整 ZIP。
2. 双击 start_local.cmd，浏览器会打开 http://127.0.0.1:8765/。
3. 保持启动窗口打开；结束游玩后按 Ctrl+C 关闭服务。
不要直接打开 index.html，浏览器不能通过 file:// 加载游戏资源。
启动器仅监听本机，不需要 Python、Node.js 或 .NET SDK。
端口已被占用时，可在终端运行 start_local.cmd -Port 8766。

Local play on Windows:
Extract the entire ZIP, then double-click start_local.cmd.
Keep its terminal open while playing; press Ctrl+C to stop the local server.
The launcher uses Windows PowerShell and listens only on 127.0.0.1.
Do not open index.html directly. Use the HTTP address opened by the launcher.
For another port: start_local.cmd -Port 8766

Other systems with Python 3, from this folder:
python -m http.server 8765 --bind 127.0.0.1
Open http://127.0.0.1:8765/ in a desktop Chrome or Edge browser.

Controls / 操作：
A/D: move / 移动; Space: jump / 跳跃; W: climb / 攀爬; S: stomp / 空中重踏.
Left mouse: inhale / 吸气; right mouse: sing / 出声.
1/2/3 or wheel: select color / 选色; R: checkpoint / 恢复检查点; Esc/P: pause / 暂停.
Audio starts after the first key or pointer input.
Use P or the in-game pause button if Esc exits browser fullscreen.
Language and key bindings can be changed in the in-game settings.
Settings use this website's browser storage. Refreshing starts a new session.

Website deployment:
Upload this folder's contents, preserving index.html, godot.js, godot.wasm,
godot.pck, _framework and the license files. Use HTTPS and WASM MIME application/wasm.
The single-threaded build does not require COOP/COEP.
The Windows launcher is only for local play; it is not a production web server.
Original files and Brotli/gzip siblings are included. A plain static server can
serve originals. Serve compressed siblings only with the correct Content-Encoding.
