// Injected after the main frame-1 script so it re-applies every time frame 1
// ("Active") is entered and the original script redefines its functions.
// Replaces the Xbox 360 host services: profile storage, saved games and
// Xbox Live leaderboards, all kept locally in a Flash SharedObject.

_root._SignedInToLive = true;
if(_root.GamerTag == undefined || _root.GamerTag == "")
{
   _root.GamerTag = "Player";
}

_root.HexicStore = function()
{
   return SharedObject.getLocal("HexicHD","/");
};

_root.ReadSettings = function()
{
   var r = _root;
   var so = r.HexicStore();
   if(so.data.settings != undefined && so.data.settings != "")
   {
      r._SettingsXMLString = so.data.settings;
      r.ParseSettings();
   }
};

_root.SaveSettings = function()
{
   var r = _root;
   var s = "<settings>\n";
   s += "  <user sfx=\"" + r._Level_sfx + "\" music=\"" + r._Level_music + "\" mute=\"" + r._Muted + "\" patterns=\"" + r._Patterns + "\" >" + r._PlayerName + "</user>\n";
   s += "</settings>";
   var so = r.HexicStore();
   so.data.settings = s;
   so.flush();
   fscommand("SaveSettings",s);
};

// Saved games are kept per mode in SavedGame1..3 (Marathon, Timed, Survival).
_root.ReadGame = function()
{
   var r = _root;
   var so = r.HexicStore();
   var i = 1;
   while(i <= 3)
   {
      var g = so.data["game" + i];
      r["SavedGame" + i] = g == undefined ? "" : g;
      i++;
   }
};

_root.HexicSetSavedGame = function(mode, str)
{
   var r = _root;
   var so = r.HexicStore();
   so.data["game" + (mode + 1)] = str;
   so.flush();
   r["SavedGame" + (mode + 1)] = str;
};

_root.HexicOrigSaveGame = _root.SaveGame;
_root.SaveGame = function()
{
   var r = _root;
   r.HexicOrigSaveGame();
   r.HexicSetSavedGame(r._GameType,r._GameXMLString);
};

// Game over: record the score and drop the finished game's save.
_root.HexicOrigWriteXenonStats = _root.WriteXenonStats;
_root.WriteXenonStats = function()
{
   var r = _root;
   r.HexicOrigWriteXenonStats();
   r.HexicSetSavedGame(r._GameType,"");
   if(!(r._Score > 0))
   {
      return undefined;
   }
   var diff = "Easy";
   if(r._Difficulty == r.DF.Hard)
   {
      diff = "Hard";
   }
   else if(r._Difficulty == r.DF.Medium)
   {
      diff = "Medium";
   }
   var tag = String(r.GamerTag).split(",").join(" ");
   var clusters = Number(r.Stats.Combo[0] + r.Stats.Combo[1] + r.Stats.Combo[2] + r.Stats.Combo[3]);
   var entry = [tag,r._Score,diff,r._GameWin == true,clusters,r.Stats.Flowers,r.Stats.Pearls,r.Stats.Bombs,r.Stats.Bonus,r.Stats.BombBonus,r.Stats.Bonus3].join(",");
   var so = r.HexicStore();
   var key = "scores" + r._GameType;
   var list = so.data[key];
   if(list == undefined)
   {
      list = [];
   }
   var at = 0;
   while(at < list.length && Number(list[at].split(",")[1]) >= r._Score)
   {
      at++;
   }
   list.splice(at,0,entry);
   if(list.length > 100)
   {
      list.splice(100);
   }
   so.data[key] = list;
   so.flush();
};

