onClipEvent(load){
   if(!_root._SignedInToLive)
   {
      _root.gotoAndStop("NoLive");
      return undefined;
   }
   this._alpha = 100;
   _root.Localizer.Loc(_root.LeaderboardTabs.marathon_hdr,"Leaderboard_Marathon_Text");
   _root.Localizer.Loc(_root.LeaderboardTabs.timed_hdr,"Leaderboard_Timed_Text");
   _root.Localizer.Loc(_root.LeaderboardTabs.survival_hdr,"Leaderboard_Survival_Text");
   _root.Localizer.Loc(_root.sortmode_hdr,"Leaderboard_FriendScores_Text");
   _root.Localizer.Loc(_root.changesortmode_hdr,"Leaderboard_Sort_Text");
   _root.Localizer.Loc(_root.back_txt,"credits_back");
   _root.Localizer.Loc(_root.signedin_hdr,"Leaderboard_SignedIn_Text");
   _root.signedin_txt.text = _root.GamerTag;
   _root.Localizer.Loc(_root.BreakoutScoreHeader,"leaderboard_score");
   _root.Localizer.Loc(_root.rank_txt,"rank_text");
   _root.Localizer.Loc(_root.gamertag_txt,"gamertag_text");
   _root.Localizer.Loc(_root.score_txt,"score_text");
   _root.Localizer.Loc(_root.difficulty_txt,"difficulty_text");
   var GM_Marathon = 0;
   var GM_Timed = 1;
   var GM_Survival = 2;
   var SO_Friends = 0;
   var SO_MyScores = 1;
   var SO_Overall = 2;
   var GameMode = GM_Marathon;
   var SortOrder = SO_Friends;
   var LeaderBoardSelected = 1;
   var LeaderBoardHighlighted = 0;
   var LeaderBoardTotalSize = 0;
   fscommand("LeaderBoardGameMode",GameMode);
   fscommand("LeaderBoardSortOrder",SortOrder);
   var UpdateLeaderBoard = function()
   {
      var _loc1_ = _root;
      _loc1_.breakoutcover._visible = true;
      _loc1_.uparrow.gotoAndStop("no");
      _loc1_.downarrow.gotoAndStop("no");
      _loc1_.BreakoutClusters.text = "";
      _loc1_.BreakoutFlowers.text = "";
      _loc1_.BreakoutPearls.text = "";
      _loc1_.BreakoutBombs.text = "";
      _loc1_.BreakoutBonuses.text = "";
      _loc1_.BreakoutBBCombos.text = "";
      _loc1_.BreakoutB3Combos.text = "";
      _loc1_.BreakoutScore.text = "";
      _loc1_.BreakoutDifficulty.text = "";
      fscommand("LeaderBoardQuery",LeaderBoardSelected);
      _root.HexicLeaderBoardQuery(GameMode,LeaderBoardSelected);
   };
   var RedrawLeaderboard = function()
   {
      switch(GameMode)
      {
         case GM_Marathon:
            _root.LeaderboardTabs.gotoAndStop("Marathon");
            break;
         case GM_Timed:
            _root.LeaderboardTabs.gotoAndStop("Timed");
            break;
         case GM_Survival:
            _root.LeaderboardTabs.gotoAndStop("Survival");
      }
      switch(SortOrder)
      {
         case SO_Friends:
            _root.Localizer.Loc(_root.sortmode_hdr,"Leaderboard_FriendScores_Text");
            break;
         case SO_MyScores:
            _root.Localizer.Loc(_root.sortmode_hdr,"Leaderboard_MyScores_Text");
            break;
         case SO_Overall:
            _root.Localizer.Loc(_root.sortmode_hdr,"Leaderboard_TopScores_Text");
      }
      var i = 0;
      while(i < 10)
      {
         eval("_parent.leaderboardline" + i).FillInfo(null);
         i++;
      }
      _root.NobodyBox._visible = false;
      UpdateLeaderBoard();
   };
   var GoBack = function()
   {
      var _loc1_ = _root;
      if(!_loc1_.IsPaused)
      {
         _loc1_.gotoAndStop("Menu");
      }
      else
      {
         _loc1_.gotoAndStop("Pause");
      }
   };
   var Righter = function()
   {
      if(GameMode < 2)
      {
         GameMode++;
         LeaderBoardSelected = SortOrder != SO_MyScores ? 1 : 0;
         LeaderBoardHighlighted = 0;
         fscommand("LeaderBoardGameMode",GameMode);
         RedrawLeaderboard();
      }
   };
   var Lefter = function()
   {
      if(GameMode > 0)
      {
         GameMode--;
         LeaderBoardSelected = SortOrder != SO_MyScores ? 1 : 0;
         LeaderBoardHighlighted = 0;
         fscommand("LeaderBoardGameMode",GameMode);
         RedrawLeaderboard();
      }
   };
   var ChangeSortOrder = function()
   {
      SortOrder = (SortOrder + 1) % 3;
      LeaderBoardSelected = SortOrder != SO_MyScores ? 1 : 0;
      LeaderBoardHighlighted = 0;
      fscommand("LeaderBoardSortOrder",SortOrder);
      RedrawLeaderboard();
   };
   var LessInfo = function()
   {
      if(_root.uparrow._currentframe == 1)
      {
         return undefined;
      }
      if(LeaderBoardSelected == 1)
      {
         return undefined;
      }
      LeaderBoardSelected -= 10;
      LeaderBoardHighlighted = 9;
      if(LeaderBoardSelected < 1)
      {
         LeaderBoardHighlighted += LeaderBoardSelected - 1;
         LeaderBoardSelected = 1;
      }
      RedrawLeaderboard();
   };
   var MoreInfo = function()
   {
      var _loc1_;
      if(_root.downarrow._currentframe != 1)
      {
         _loc1_ = Number(LeaderBoardSelected) + 10;
         if(_loc1_ <= LeaderBoardTotalSize)
         {
            LeaderBoardSelected = _loc1_;
            LeaderBoardHighlighted = 0;
            RedrawLeaderboard();
         }
      }
   };
   _root.KeyboardAccessibility.RegisterActionableItem("Back",GoBack,null,null,null,function()
   {
      return false;
   }
   );
   _root.KeyboardAccessibility.RegisterActionableItem("Lefter",Lefter,null,null,null,function()
   {
      return false;
   }
   );
   _root.KeyboardAccessibility.RegisterActionableItem("Righter",Righter,null,null,null,function()
   {
      return false;
   }
   );
   _root.KeyboardAccessibility.RegisterActionableItem("SortOrder",ChangeSortOrder,null,null,null,function()
   {
      return false;
   }
   );
   _root.KeyboardAccessibility.RegisterActionableItem("LessScores",null,null,null,null,function()
   {
      _root.LeaderboardTabs.LessInfo();
      return false;
   }
   );
   _root.KeyboardAccessibility.RegisterActionableItem("MoreScores",null,null,null,null,function()
   {
      _root.LeaderboardTabs.MoreInfo();
      return false;
   }
   );
   this.onEnterFrame = function()
   {
      this.onEnterFrame = function()
      {
         if(!_root._SignedInToLive)
         {
            _root.gotoAndStop("NoLive");
         }
      };
      var RegisterInfoLine = function(line, index)
      {
         var _loc2_ = function()
         {
            fscommand("ShowGamercard",index);
         };
         var _loc1_ = function()
         {
            line.myRollOver();
         };
         var _loc3_ = function()
         {
            line.myRollOut();
         };
         var Valid = function()
         {
            return line.fValid;
         };
         _root.KeyboardAccessibility.RegisterActionableItem("Score" + index,_loc2_,null,_loc1_,_loc3_,Valid);
      };
      var i = 0;
      while(i < 10)
      {
         RegisterInfoLine(eval("_parent.leaderboardline" + i),i);
         i++;
      }
      _root.KeyboardAccessibility.SetState("LeaderBoard");
      RedrawLeaderboard();
   };
}
