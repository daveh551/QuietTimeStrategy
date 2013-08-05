//+------------------------------------------------------------------+
//|                                                     RunTests.mq4 |
//|                                                       Dave Hanna |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Dave Hanna"
#property link      "http://nohypeforexrobotreview.com"

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2005

//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);

// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import

//+------------------------------------------------------------------+
//| EX4 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex4"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
void RunTests()
{

   int totalTests = 0;
   int testsPassed = 0;
   
   Print("Beginning Unit Tests");
   // Run the individual tests

   if (CanCalculateBrokerStartTime())
      testsPassed++;
   totalTests++;
   if (CanCalculateBrokerEndTime())
      testsPassed++;
   totalTests++;  
   if (CanCalculateBrokerTermTime())
      testsPassed++;
   totalTests++;  
   if (BeforeWindowReturnsFalse())
      testsPassed++;
   totalTests++;
   if (InWindowReturnsTrue())
      testsPassed++;
   totalTests++;
   if (AfterWindowReturnsFalse())
      testsPassed++;
   totalTests++;
   if (AfterTermBumpsWindowTimes())
      testsPassed++;
   totalTests++;
   if (CalculateTargetsReturnsSL())
      testsPassed++;
   totalTests++;
   if (CalculateTargetsReturnsTP())
      testsPassed++;
   totalTests++;
   if (ShldClseFPriceBetweenTargets())
		testsPassed++;
	totalTests++;
	if (ShldClsTPriceLowThanStopLoss())
		testsPassed++;
	totalTests++;
	if (ShldClsTPriceHiTakeProfit())
		testsPassed++;
	totalTests++;
	if (ShldClsFSpreadSplittingTP())
		testsPassed++;
	totalTests++;
   if (SShldClseFPriceBetweenTargets())
		testsPassed++;
	totalTests++;
	if (SShldClsTPriceHiStopLoss())
		testsPassed++;
	totalTests++;
	if (SShldClsTPriceLowerTP())
		testsPassed++;
	totalTests++;
	if (SShldClsFSpreadSplittingTP())
		testsPassed++;
	totalTests++;
   
   Print("Completed tests. ", testsPassed, " of ", totalTests, " passed.");
   
 
}

bool CanCalculateBrokerStartTime()
{
   Print("Starting CanCalculateBrokerStartTime()");
   SetupBrokerTestTimes();
   return (Assert(TimeToStr(brokerQTStart, TIME_MINUTES) == "15:00", "Wrong start time"));   
}

void SetupBrokerTestTimes()
{
   string saveQuietTimeStart = QuietTimeStart;
   string saveQuietTimeEnd = QuietTimeEnd;
   string saveQuietTimeTerminate = QuietTimeTerminate;
   QuietTimeStart = "14:00";
   QuietTimeEnd = "18:00";
   QuietTimeTerminate = "01:00";
   CalculateBrokerTimes();
   QuietTimeStart = saveQuietTimeStart;
   QuietTimeEnd = saveQuietTimeEnd;
   QuietTimeTerminate = saveQuietTimeTerminate;
}

bool CanCalculateBrokerEndTime()
{
   Print("Starting CanCalculateBrokerEndTime()");
   SetupBrokerTestTimes();
   return (Assert(TimeToStr(brokerQTEnd, TIME_MINUTES) == "19:00", "Wrong end time"));   
}

bool CanCalculateBrokerTermTime()
{
   Print("Starting CanCalculateBrokerTermTime()");
   SetupBrokerTestTimes();
   Print("CanCalculateBrokerTermTime. brokerQTTerminate= ", TimeToStr(brokerQTTerminate, TIME_MINUTES));
   return (Assert(TimeToStr(brokerQTTerminate, TIME_MINUTES) == "02:00", "Wrong termination time"));   
}
//Time Window tests
bool BeforeWindowReturnsFalse()
{
   Print ("Beginning BeforeWindowReturnsFalse()");
   SetupBrokerTestTimes();
   return (Assert(!TimeWindowToTrade(StrToTime(StringConcatenate(TimeToStr(TimeLocal(), TIME_DATE), " 10:00"))), "TimeToTradeWindow(10:00) returned true"));
   
}