// Stand-in for the Xbox Live leaderboard query: fills LeaderBoardResults0..9
// as "rank,gamertag,score,difficulty,won,clusters,flowers,pearls,bombs,bonuses,bbcombo,b3combo"
// then runs the LeaderBoardStats frame actions the host used to trigger.
_root.HexicLeaderBoardQuery = function(mode, first)
{
   var r = _root;
   var list = r.HexicStore().data["scores" + mode];
   if(list == undefined)
   {
      list = [];
   }
   var start = Number(first) < 1 ? 1 : Number(first);
   // "My Scores" asks for 0 (the page around the player on Xbox Live); every
   // local score is the player's, so start at the top and tell the paging
   // code, which treats 1 as the first page.
   r.LeaderboardTabs.LeaderBoardSelected = start;
   var i = 0;
   while(i < 10)
   {
      var idx = start - 1 + i;
      r["LeaderBoardResults" + i] = idx < list.length ? idx + 1 + "," + list[idx] : "";
      i++;
   }
   r.LeaderboardTabs.LeaderBoardTotalSize = list.length;
   // The Xbox answered asynchronously; calling the frame from inside the
   // key handler that triggered the query makes Ruffle replay that key.
   clearInterval(r.HexicStatsInterval);
   r.HexicStatsInterval = setInterval(function()
   {
      clearInterval(_root.HexicStatsInterval);
      call("LeaderBoardStats");
   },1);
};

