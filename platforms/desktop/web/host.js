// Stands in for the Xbox 360 shell that originally hosted HexicDeluxe.swf:
// plays the soundtrack, maps controls onto the Xbox key codes the game
// listens for, and answers the FSCommands it sends.
(function () {
    // The Xbox shell delivered controller buttons as these key codes.
    const KEY = { A: 65, B: 66, X: 88, Y: 89, START: 83, LB: 76, RB: 82, LEFT: 37, UP: 38, RIGHT: 39, DOWN: 40 };
    const KEY_NAMES = {
        [KEY.A]: ["KeyA", "a"], [KEY.B]: ["KeyB", "b"], [KEY.X]: ["KeyX", "x"], [KEY.Y]: ["KeyY", "y"],
        [KEY.START]: ["KeyS", "s"], [KEY.LB]: ["KeyL", "l"], [KEY.RB]: ["KeyR", "r"],
        [KEY.LEFT]: ["ArrowLeft", "ArrowLeft"], [KEY.UP]: ["ArrowUp", "ArrowUp"],
        [KEY.RIGHT]: ["ArrowRight", "ArrowRight"], [KEY.DOWN]: ["ArrowDown", "ArrowDown"],
    };
    // Extra keyboard keys on top of the native A/B/X/Y/S/L/R and arrows.
    const KEY_ALIASES = {
        Space: KEY.A, Enter: KEY.A, NumpadEnter: KEY.A,
        Escape: KEY.B, Backspace: KEY.B,
        KeyZ: KEY.X,
        KeyP: KEY.START,
    };
    const SOUNDTRACK = ["Oilyn", "Underlow", "Slartisfgh", "Cobblers", "Belkell", "Lubax", "Badback", "54"];
    const host = window.hexicHost || {};

    const ruffle = window.RufflePlayer.newest();
    const player = ruffle.createPlayer();
    document.getElementById("stage").appendChild(player);

    // --- Soundtrack ---------------------------------------------------------
    const music = new Audio();
    let musicVolume = 0.25; // the game's _DefaultLevel_music
    let lastTrack = -1;
    music.volume = musicVolume;
    function nextTrack() {
        let track;
        do {
            track = Math.floor(Math.random() * SOUNDTRACK.length);
        } while (track === lastTrack && SOUNDTRACK.length > 1);
        lastTrack = track;
        music.src = `music/${SOUNDTRACK[track]}.ogg`;
        music.play().catch(() => {});
    }
    music.addEventListener("ended", nextTrack);
    music.addEventListener("error", () => setTimeout(nextTrack, 1000));

    // --- FSCommands ---------------------------------------------------------
    const FS_COMMANDS = {
        SessionReady() {
            if (!music.src) nextTrack();
        },
        MusicVolume(level) {
            musicVolume = Math.min(1, Math.max(0, Number(level) || 0));
            music.volume = musicVolume;
        },
        // TerminateGame only marks the end of a play session (the pause
        // menu's "Main Menu" sends it); ReturnToArcade is the Exit button.
        ReturnToArcade() {
            if (host.quit) host.quit();
        },
    };
    player.onFSCommand = function (command, args) {
        const handler = FS_COMMANDS[command];
        if (handler) handler(args);
        return true;
    };

    // --- Keyboard aliases -----------------------------------------------------
    // Several physical keys can drive one game key (Space, Enter and A are
    // all A), so a game key is released only when the last of them is.
    const held = {};
    const heldCount = {};
    function press(source, keyCode, down, repeat) {
        if (down) {
            if (held[source] !== undefined && !repeat) return;
            if (held[source] === undefined) {
                held[source] = keyCode;
                heldCount[keyCode] = (heldCount[keyCode] || 0) + 1;
            }
            sendKey("keydown", keyCode);
        } else if (held[source] !== undefined) {
            delete held[source];
            heldCount[keyCode] -= 1;
            if (heldCount[keyCode] === 0) sendKey("keyup", keyCode);
        }
    }
    function releaseAll() {
        for (const source of Object.keys(held)) press(source, held[source], false);
    }
    function sendKey(type, keyCode) {
        const [code, key] = KEY_NAMES[keyCode];
        player.dispatchEvent(new KeyboardEvent(type, { code, key, keyCode, bubbles: true }));
    }
    const NATIVE = {};
    for (const keyCode of Object.keys(KEY_NAMES)) NATIVE[KEY_NAMES[keyCode][0]] = Number(keyCode);
    for (const type of ["keydown", "keyup"]) {
        window.addEventListener(type, (event) => {
            if (!event.isTrusted) return;
            const keyCode = KEY_ALIASES[event.code] !== undefined ? KEY_ALIASES[event.code] : NATIVE[event.code];
            if (keyCode === undefined) return;
            event.preventDefault();
            event.stopImmediatePropagation();
            press("key:" + event.code, keyCode, type === "keydown", event.repeat);
        }, true);
    }
    window.addEventListener("blur", releaseAll);

    // --- Analog stick ---------------------------------------------------------
    // Ruffle maps gamepad buttons itself (see gamepadButtonMapping); the left
    // stick is turned into arrow key presses here.
    const STICK_THRESHOLD = 0.5;
    function pollStick() {
        const pad = Array.from(navigator.getGamepads ? navigator.getGamepads() : []).find(Boolean);
        const [x = 0, y = 0] = pad ? pad.axes : [];
        const wanted = { [KEY.LEFT]: x < -STICK_THRESHOLD, [KEY.RIGHT]: x > STICK_THRESHOLD,
                         [KEY.UP]: y < -STICK_THRESHOLD, [KEY.DOWN]: y > STICK_THRESHOLD };
        for (const [keyCode, down] of Object.entries(wanted)) {
            const source = "stick:" + keyCode;
            if (down !== (held[source] !== undefined)) press(source, Number(keyCode), down);
        }
        requestAnimationFrame(pollStick);
    }
    requestAnimationFrame(pollStick);

    // If autoplay was refused, start (or resume) the soundtrack on the first input.
    function ensureMusic() {
        if (!music.src) nextTrack();
        else if (music.paused && !music.ended) music.play().catch(() => {});
    }
    player.addEventListener("pointerdown", ensureMusic);
    window.addEventListener("keydown", ensureMusic, { once: true });

    player.ruffle().load({
        url: "game/HexicDeluxe.swf",
        base: "game/",
        parameters: { GamerTag: host.gamerTag || "Player" },
        // The console's own fonts: Arial Unicode MS (xarialuni.ttf, repaired
        // at build time) for almost every string, and Convection UI for the
        // HUD labels; frame1_host.as maps the game's font names onto these
        // the way the Xbox shell did.
        fontSources: ["fonts/xarialuni.ttf", "game/convectionui.ttf", "fonts/LiberationSans-Regular.ttf", "fonts/LiberationSans-Bold.ttf"],
        defaultFonts: { sans: ["Arial Unicode MS", "Liberation Sans"], serif: ["Arial Unicode MS", "Liberation Sans"], typewriter: ["Arial Unicode MS", "Liberation Sans"] },
        gamepadButtonMapping: {
            "south": KEY.A, "east": KEY.B, "west": KEY.X, "north": KEY.Y,
            "start": KEY.START, "select": KEY.B,
            "left-trigger": KEY.LB, "right-trigger": KEY.RB,
            "dpad-up": KEY.UP, "dpad-down": KEY.DOWN, "dpad-left": KEY.LEFT, "dpad-right": KEY.RIGHT,
        },
    }).then(() => {
        // Ruffle only accepts keys after it has seen the player gain focus;
        // focus given before the instance existed doesn't count.
        if (!player.hasAttribute("tabindex")) player.setAttribute("tabindex", "0");
        player.blur();
        player.focus({ preventScroll: true });
    });
    window.hexicPlayer = player;
})();