bool InWindowReturnsTrue()
{
   Print ("Beginning InWindowReturnsTrue()");
   SetupBrokerTestTimes();
   return (Assert(TimeWindowToTrade(StrToTime(StringConcatenate(TimeToStr(TimeLocal(), TIME_DATE), " 16:00"))), "TimeToTradeWindow(16:00) returned false"));
   
}

bool AfterWindowReturnsFalse()
{
   Print ("Beginning AfterWindowReturnsFalse()");
   SetupBrokerTestTimes();
   return (Assert(!TimeWindowToTrade(StrToTime(StringConcatenate(TimeToStr(TimeLocal(), TIME_DATE), " 20:00"))), "TimeToTradeWindow(20:00) returned true"));
}

bool AfterTermBumpsWindowTimes()
{
   Print ("Beginning AfterTermBumpsWindowTimes()");
   SetupBrokerTestTimes();
   datetime startingQTStart = brokerQTStart;
   datetime startingQTEnd = brokerQTEnd;
   datetime startingQTTerminate = brokerQTTerminate;
   bool windowResult = TimeWindowToTrade(StrToTime(StringConcatenate(TimeToStr(TimeLocal() + 86400, TIME_DATE), " 03:00")));
   return (Assert (!windowResult, "TimeToTrade after terminate returned true") &&
      Assert (brokerQTStart == startingQTStart + 86400, "BrokerQTStart not bumped") &&
      Assert (brokerQTEnd == startingQTEnd + 86400, "BrokerQTEnd not bumped") &&
      Assert (brokerQTTerminate == startingQTTerminate + 86400, "BrokerQTTerminate not bumped"));
    return (false); 
}

bool CalculateTargetsReturnsSL()
{
   double stopLoss =0.0;
   double takeProfit = 0.0;
   Print ("Entering CalculateTargetsReturnsSL. Price=1.35931, spread = .0007, FiveDig=", FiveDig, ", Point=", DoubleToStr(Point, 5));
//void CalculateTargets(double price, double spread, int tradeType, int stopLossPips, int targetPips, double& stopLostPrice, double& targetPrice)
//   stopLossPrice = price - tradeType * stopLossPips * FiveDig * Point - tradeType * spread;
   Print ("tradeType * stopLossPips * FiveDig * Point =",  DoubleToStr(-1 * 12 * FiveDig * Point, 5));
   Print ("tradeType * spread = ", DoubleToStr(-1 * 0.0007, 5));
   CalculateTargets(1.35931, 0.0007, -1, 12, 10, stopLoss, takeProfit);
   Print ("Calculate Targets returns stopLoss of ", DoubleToStr(stopLoss, 10));
   return (Assert(NormalizeDouble(stopLoss,5) == 1.36121, "Wrong StopLoss"));
}

bool CalculateTargetsReturnsTP()
{
   double takeProfit =  0.0;
   double stopLoss = 0.0;
   Print ("Entering CalculateTargetsReturnsTP. Price=1.35931, spread = .0007, FiveDig=", FiveDig, ", Point=", DoubleToStr(Point, 5));
   // targetPrice = price + tradeType * targetPips * FiveDig * Point;   
  CalculateTargets(1.35931, 0.0007, -1, 12, 10, stopLoss, takeProfit);
   Print ("Calculate Targets returns takeProfit of ", DoubleToStr(takeProfit, 10));
   return (Assert(NormalizeDouble(takeProfit,5) == 1.35831, "Wrong TakeProfit"));
}

