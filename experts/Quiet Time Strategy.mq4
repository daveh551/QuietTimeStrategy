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
int serverOffsetFromLocal = 0;
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
      serverOffsetFromLocal = 0;
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   if (TradesOpen() > 0 && CheckOpenTrade()) return(0);
      
   if (!TimeWindowToTrade(TimeCurrent())) return (0);
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
   
   Print("Completed tests. ", testsPassed, " of ", totalTests, " passed.");
   
 
}



bool TimeWindowToTrade(datetime time)
{
   return (false);
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
   Print (TimeToStr(localStart), " ", TimeToStr(localEnd), " " , TimeToStr(localTerm));
   Print ("ServerOffsetFromLocal =", serverOffsetFromLocal);
   if (serverOffsetFromLocal == 0) 
      serverOffsetFromLocal = FindServerOffset();
   brokerQTStart = localStart + serverOffsetFromLocal;
   brokerQTEnd = localEnd + serverOffsetFromLocal;
   brokerQTTerminate = localTerm + serverOffsetFromLocal;
}

bool CanCalculateBrokerStartTime()
{
   CalculateBrokerTimes();
   return (Assert(TimeToStr(brokerQTStart, TIME_MINUTES) == "15:00", "Wrong start time"));   
}

bool TradesOpen()
{ 
   return (false);
}

bool CheckOpenTrade()
{
   return (false);
}

int FindServerOffset()
{
   Print("Entering FindServerOffset()");
   if (WaitForNewBar())
   {
      datetime localNow = TimeLocal();
      datetime ServerNow = iTime(Symbol(), PERIOD_M1, 0);
   

      Print ("Local= ", TimeToStr(localNow), ", Server= ", TimeToStr(ServerNow));
      return (ServerNow - localNow);
   }
   else
   {
      Alert("No new bar received in 60 seconds. Impossible to determine Server Offset");
      return (-1);
   }
}

bool WaitForNewBar()
{
   // Wait for upto 60 seconds for a new 1 minute bar, then return.
   datetime startTime = TimeLocal();
   datetime startBar = iTime(Symbol(), PERIOD_M1, 0);
   
   while(true)
   {
      if (iTime(Symbol(), PERIOD_M1, 0) > startBar) return (true);
      if (TimeLocal() > startTime + 60) return (false);
   }
   
   
}