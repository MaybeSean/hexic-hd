onLoad();
this.button.onDragOut = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("over");
   _loc1_._parent.myDragOut();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
this.button.onDragOver = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("down");
   _loc1_._parent.myDragOut();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
this.button.onRollOver = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("over");
   _loc1_._parent.myRollOver();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
this.button.onRollOut = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("up");
   _loc1_._parent.myRollOut();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
this.button.onPress = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("down");
   _loc1_._parent.myPress();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
this.button.onReleaseOutside = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("up");
   _loc1_._parent.myReleaseOutside();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
this.button.onRelease = function()
{
   var _loc1_ = this;
   _loc1_._parent.gotoAndStop("over");
   _loc1_._parent.myRelease();
   _loc1_._parent.text.valign = "center";
   if(_loc1_._parent.ButtonText != "UNLOCALIZED")
   {
      _root.Localizer.Loc(_loc1_._parent.text,_loc1_._parent.ButtonText);
   }
   else
   {
      _loc1_._parent.text.text = _loc1_._parent.UnlocalizedButtonText;
   }
};
stop();
// Handheld port: PortMaster's virtual mouse leaves an invisible pointer
// mid-screen that would "hover" whatever button appears under it. Mouse
// input is off from the moment the button exists; the D-pad highlight
// calls the handlers directly and is unaffected.
if(_root.HexicHandheld == "1")
{
   this.button.enabled = false;
}
_root.HexicWrapButtonHandlers(this);
