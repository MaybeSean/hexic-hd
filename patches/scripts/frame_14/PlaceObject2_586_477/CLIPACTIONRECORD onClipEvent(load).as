onClipEvent(load){
   ButtonText = "menuButton_exittodash";
   this.text.valign = "center";
   _root.Localizer.Loc(this.text,ButtonText);
   _root.KeyboardAccessibility.RegisterActionableItem("Exit",function()
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
      _loc1_.Localizer.Loc(_loc1_.ToolTip.tip_txt,"main_exittodashtooltip_text");
   };
   this.myPress = function()
   {
      _root._SoundMask |= _root.SF.ButtonDown;
   };
   this.myRelease = function()
   {
      _root._SoundMask |= _root.SF.ButtonUp;
      fscommand("ReturnToArcade");
      // Standalone players (the handheld port) quit on "quit"; the Xbox shell and the desktop app use ReturnToArcade.
      fscommand("quit");
   };
}
