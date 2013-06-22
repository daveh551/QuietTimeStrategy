//+------------------------------------------------------------------+
//|                                          Quiet Time Strategy.mq4 |
//|                                                       Dave Hanna |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Dave Hanna"
#property link      "http://nohypeforexrobotreview.com"

//--- input parameters
extern datetime  QuietTimeStart=D'01/01/1970 15:00';
extern datetime  QuietTimeEnd=D'01/01/1970 19:00';
extern int       TriggerPipsFromQTEntry=15;
extern datetime  QuietTimeTerminate=D'01/01/1970 02:00';
extern int       StopLossPips=12;
extern int       TargetPops=10;
extern int       MaximumSpread=6;
extern bool      Testing=false;

//Global variables
double QuietTimeEntryPrice;   // The bid price at the start of quiet time.
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   if (Testing)
      RunTests();
     
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
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