//+------------------------------------------------------------------+
//|                                          Quiet Time Strategy.mq4 |
//|                                                       Dave Hanna |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Dave Hanna"
#property link      "http://nohypeforexrobotreview.com"
#include <Assert.mqh>
//--- input parameters
extern string  QuietTimeStart="15:00";
extern string  QuietTimeEnd="19:00";
extern string  QuietTimeTerminate="02:00";
extern bool    TradeSunday=false;
extern bool    TradeFriday=false;
extern int       TriggerPipsFromQTEntry=15;

extern int       StopLossPips=12;
extern int       TargetPops=10;
extern int       MaximumSpread=6;
extern bool      Testing=false;

//Global variables
double QuietTimeEntryPrice;   // The bid price at the start of quiet time.
datetime brokerQTStart;       // The Quiet Time startTime in broker timezone
datetime brokerQTEnd;
datetime brokerQTTerminate;
int serverOffsetFromLocal = -1;
datetime serverFirstBar = 0;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   if (Testing)
      RunTests();
   CalculateBrokerTimes();
     
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
      serverOffsetFromLocal = -1;
      serverFirstBar = 0;
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
   if (serverOffsetFromLocal == -1)
   {
      CalculateBrokerTimes();   
   }
   if (serverOffsetFromLocal == -1) return (0);
//----
   if (TradesOpen() > 0)
      if (ManageOpenTrade()) return(0);
      
   if (!TimeWindowToTrade(iTime(NULL, PERIOD_M1, 0))) return (0);
   if (QuietTimeEntryPrice == 0.00)
   {
      QuietTimeEntryPrice = GetQuietTimeEntryPrice();
   }
   int typeTrade = ShouldTrade();
   if (typeTrade == 0) return(0);
   PlaceTrade(typeTrade, Symbol());
//----
   return(0);
  }
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
   
   Print("Completed tests. ", testsPassed, " of ", totalTests, " passed.");
   
 
}



bool TimeWindowToTrade(datetime time)
{
   //Print("time param = ", TimeToStr(time), " Start = ", TimeToStr(brokerQTStart), " End= ", TimeToStr(brokerQTEnd));
   bool result = ((time >= brokerQTStart) && (time <= brokerQTEnd));
   if (time > brokerQTTerminate)
   {
      // Advance window times for next day's trading
      brokerQTStart += 86400;
      brokerQTEnd += 86400; 
      brokerQTTerminate += 86400;
   }
   return (result);
}

double GetQuietTimeEntryPrice()
{
   return (1.0);
}

int ShouldTrade()
{
   return (0);
}

void PlaceTrade(int tradeType, string symbol)
{
}

void CalculateBrokerTimes()
{
   if (serverOffsetFromLocal == -1) 
   {
      serverOffsetFromLocal = FindServerOffset();
   }
   if (serverOffsetFromLocal == -1) return;
   datetime localNow = TimeLocal();
   string localDateString = TimeToStr(localNow, TIME_DATE);
   string localStartString = StringConcatenate(localDateString, " " , QuietTimeStart);
   string localEndString = StringConcatenate(localDateString, " " , QuietTimeEnd);
   string localTermString = StringConcatenate(localDateString, " " , QuietTimeTerminate);
   Print(localDateString, " " , localStartString, " ", localEndString, " " , localTermString);
   datetime localStart = StrToTime(localStartString);
   datetime localEnd = StrToTime(localEndString);
   datetime localTerm = StrToTime(localTermString);
   if (localEnd < localStart) localEnd += 86400;
   if (localTerm < localEnd) localTerm += 86400;
   brokerQTStart = localStart + serverOffsetFromLocal;
   brokerQTEnd = localEnd + serverOffsetFromLocal;
   brokerQTTerminate = localTerm + serverOffsetFromLocal;
   Print (TimeToStr(brokerQTStart), " ", TimeToStr(brokerQTEnd), " " , TimeToStr(brokerQTTerminate));
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

bool TradesOpen()
{ 
   return (false);
}

bool ManageOpenTrade()
{
   return (false);
}

int FindServerOffset()
{
   Print("Entering FindServerOffset()");
   if (Testing) return (3600); // an arbitrary number - anything will do for testing
   if (serverFirstBar == 0)
   {
      serverFirstBar = iTime(Symbol(), PERIOD_M1, 0);
      return (-1);
   }
   
   datetime ServerNow = iTime(Symbol(), PERIOD_M1, 0);
   if (ServerNow > serverFirstBar)
   {
      datetime localNow = (TimeLocal()/ 60) * 60;
      Print ("Local= ", TimeToStr(localNow, TIME_SECONDS), ", Server= ", TimeToStr(ServerNow, TIME_SECONDS));
      int serverOffset = ServerNow - localNow;
      Print ("Server Offset= ", serverOffset);
      return (serverOffset);
   }
   return (-1);
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