// The Xbox shell's Flash player sized device text in screen pixels, about
// 1.375x the requested size, and ignored the scale of the clips containing
// the field (measured against captures of the original: the leaderboard
// table sits in a ~1.94x clip and its text is ~0.7x what desktop Flash
// draws, the 1.0x side panel ~1.38x). Re-size each field the same way.
_root.HexicTextScale = 1.375;
// Font names as the Xbox shell resolved them: it had no "Electrofied", so
// those strings fell back to its system font, Convection UI, while the
// "Convection UI" and "Arial" the game asks for everywhere else came out in
// its Arial Unicode MS (matched against console captures).
_root.HexicXboxFont = function(font)
{
   return font == "Electrofied" ? "Convection UI" : "Arial Unicode MS";
};
_root.HexicApplyTextSize = function(o)
{
   var fmt = o.getTextFormat();
   if(fmt.size == null || (fmt.size == o.hexicAppliedSize && fmt.font == o.hexicAppliedFont))
   {
      return undefined;
   }
   var scale = 1;
   var p = o;
   while(p != undefined && p != _root)
   {
      scale *= p._yscale / 100;
      p = p._parent;
   }
   if(!(scale > 0))
   {
      return undefined;
   }
   var resized = new TextFormat();
   resized.font = fmt.font == o.hexicAppliedFont ? fmt.font : _root.HexicXboxFont(fmt.font);
   resized.size = Math.round(fmt.size * _root.HexicTextScale / scale);
   o.setTextFormat(resized);
   o.setNewTextFormat(resized);
   o.hexicAppliedSize = resized.size;
   o.hexicAppliedFont = resized.font;
};
// Fields filled without the localizer (scores, gamertags, stats) and button
// labels re-created on highlight are found by walking the display list. The
// board's hundreds of piece clips hold no text (bomb digits are shapes) and
// made each walk cost ~15 ms, enough to starve Ruffle's audio, so they're
// skipped; the rest takes about a millisecond.
_root.HexicResizeTree = function(clip)
{
   for(var k in clip)
   {
      var v = clip[k];
      // Handhelds have an invisible pointer (PortMaster's virtual mouse) parked
      // mid-screen, which "hovers" whichever button sits there. Mouse input is
      // switched off for menu buttons; the D-pad highlight calls their
      // handlers directly, so it is unaffected.
      if(_root.HexicHandheld == "1" && k == "button" && v._parent == clip && v.enabled != false)
      {
         v.enabled = false;
      }
      if(v instanceof TextField)
      {
         if(v._parent == clip)
         {
            _root.HexicApplyTextSize(v);
         }
      }
      else if(typeof v == "movieclip" && v._parent == clip && v != _root.PieceBoard)
      {
         _root.HexicResizeTree(v);
      }
      else if(k == "text" && typeof v == "string")
      {
         _root.HexicLocalizeButton(clip);
      }
   }
};
// Button labels are fields named "text" bound to a variable "text". Ruffle
// resolves clip.text to the variable, so the game's
// Localizer.Loc(_parent.text, ...) calls never reach the field; the Xbox
// resolved the field and localised every label the same way. Lift the
// variable to reach the field and localise it here.
_root.HexicLocalizeButton = function(clip)
{
   var v = clip.text;
   if(typeof v != "string")
   {
      return undefined;
   }
   delete clip.text;
   var field = clip.text;
   clip.text = v;
   if(field instanceof TextField && field.hexicLocalized != true)
   {
      field.hexicLocalized = true;
      if(clip.ButtonText != undefined && clip.ButtonText != "UNLOCALIZED" && _root.Localizer.HexicOrigLoc != undefined)
      {
         _root.Localizer.HexicOrigLoc(field,clip.ButtonText);
      }
      _root.HexicApplyTextSize(field);
      // The game's .text.valign = "center" missed the field the same way.
      field.valign = "center";
      _root.HexicApplyVAlign(field);
   }
};
// Highlighting a button swaps in a new label (its "over"/"up" frame), at its
// raw authored size until localised; called from the button sprites so that
// happens in the same frame instead of on the next walk, which flickered.
// Which KeyboardAccessibility item (e.g. "Options") a button belongs to,
// found by asking each item of the current screen to highlight itself with the
// button handlers muted. The leaderboard's rows highlight through other code,
// so that screen is left alone.
_root.HexicItemIdFor = function(clip)
{
   var r = _root;
   var ka = r.KeyboardAccessibility;
   if(clip.hexicItemID != undefined || ka.CurrentState.ID == "LeaderBoard")
   {
      return clip.hexicItemID;
   }
   var map = ka.CurrentState.ObjectMap;
   var i = 0;
   while(i < map.length)
   {
      var item = ka.GetObject(map[i].ID);
      if(typeof item.Highlight == "function")
      {
         r.HexicProbing = true;
         r.HexicProbeFound = undefined;
         item.Highlight();
         r.HexicProbing = false;
         if(r.HexicProbeFound != undefined)
         {
            r.HexicProbeFound.hexicItemID = map[i].ID;
         }
      }
      i++;
   }
   return clip.hexicItemID;
};
_root.HexicWrapButtonHandlers = function(clip)
{
   var b = clip.button;
   var names = ["onRollOver","onRollOut","onDragOver","onDragOut","onPress","onRelease","onReleaseOutside"];
   var i = 0;
   while(i < names.length)
   {
      var original = b[names[i]];
      if(typeof original == "function" && original.hexicWrapped != true)
      {
         var wrapped = function()
         {
            var self = arguments.callee;
            var r = _root;
            var ka = r.KeyboardAccessibility;
            var over = self.handler == "onRollOver" || self.handler == "onDragOver";
            var out = self.handler == "onRollOut" || self.handler == "onDragOut";
            if(r.HexicProbing == true)
            {
               // HexicItemIdFor is asking which menu item drives this button.
               if(over)
               {
                  r.HexicProbeFound = self.clip;
               }
               return undefined;
            }
            // The player calls these for the mouse with no calling script;
            // the game's keyboard/D-pad code calls them from its own functions.
            var fromMouse = arguments.caller == null;
            var id = fromMouse && (over || out) ? r.HexicItemIdFor(self.clip) : undefined;
            if(over && !fromMouse)
            {
               self.clip.hexicItemID = ka.CurrentlyActiveID;
            }
            // One highlight at a time. The game tracks the D-pad selection and
            // the mouse hover separately; here hovering a button makes it the
            // selection, so the two never disagree.
            if(over && fromMouse && id != undefined)
            {
               if(id != ka.CurrentlyActiveID)
               {
                  ka.GetObject(ka.CurrentlyActiveID).UnHighlight();
                  ka.CurrentlyActiveID = id;
               }
            }
            else if(over && fromMouse)
            {
               // A button the menu code doesn't know: hover it on its own.
               var mouseClip = r.HexicMouseClip;
               r.HexicMouseClip = self.clip;
               if(mouseClip != undefined && mouseClip != self.clip)
               {
                  mouseClip.button.onRollOut();
               }
               ka.GetObject(ka.CurrentlyActiveID).UnHighlight();
            }
            else if(over && r.HexicMouseClip != undefined && r.HexicMouseClip != self.clip)
            {
               var hovered = r.HexicMouseClip;
               r.HexicMouseClip = undefined;
               hovered.button.onRollOut();
            }
            var result = self.original.apply(this,arguments);
            _root.HexicLocalizeButton(self.clip);
            if(out && fromMouse)
            {
               if(id != undefined && id == ka.CurrentlyActiveID)
               {
                  // Still the selection: stay lit after the pointer leaves.
                  ka.GetObject(id).Highlight();
               }
               else if(r.HexicMouseClip == self.clip)
               {
                  r.HexicMouseClip = undefined;
                  ka.GetObject(ka.CurrentlyActiveID).Highlight();
               }
            }
            return result;
         };
         wrapped.handler = names[i];
         wrapped.original = original;
         wrapped.clip = clip;
         wrapped.hexicWrapped = true;
         b[names[i]] = wrapped;
      }
      i++;
   }
};
if(_root.HexicResizeInterval == undefined)
{
   // Menus re-create button labels on every highlight change, so they are
   // walked 10 times a second; during play (InActiveScreen) text is sized
   // as the localizer sets it, so once a second is plenty and leaves the
   // CPU to the game, which matters on handhelds.
   _root.HexicResizeTick = 0;
   _root.HexicResizeInterval = setInterval(function()
   {
      var r = _root;
      r.HexicResizeTick++;
      if(r.KeyboardAccessibility.InActiveScreen != true || r.HexicResizeTick % 10 == 0)
      {
         r.HexicResizeTree(r);
      }
   },100);
}

