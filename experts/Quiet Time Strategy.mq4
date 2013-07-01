//+------------------------------------------------------------------+
//|                                          Quiet Time Strategy.mq4 |
//|                                                       Dave Hanna |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Dave Hanna"
#property link      "http://nohypeforexrobotreview.com"
#include <Assert.mqh>
#include <PcntTradeSize.mqh>
//--- input parameters
extern string  QuietTimeStart="15:00";
extern string  QuietTimeEnd="19:00";
extern string  QuietTimeTerminate="02:00";
extern bool    TradeSunday=false;
extern bool    TradeFriday=false;
extern int       TriggerPipsFromQTEntry=15;
extern double  PercentRisk=1.0;
extern int       StopLossPips=12;
extern int       TargetPips=10;
extern int       MaximumSpread=6;
extern int       MagicNumber=123456;
extern string    TradeComment="";
extern bool      Testing=false;

//Global variables
double QuietTimeEntryPrice = 0.00;   // The bid price at the start of quiet time.
double HighTrigger;
double LowTrigger;
datetime brokerQTStart;       // The Quiet Time startTime in broker timezone
datetime brokerQTEnd;
datetime brokerQTTerminate;
int serverOffsetFromLocal = -1;
datetime serverFirstBar = 0;
int openTicketNumbers[30];
int Digit5 = 1;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   if (Testing)
      RunTests();
   CalculateBrokerTimes();
   if (Digits == 5 || Digits == 3) 
      Digit5 = 10;
   else Digit5 = 1;
   ClearTicketNumbers();
     
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
      QuietTimeEntryPrice = 0.00;
      ClearTicketNumbers();
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
      if (ManageOpenTrade(iTime(NULL, PERIOD_M1, 0))) return(0);
      
   if (!TimeWindowToTrade(iTime(NULL, PERIOD_M1, 0))) return (0);
   if (QuietTimeEntryPrice == 0.00)
   {
      QuietTimeEntryPrice = GetQuietTimeEntryPrice();
      HighTrigger = QuietTimeEntryPrice + TriggerPipsFromQTEntry * Digit5 * Point;
      LowTrigger = QuietTimeEntryPrice + TriggerPipsFromQTEntry * Digit5 * Point;
      if (ObjectFind("TRADEWINDOW") == -1)
      {
         MakeTradeWindow(brokerQTStart,brokerQTEnd, LowTrigger, HighTrigger);
      }
   }
   int typeTrade = ShouldTrade(Bid, Ask);
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
   int barIndex = 0;
   while(true)
   {
      if (iTime(NULL, PERIOD_M1,  barIndex) <= brokerQTStart)
      {
         return (iOpen(NULL, PERIOD_M1,barIndex));
      }
      barIndex++;
   }
}

int ShouldTrade(double bid, double ask)
{

   int result = 0;
   if (Ask < LowTrigger) result = 1; // execute a Buy trade
   if (Bid > HighTrigger) result = -1; // execute a Sell Trade
   if ((ask -bid) > (MaximumSpread * Point)) 
   {
      Print("Would have executed a trade, but spread is too wide: ", ask-bid, ", Max spread=", MaximumSpread, ", Point=", DoubleToStr(Point, Digits));
      result = 0;
   }
   return (result);

}

void PlaceTrade(int tradeType, string symbol)
{

   double TP,SL,TradeSize;
   int Ticket;
   bool ModifyResult;

   TradeSize = PcntTradeSize(Symbol(), StopLossPips, PercentRisk, 1, false, true);

      while(IsTradeContextBusy())  //our loop for the busy trade context
         Sleep(100);  //sleep for 100 ms and test the trade context again
      RefreshRates();  //refreshing all the variables when the 
                      //trade context is no longer busy
   int orderOp = OP_BUY;
   string printType = "BUY";
   double orderPrice = Ask;
   double exitPrice = Bid;
   color orderArrow = Blue;
   if(tradeType == -1)  //Short Trade
      {
         orderOp = OP_SELL;
         printType = "SELL";
         orderPrice = Bid;
         exitPrice = Ask;
         orderArrow = Red;
       }
       
      TP = exitPrice + tradeType * (TargetPips / Point);
      SL = exitPrice  - tradeType * (StopLossPips / Point);

      Print("Entering ", printType, " order for ", DoubleToStr(TradeSize, 2), " lots of ",  Symbol(), " at ", DoubleToStr(orderPrice, Digits)); 
      Ticket = OrderSend(Symbol(),orderOp,NormalizeDouble(TradeSize,2),
                        NormalizeDouble(orderPrice,Digits),2.0,0.0,0.0,"Trade Comment",
                        MagicNumber,orderArrow);
      if(Ticket >= 0)
         {
         while(IsTradeContextBusy())
            Sleep(100);
         RefreshRates();
         OrderSelect(Ticket,SELECT_BY_TICKET);
         ModifyResult = OrderModify(Ticket,OrderOpenPrice(),
                                    NormalizeDouble(SL,Digits),
                                    NormalizeDouble(TP,Digits),0,orderArrow);
         Print("Modifying order for SL=", DoubleToStr(SL,Digits), ", TP=", DoubleToStr(TP, Digits));                                    
         if(!ModifyResult)
            Alert("Stop Loss and Take Profit not set on order ",Ticket);
         }  //if(Ticket >= 0)
      else
         {
         Alert("Trade Not Entered");
         }  //else

   } 


