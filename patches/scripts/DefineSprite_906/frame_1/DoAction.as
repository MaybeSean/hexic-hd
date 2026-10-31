onLoad();
this.tooltip._xscale = 0;
this.tooltip._yscale = 0;
this.antitooltip._xscale = 100;
this.antitooltip._yscale = 100;
this.fValid = false;
this.myRollOver = function()
{
   var _loc1_ = this;
   if(_loc1_.fValid)
   {
      _loc1_.tooltip._xscale = 100;
      _loc1_.tooltip._yscale = 100;
      _loc1_.antitooltip._xscale = 0;
      _loc1_.antitooltip._yscale = 0;
   }
};
this.myRollOut = function()
{
   var _loc1_ = this;
   _loc1_.tooltip._xscale = 0;
   _loc1_.tooltip._yscale = 0;
   _loc1_.antitooltip._xscale = 100;
   _loc1_.antitooltip._yscale = 100;
};
this.FillInfo = function(highscore, clr)
{
   var _loc1_ = this;
   var _loc2_ = highscore;
   var _loc3_ = clr;
   if(_loc2_.score > 0)
   {
      _loc1_.fValid = true;
      _loc1_.name.text = _loc2_.name;
      _loc1_.level.text = _loc2_.level;
      _loc1_.score.text = _loc2_.score;
      _loc1_.star.gotoAndStop(!_loc2_.won ? "none" : "win");
      _loc1_.tooltip.time.text = _loc2_.time;
      _loc1_.tooltip.date.text = _loc2_.date;
      _loc1_.tooltip.clusters.text = _loc2_.clusters;
      _loc1_.tooltip.flowers.text = _loc2_.flowers;
      _loc1_.tooltip.pearls.text = _loc2_.pearls;
      _loc1_.tooltip.bombs.text = _loc2_.bombs;
      _loc1_.tooltip.bonuses.text = _loc2_.bonuses;
      _loc1_.tooltip.bbcombo.text = _loc2_.bbcombo;
      _loc1_.tooltip.b3combo.text = _loc2_.b3combo;
      _loc1_.onRollOver = _loc1_.myRollOver;
      _loc1_.onRollOut = _loc1_.myRollOut;
      _loc1_.useHandCursor = true;
   }
   else
   {
      _loc1_.fValid = false;
      _loc1_.name.text = "---";
      _loc1_.level.text = "---";
      _loc1_.score.text = "---";
      _loc1_.star.gotoAndStop("none");
      _loc1_.onRollOver = null;
      _loc1_.onRollOut = null;
      _loc1_.useHandCursor = false;
   }
   _loc1_.level.textColor = _loc3_;
   _loc1_.name.textColor = _loc3_;
   _loc1_.score.textColor = _loc3_;
};
this.DoMyUpdate();
// Handheld port: see the button sprites; leaderboard rows hover on the clip itself.
if(_root.HexicHandheld == "1")
{
   this.enabled = false;
}