bool ShldClseFPriceBetweenTargets()
{
/*******************************************/
/* Scenario - Buy EURCAD at 1.3523
/*            Stop at 1.3511
/*            TP at 1.3533
/*            Bid at 1.3525
/*            Ask at 1.3527
/*  ShouldClose should return false  
/*******************************************/

	Print ("Entering ShouldCloseReturnsFalseForPriceBetweenTargets");
	SetupTrade(OP_BUY);
	bool result = ShouldClose(0, 1.3525, 1.3527, 1.3511);
	return (Assert(result == false, "ShouldClose returned true instead of false"));
}
bool ShldClsTPriceLowThanStopLoss()
/*******************************************/
/* Scenario - Buy EURCAD at 1.3523
/*            Stop at 1.3511
/*            TP at 1.3533
/*            Bid at 1.35109
/*            Ask at 1.3512
/*  ShouldClose should return true  
/*******************************************/
{
	Print ("Entering ShouldCloseReturnsTrueForPriceLowerThanStopLoss");
	SetupTrade(OP_BUY);
	bool result = ShouldClose(0, 1.35109, 1.3512, 1.3511);
	return (Assert(result , "ShouldClose returned false instead of true"));
}
bool ShldClsTPriceHiTakeProfit()
/*******************************************/
/* Scenario - Buy EURCAD at 1.3523
/*            Stop at 1.3511
/*            TP at 1.3533
/*            Bid at 1.3533
/*            Ask at 1.3535
/*  ShouldClose should return true  
/*******************************************/
{
	Print ("Entering ShouldCloseReturnsTrueForPriceHigherThanTakeProfit");
	SetupTrade(OP_BUY);
	bool result = ShouldClose(0, 1.35331, 1.3535, 1.3533);
	return (Assert(result , "ShouldClose returned false instead of true"));
}
bool ShldClsFSpreadSplittingTP()
/*******************************************/
/* Scenario - Buy EURCAD at 1.3523
/*            Stop at 1.3511
/*            TP at 1.3533
/*            Bid at 1.3532
/*            Ask at 1.3534
/*  ShouldClose should return false  
/*******************************************/
{
	Print ("Entering ShouldCloseReturnsFalseForSpreadSplittingTakeProfit");
	SetupTrade(OP_BUY);
	bool result = ShouldClose(0, 1.3532, 1.3534, 1.3533);
	return (Assert(result==false , "ShouldClose returned true instead of false"));
}
bool SShldClseFPriceBetweenTargets()
{
/*******************************************/
/* Scenario - SELL EURCAD at 1.3523
/*            Stop at 1.3535
/*            TP at 1.3513
/*            Bid at 1.3525
/*            Ask at 1.3527
/*  ShouldClose should return false  
/*******************************************/

	Print ("Entering Sell_ShouldCloseReturnsFalseForPriceBetweenTargets");
	SetupTrade(OP_SELL);
	bool result = ShouldClose(0, 1.3525, 1.3527, 1.3535);
	return (Assert(result == false, "ShouldClose returned true instead of false"));
}
bool SShldClsTPriceHiStopLoss()
/*******************************************/
/* Scenario - SELL EURCAD at 1.3523
/*            Stop at 1.3535
/*            TP at 1.3513
/*            Bid at 1.3535
/*            Ask at 1.3537
/*  ShouldClose should return true  
/*******************************************/
{
	Print ("Entering Sell_ShouldCloseReturnsTrueForPriceHigherThanStopLoss");
	SetupTrade(OP_SELL);
	bool result = ShouldClose(0, 1.3533, 1.35351, 1.3535);
	return (Assert(result , "ShouldClose returned false instead of true"));
}
bool SShldClsTPriceLowerTP()
/*******************************************/
/* Scenario - SELL EURCAD at 1.3523
/*            Stop at 1.3535
/*            TP at 1.3513
/*            Bid at 1.3511
/*            Ask at 1.3513
/*  ShouldClose should return true  
/*******************************************/
{
	Print ("Entering Sell_ShouldCloseReturnsTrueForPriceHigherThanTakeProfit");
	SetupTrade(OP_SELL);
	bool result = ShouldClose(0, 1.3511, 1.35129, 1.3513);
	return (Assert(result , "ShouldClose returned false instead of true"));
}
bool SShldClsFSpreadSplittingTP()
/*******************************************/
/* Scenario - SELL EURCAD at 1.3523
/*            Stop at 1.3535
/*            TP at 1.3513
/*            Bid at 1.3513
/*            Ask at 1.3515
/*  ShouldClose should return false  
/*******************************************/
{
	Print ("Entering Sell_ShouldCloseReturnsFalseForSpreadSplittingTakeProfit");
	SetupTrade(OP_SELL);
	bool result = ShouldClose(0, 1.3513, 1.3515, 1.3513);
	return (Assert(result == false, "ShouldClose returned true instead of false"));
}

void SetupTrade(int op)
{
	int ticketIndex = 0;
	openTicketNumbers[ticketIndex] = 12345;
	openPrice[ticketIndex] = 1.3523;
	orderType[ticketIndex] = op;
	if (op == OP_BUY)
	{
	tradeSL[ticketIndex] = 1.3511;
	tradeTP[ticketIndex] = 1.3533;
	}
	else
	{
		tradeSL[ticketIndex] = 1.3535;
		tradeTP[ticketIndex] = 1.3513;
	}
}