void CalculateBrokerTimes()
{
   Print("Entering CalculateBrokerTimes(). serverOffsetFromLocal = ", serverOffsetFromLocal);
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

int TradesOpen()
{ 
   int totalOrdersCount = OrdersTotal();
   int ordersForThisSymbol = 0;
   
   if (totalOrdersCount == 0) return (0);
   Print("Entering TradesOpen(). totalOrderCount = ", totalOrdersCount);
   for (int ix = 0; ix < totalOrdersCount; ix++)
   {
      Print("In Open Trades. Examining openOrder[", ix, "] Symbol=", Symbol(), ", OrderSymbol()=", OrderSymbol(), ", OrderTicket=", OrderTicket());
      if (OrderSelect(ix, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol())
         {
            Print("Order is for active symbol ", Symbol(), ". ordersForThisSymol = ", ordersForThisSymbol);
            openTicketNumbers[ordersForThisSymbol] = OrderTicket();
            ordersForThisSymbol++;
         }
      }
   }
   Print ("Returning ordersForThisSymbol = ", ordersForThisSymbol);
   return (ordersForThisSymbol);
}

bool ManageOpenTrade(datetime serverTime)
{
   // For now, we're assuming Stop Loss and TP are set on the trade.
   // All we have to worry about is closing the trade at QTTerminate
   if (serverTime >= brokerQTTerminate)
   {
      CloseOpenOrders();
      return (false);
   }
   return (true); // orders remain open, so don't attempt to enter a new one. 
}

void CloseOpenOrders()
{
   for (int ix= 0; openTicketNumbers[ix] > 0; ix++)
   {
      OrderSelect(openTicketNumbers[ix], SELECT_BY_TICKET);
      double lotSize = OrderLots();
      int orderType = OrderType();
      double price = Bid;
      if (orderType == OP_SELL)
         price = Ask;
      OrderClose(openTicketNumbers[ix], lotSize, price, 3, Red);
   }
}
int FindServerOffset()
{
   Print("Entering FindServerOffset()");
   if (Testing) return (3600); // an arbitrary number - anything will do for testing
   if (serverFirstBar == 0)
   {

      serverFirstBar = iTime(Symbol(), PERIOD_M1, 0);
      Print ("Set serverFirstBar to ", TimeToStr(serverFirstBar));
      return (-1);
   }
   
   datetime ServerNow = iTime(Symbol(), PERIOD_M1, 0);
   Print("Comparing ServerNow to serverFirstBar. ServerNow =", TimeToStr(ServerNow));
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

void MakeTradeWindow(datetime start, datetime end, double lowPrice, double highPrice)
{
   if (ObjectFind("TRADEWINDOW") == -1)
      ObjectCreate("TRADEWINDOW", OBJ_RECTANGLE, 0, start, lowPrice, end, highPrice);
   else
   {
      ObjectSet("TRADEWINDOW", OBJPROP_TIME1, start);
      ObjectSet("TRADEWINDOW", OBJPROP_TIME2, end);
      ObjectSet("TRADEWINDOW", OBJPROP_PRICE1,  lowPrice);
      ObjectSet("TRADEWINDOW", OBJPROP_PRICE2,  highPrice);
   }
   ObjectSet("TRADEWINDOW", OBJPROP_COLOR, Blue);
   ObjectSet("TRADEWINDOW", OBJPROP_BACK, true);
}

void ClearTicketNumbers()
{
   for (int ix=0; ix <= ArrayRange(openTicketNumbers, 0); ix++)
      openTicketNumbers[ix] = 0;
}