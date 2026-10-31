function onEnterFrame()
{
   var _loc1_ = _root;
   _loc1_.splash_txt.valign = "center";
   if(_loc1_.StartupMode == "SignedOut")
   {
      _loc1_.Localizer.Loc(_loc1_.splash_txt,"startup_signedout_text");
   }
   else if(_loc1_.StartupMode == "NoProfile")
   {
      _loc1_.Localizer.Loc(_loc1_.splash_txt,"startup_profile_text");
   }
   else
   {
      _loc1_.Localizer.Loc(_loc1_.splash_txt,"startup_text");
   }
   if(_loc1_._SplashPlayed == null)
   {
      _loc1_._SessReady = false;
      _loc1_._SplashPlayed = getTimer();
      _loc1_.InitSounds();
   }
   if(!RegisteredAccessibility && _loc1_.KeyboardAccessibility.RegisterActionableItem && _loc1_.KeyboardAccessibility.StateMap.length > 0)
   {
      RegisteredAccessibility = true;
      _loc1_.KeyboardAccessibility.RegisterActionableItem("OK",function()
      {
      }
      ,function()
      {
         PressedSplashButton = true;
      }
      ,function()
      {
      }
      ,function()
      {
      }
      ,function()
      {
         return true;
      }
      );
      _loc1_.KeyboardAccessibility.SetState("Splash","OK");
   }
   var _loc2_ = getTimer();
   var _loc3_ = _loc2_ - _loc1_._SplashPlayed;
   false;
   if(PressedSplashButton && _loc3_ > _loc1_.UI.SplashTime && _loc1_.Localizer.Loaded && _loc1_.S_WinGame.getBytesLoaded() >= _loc1_.S_WinGame.getBytesTotal())
   {
      _loc1_.StartupMode = "";
      _loc1_.SessionUpdate();
      _loc1_._ReceivedSessionStart = true;
      _loc1_.InitSession();
      this.onEnterFrame = _loc1_.DoGame;
      _loc1_.ReadSettings();
      _loc1_.ReadGame();
      fscommand("SessionReady","true");
      _loc1_.gotoAndStop("Menu");
   }
}
var RegisteredAccessibility = false;
var PressedSplashButton = false;
stop();
