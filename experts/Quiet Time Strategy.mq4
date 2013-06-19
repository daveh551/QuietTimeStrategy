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
extern int       StopLossPIps=12;
extern int       TargetPops=10;
extern bool      Testing=false;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
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
   
//----
   return(0);
  }
//+------------------------------------------------------------------+

void RunTests()
{
}