// The Xbox Flash runtime honoured a non-standard TextField.valign property
// (the game sets valign = "center" on ~100 fields); desktop Flash ignores it.
// Emulate it whenever the localizer fills a field, by shifting the field
// down by half its unused height.
_root.HexicApplyVAlign = function(o)
{
   if(o.valign != "center")
   {
      return undefined;
   }
   if(o.hexicBaseY == undefined)
   {
      o.hexicBaseY = o._y;
   }
   var scale = o._yscale / 100;
   var free = o._height / scale - 4 - o.textHeight;
   o._y = o.hexicBaseY + (free > 0 ? free / 2 * scale : 0);
};
_root.HexicWrapLocalizer = function()
{
   var loc = _root.Localizer;
   if(loc.Loc == undefined)
   {
      return false;
   }
   if(loc.HexicOrigLoc == undefined)
   {
      loc.HexicOrigLoc = loc.Loc;
      loc.Loc = function(o, name)
      {
         _root.Localizer.HexicOrigLoc(o,name);
         _root.HexicApplyTextSize(o);
         _root.HexicApplyVAlign(o);
      };
   }
   return true;
};
if(!_root.HexicWrapLocalizer())
{
   _root.HexicWrapInterval = setInterval(function()
   {
      if(_root.HexicWrapLocalizer())
      {
         clearInterval(_root.HexicWrapInterval);
      }
   },10);
}

// KeyboardAccessibility.PerformAction keeps its loop counter in a register
// that the actions it calls overwrite under Ruffle, so a single press of a
// bound key (e.g. Right on the leaderboard) re-runs the loop and fires
// repeatedly. Same behaviour, but matches are collected before any runs.
_root.HexicPerformAction = function(KeyCode, ActionType)
{
   var ka = _root.KeyboardAccessibility;
   var map = ka.CurrentState.KeyMap;
   // A release only counts on the screen its press happened on. Otherwise
   // pressing Start in-game pauses on key-down and the key-up then lands on
   // the pause menu's default "Resume Game", unpausing at once.
   if(_root.HexicPressedIn == undefined)
   {
      _root.HexicPressedIn = new Object();
   }
   if(ActionType == "Press")
   {
      _root.HexicPressedIn[KeyCode] = ka.CurrentState.ID;
   }
   else if(ActionType == "Release")
   {
      var pressedIn = _root.HexicPressedIn[KeyCode];
      delete _root.HexicPressedIn[KeyCode];
      if(pressedIn != ka.CurrentState.ID)
      {
         return true;
      }
   }
   var hits = [];
   var i = 0;
   while(i < map.length)
   {
      if(map[i].Code == KeyCode)
      {
         hits.push(ka.GetObject(map[i].ObjectID));
      }
      i++;
   }
   i = 0;
   while(i < hits.length)
   {
      if(hits[i][ActionType])
      {
         hits[i][ActionType]();
      }
      i++;
   }
   if(KeyCode == 65 || KeyCode == 83)
   {
      var current = ka.GetObject(ka.CurrentlyActiveID);
      if(current[ActionType])
      {
         current[ActionType]();
      }
      if(ActionType == "Release" && current.Highlight)
      {
         current.Highlight();
      }
      return true;
   }
   return false;
};
_root.HexicPatchKeyboard = function()
{
   var ka = _root.KeyboardAccessibility;
   if(ka.PerformAction == undefined)
   {
      return false;
   }
   ka.PerformAction = _root.HexicPerformAction;
   return true;
};
if(!_root.HexicPatchKeyboard())
{
   _root.HexicKeyboardInterval = setInterval(function()
   {
      if(_root.HexicPatchKeyboard())
      {
         clearInterval(_root.HexicKeyboardInterval);
      }
   },10);
}

