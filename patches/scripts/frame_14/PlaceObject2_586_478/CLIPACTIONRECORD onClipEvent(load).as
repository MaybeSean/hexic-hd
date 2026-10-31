onClipEvent(load){
   // Leaderboards entry from the later title update's main menu; added by
   // tools/menu_layout.py as a copy of the Options button.
   ButtonText = "menuButton_leaderboard";
   this.text.valign = "center";
   _root.Localizer.Loc(this.text,ButtonText);
   _root.KeyboardAccessibility.RegisterActionableItem("Leaderboard",function()
   {
      button.onPress();
   }
   ,function()
   {
      button.onRelease();
   }
   ,function()
   {
      button.onRollOver();
   }
   ,function()
   {
      button.onRollOut();
   }
   ,function()
   {
      return true;
   }
   );
   this.myRollOver = function()
   {
      var _loc1_ = _root;
      _loc1_.ToolTip.tip_txt.valign = "center";
      _loc1_.Localizer.Loc(_loc1_.ToolTip.tip_txt,"main_leaderboardtooltip_text");
   };
   this.myPress = function()
   {
      _root._SoundMask |= _root.SF.ButtonDown;
   };
   this.myRelease = function()
   {
      var _loc1_ = _root;
      _loc1_._SoundMask |= _loc1_.SF.ButtonUp;
      _loc1_.IsPaused = false;
      _loc1_.gotoAndStop("Leaderboard");
   };
   // The update's taller panel has rounded top corners that follow the
   // frame; the stretched original is square, so mask its top. The mask
   // lives in this button, which leaves with the menu.
   this.onEnterFrame = function()
   {
      this.onEnterFrame = null;
      var panel = _root.hexicMenuPanel;
      var b = panel.getBounds(_root);
      var radius = 42;
      var mask = this.createEmptyMovieClip("hexicPanelMask",1);
      var me = this;
      var pt = function(x, y)
      {
         var p = {x:x,y:y};
         me.globalToLocal(p);
         return p;
      };
      var a = pt(b.xMin,b.yMax);
      var c;
      var e;
      mask.beginFill(0,100);
      mask.moveTo(a.x,a.y);
      a = pt(b.xMin,b.yMin + radius);
      mask.lineTo(a.x,a.y);
      c = pt(b.xMin,b.yMin);
      e = pt(b.xMin + radius,b.yMin);
      mask.curveTo(c.x,c.y,e.x,e.y);
      a = pt(b.xMax - radius,b.yMin);
      mask.lineTo(a.x,a.y);
      c = pt(b.xMax,b.yMin);
      e = pt(b.xMax,b.yMin + radius);
      mask.curveTo(c.x,c.y,e.x,e.y);
      a = pt(b.xMax,b.yMax);
      mask.lineTo(a.x,a.y);
      mask.endFill();
      panel.setMask(mask);
   };
}
