onLoad();
this.tooltip._xscale = 0;
this.tooltip._yscale = 0;
this.antitooltip._xscale = 100;
this.antitooltip._yscale = 100;
this.fValid = false;
this.myRollOver = function(n)
{
   var _loc1_ = this;
   var _loc2_ = _root;
   if(_loc1_.fValid)
   {
      _loc1_.tooltip._xscale = 100;
      _loc1_.tooltip._yscale = 100;
      _loc1_.antitooltip._xscale = 0;
      _loc1_.antitooltip._yscale = 0;
      _loc2_.breakoutcover._visible = false;
      _loc2_.BreakoutClusters.text = _loc1_.tooltip_clusters;
      _loc2_.BreakoutFlowers.text = _loc1_.tooltip_flowers;
      _loc2_.BreakoutPearls.text = _loc1_.tooltip_pearls;
      _loc2_.BreakoutBombs.text = _loc1_.tooltip_bombs;
      _loc2_.BreakoutBonuses.text = _loc1_.tooltip_bonuses;
      _loc2_.BreakoutBBCombos.text = _loc1_.tooltip_bbcombo;
      _loc2_.BreakoutB3Combos.text = _loc1_.tooltip_b3combo;
      _loc2_.BreakoutScore.text = _loc1_.score_txt.text;
      _loc2_.Localizer.Loc(_loc2_.BreakoutDifficulty,_loc1_.difficulty);
   }
};
this.myRollOut = function(n)
{
   var _loc1_ = this;
   _loc1_.tooltip._xscale = 0;
   _loc1_.tooltip._yscale = 0;
   _loc1_.antitooltip._xscale = 100;
   _loc1_.antitooltip._yscale = 100;
};
this.FillInfo = function(leaderboard, clr)
{
   var _loc1_ = this;
   var _loc2_ = leaderboard;
   var _loc3_ = clr;
   _loc1_.tooltip._xscale = 0;
   _loc1_.tooltip._yscale = 0;
   _loc1_.antitooltip._xscale = 100;
   _loc1_.antitooltip._yscale = 100;
   if(_loc2_.score > 0)
   {
      _loc1_.fValid = true;
      _loc1_.rank_txt.text = _loc2_.rank;
      _loc1_.gamertag_txt.text = _loc2_.gamertag;
      _loc1_.score_txt.text = _loc2_.score;
      _loc1_.tooltip_clusters = _loc2_.clusters;
      _loc1_.tooltip_flowers = _loc2_.flowers;
      _loc1_.tooltip_pearls = _loc2_.pearls;
      _loc1_.tooltip_bombs = _loc2_.bombs;
      _loc1_.tooltip_bonuses = _loc2_.bonuses;
      _loc1_.tooltip_bbcombo = _loc2_.bbcombo;
      _loc1_.tooltip_b3combo = _loc2_.b3combo;
      _loc1_.difficulty = _loc2_.difficulty;
      _loc1_.onRollOver = _loc1_.myRollOver;
      _loc1_.onRollOut = _loc1_.myRollOut;
   }
   else
   {
      _loc1_.fValid = false;
      _loc1_.rank_txt.text = "";
      _loc1_.gamertag_txt.text = "";
      _loc1_.score_txt.text = "";
      _loc1_.tooltip_clusters = "";
      _loc1_.tooltip_flowers = "";
      _loc1_.tooltip_pearls = "";
      _loc1_.tooltip_bombs = "";
      _loc1_.tooltip_bonuses = "";
      _loc1_.tooltip_bbcombo = "";
      _loc1_.tooltip_b3combo = "";
      _loc1_.onRollOver = null;
      _loc1_.onRollOut = null;
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