// Standalone players (the handheld port) have no host page to play the
// soundtrack, so with HexicMusic=swf the game streams it itself through its
// own music hooks (_MusicClip / M_current), which the Options volume and
// the pause screen already drive. The desktop app leaves this unset.
_root.HexicSoundtrack = ["Oilyn","Underlow","Slartisfgh","Cobblers","Belkell","Lubax","Badback","54"];
_root.HexicNextTrack = function()
{
   var r = _root;
   var n = r.HexicSoundtrack.length;
   var track = random(n);
   if(n > 1 && track == r.HexicLastTrack)
   {
      track = (track + 1 + random(n - 1)) % n;
   }
   r.HexicLastTrack = track;
   var music = new Sound(r._MusicClip);
   music.onSoundComplete = function()
   {
      _root.HexicNextTrack();
   };
   music.loadSound("music/" + r.HexicSoundtrack[track] + ".mp3",true);
   music.setVolume(!r._Muted ? r._Level_music * 100 : 0);
   r.M_current = music;
};
if(_root.HexicMusic == "swf" && _root.HexicMusicInterval == undefined)
{
   // Start once the player is past the splash screen, as the Xbox did.
   _root.HexicMusicInterval = setInterval(function()
   {
      var r = _root;
      var screen = r.KeyboardAccessibility.CurrentState.ID;
      if(r._MusicClip != undefined && screen != undefined && screen != "Splash")
      {
         clearInterval(r.HexicMusicInterval);
         r.HexicNextTrack();
      }
   },250);
}

// Handheld port: write the real frame rate to the log every 10 seconds
// ("HEXFPS 41.2 Active"), to judge performance settings on the device.
if(_root.HexicHandheld == "1" && _root.HexicFpsClip == undefined)
{
   _root.HexicFpsClip = _root.createEmptyMovieClip("HexicFpsClip",16000);
   _root.HexicFpsClip.frames = 0;
   _root.HexicFpsClip.since = getTimer();
   _root.HexicFpsClip.onEnterFrame = function()
   {
      this.frames++;
      var elapsed = getTimer() - this.since;
      if(elapsed >= 10000)
      {
         var screen = _root.KeyboardAccessibility.InActiveScreen == true ? "Active" : _root.KeyboardAccessibility.CurrentState.ID;
         trace("HEXFPS " + Math.round(this.frames * 10000 / elapsed) / 10 + " " + screen);
         this.frames = 0;
         this.since = getTimer();
      }
   };
}

// Y opens the leaderboards from the main menu or pause screen, as the
// Xbox guide button flow used to.
if(_root.HexicKeyListener == undefined)
{
   _root.HexicKeyListener = new Object();
   _root.HexicKeyListener.onKeyDown = function()
   {
      var r = _root;
      if(Key.getCode() != 89)
      {
         return undefined;
      }
      var st = r.KeyboardAccessibility.CurrentState.ID;
      if(st == "Menu" || st == "Pause")
      {
         r.IsPaused = st == "Pause";
         r.gotoAndStop("Leaderboard");
      }
   };
   Key.addListener(_root.HexicKeyListener);
}
