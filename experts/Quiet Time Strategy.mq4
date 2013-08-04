//+------------------------------------------------------------------+
//|                                          Quiet Time Strategy.mq4 |
//|                                                       Dave Hanna |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Dave Hanna"
#property link      "http://nohypeforexrobotreview.com"
#include <Assert.mqh>
#include <stdlib.mqh>
#include <stderror.mqh> 
#include <PcntTradeSize.mqh>
string Title = "Quiet Time Stategy";
string Prefix="QTS_";
string Version = "v0.1.4";

//--- input parameters
extern string  TimesInfo="These times should be set (in 24 Hour time) for your local timezone";
extern string  TimesInfo2="They should correspond to 3:00PM and 7:00PM New York Time";
extern string  QuietTimeStart="15:00";
extern string  QuietTimeEnd="19:00";
extern string  TimesInfo3="This should correspond to 2:00AM New York Time";
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
extern bool      StealthMode = false;
extern bool      Testing=false;
extern bool      UseATRFilter=true;
extern int       ATRPeriod=1;
extern int       ATRAveraging=5;
extern double    ATRRatioToSLLimit=0.5;
extern int       SlowMAPeriod = 10;
extern int       FastMAPeriod = 3;

//Global variables
int FiveDig;
int LotDigits;
bool MarginAlert=false;
double AdjPoint;
static datetime LastTradeTime=0;
color TextColor=Goldenrod;
string TextFont="Verdana";
int debug = true;
bool HeartBeat = true;
int DEBUG_STARTUP = 1;
int DEBUG_ORDERARRAY=2;
int DEBUG_GLOBALVARIABLES = 4;
int DEBUG_ORDERCLOSING = 8;
double QuietTimeEntryPrice = 0.00;   // The bid price at the start of quiet time.
double HighTrigger;
double LowTrigger;
datetime brokerQTStart;       // The Quiet Time startTime in broker timezone
datetime brokerQTEnd;
datetime brokerQTTerminate;
int serverOffsetFromLocal = -1;
datetime serverFirstBar = 0;

int openTicketNumbers[30];
datetime openTime[30];
double openPrice[30];
double tradeSL[30];
double tradeTP[30];
double lots[30];
double openATR[30];
double openFastMA[30];
double openFastMAShift5[30];
double openSlowMA[30];
double openSlowMAShift5[30];
double openQTEntryPrice[30];
datetime closeTime[30];
double closePrice[30];
int orderType[30];
double orderProfit[30];
int nextOpenTicketNumber = 0;
string trackingFileName;
int trackingFileHandle;
//Per bar values
datetime time0;
double atrInPips;
double barHigh;
double barLow;
#include "RunTests.mq4"
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
   //----
   Print("---------------------------------------------------------");
   Print("-----",Title," ",Version," Initializing ",Symbol(),"-----"); 
   if(Digits==5||Digits==3)
      FiveDig = 10;
   else
      FiveDig = 1;
   AdjPoint = Point * FiveDig;
   DrawVersion(); 

   if(MarketInfo(Symbol(),MODE_LOTSTEP) < 0.1)
      LotDigits = 2;
   else if(MarketInfo(Symbol(),MODE_LOTSTEP) < 1.0)
      LotDigits = 1;
   else
      LotDigits = 0;

   CheckGlobals();
  //---------------------------------------------------- 
//----
   if (Testing)
      RunTests();
   CalculateBrokerTimes();
   ClearTicketNumbers();
   
   InitializeTrackingFile();  
   
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
      if (trackingFileHandle != 0) 
      {
         FileClose(trackingFileHandle);
         trackingFileHandle = 0;
      }
   //----
   DeleteAllObjects();

   //----
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {

   if (NewBar())
      CheckGlobals();
   if(HeartBeat)
      HeartBeat();
        
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
      HighTrigger = QuietTimeEntryPrice + TriggerPipsFromQTEntry * FiveDig * Point;
      LowTrigger = QuietTimeEntryPrice - TriggerPipsFromQTEntry * FiveDig * Point;
      Print("QuietTimeEntryPrice = ", DoubleToStr(QuietTimeEntryPrice, Digits), ", HighTrigger= ", DoubleToStr(HighTrigger, Digits), ", LowTrigger= ", DoubleToStr(LowTrigger, Digits));
          MakeTradeWindow(brokerQTStart,brokerQTEnd, LowTrigger, HighTrigger);
    }
    if (NewBar()) CalculateNewPerBarValues();
    //Print("At ", TimeToStr(TimeCurrent())," iATR(NULL, M1,5,1) = ", DoubleToStr(iATR(NULL,PERIOD_M1, 5, 1), Digits));
   int typeTrade = ShouldTrade(Bid, Ask);
   if (typeTrade == 0) return(0);
   if (!AllowTrade()) return (0);
   int ticketNumber = PlaceTrade(typeTrade, Symbol());
   if (ticketNumber >0)
   {
      OrderSelect(ticketNumber,SELECT_BY_TICKET);
      double price = OrderOpenPrice();
      Print("Modifying SL and TP for Order #", ticketNumber, ". OrderPrice = ", DoubleToStr(price, Digits));
      double spread = Ask-Bid ;
      double stopLossPrice, targetPrice;
      CalculateTargets(price, spread, typeTrade, StopLossPips, TargetPips, stopLossPrice, targetPrice );
      if (!StealthMode)
         if (SetTargets(ticketNumber, stopLossPrice, targetPrice))
         {
            RecordTrade(ticketNumber);
         }
      else
      {
         RecordTrade(ticketNumber, stopLossPrice, targetPrice);
      }
   }
//----
   return(0);
  }
//+------------------------------------------------------------------+




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
      QuietTimeEntryPrice = 0.00;
      if (trackingFileHandle > 0)
      {
         FileClose(trackingFileHandle);
         trackingFileHandle = 0;
      }
   }
   if (TimeDayOfWeek(time) == 0 && !TradeSunday) result = false;
   if (TimeDayOfWeek(time) == 5 && !TradeFriday) result = false;
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
   if (result != 0 && (ask -bid + Point/2) >= (MaximumSpread * FiveDig * Point)) 
   {
      Print("Would have executed a trade, but spread is too wide: ", ask-bid, ", Max spread=", MaximumSpread, ", Point=", DoubleToStr(Point, Digits));
      result = 0;
   }
   //if (result != 0)
   //   Print("ShouldTrade = ", result, ", Spread= ", DoubleToStr(ask-bid, Digits));
   return (result);

}

bool AllowTrade()
{
   if (UseATRFilter)
      if (!ATRFilter()) return (false);
   return (true);
}
int PlaceTrade(int tradeType, string symbol)
{

   double TradeSize;
   int Ticket;
   bool ModifyResult;

   double spreadInPoints = (Ask - Bid)/Point;
   double stopLossRisk = StopLossPips + spreadInPoints/FiveDig;
   Print("Calculating lot size. SpreadInPoints= ", DoubleToStr(spreadInPoints, Digits), 
      ", Points= ", DoubleToStr(Point, Digits), 
      ", StopLossPips= ", StopLossPips, 
      "Risk= ", DoubleToStr(stopLossRisk, Digits));
   
   TradeSize = PcntTradeSize(symbol, stopLossRisk , PercentRisk, 1, false, true);

      while(IsTradeContextBusy())  //our loop for the busy trade context
         Sleep(100);  //sleep for 100 ms and test the trade context again
      RefreshRates();  //refreshing all the variables when the 
                      //trade context is no longer busy
   int orderOp = OP_BUY;
   string printType = "BUY";
   double orderPrice = Ask;
   color orderArrow = Blue;
   if(tradeType == -1)  //Short Trade
      {
         orderOp = OP_SELL;
         printType = "SELL";
         orderPrice = Bid;
         orderArrow = Red;
       }
       

      Print("Entering ", printType, " order for ", DoubleToStr(TradeSize, 2), " lots of ",  Symbol(), " at ", DoubleToStr(orderPrice, Digits)); 
      Ticket = OrderSend(Symbol(),orderOp,NormalizeDouble(TradeSize,2),
                        NormalizeDouble(orderPrice,Digits),2.0,0.0,0.0,"Trade Comment",
                        MagicNumber,orderArrow);
      if(Ticket >= 0)
         {
            RecordOrder(Ticket);
            return (Ticket);
         }
      else
         {
         Alert("Trade Not Entered");
         return (-1);
         }  //else

}

void CalculateTargets(double price, double spread, int tradeType, int stopLossPips, int targetPips, double& stopLossPrice, double& targetPrice)
{
   stopLossPrice = price - tradeType * stopLossPips * FiveDig * Point - tradeType * spread;
   targetPrice = price + tradeType * targetPips * FiveDig * Point;   
} 

bool SetTargets(int ticketNumber, double stopLossPrice, double takeProfitPrice)
{
   bool ModifyResult;
         if (Testing)
         {
            ModifyResult = true;
         }
         else
         {
            while(IsTradeContextBusy())
               Sleep(100);
            RefreshRates();
            ModifyResult = OrderModify(ticketNumber,OrderOpenPrice(),
                                    NormalizeDouble(stopLossPrice,Digits),
                                    NormalizeDouble(takeProfitPrice,Digits),0);
         }
         Print("Modifying order for SL=", DoubleToStr(stopLossPrice,Digits), ", TP=", DoubleToStr(takeProfitPrice, Digits));                                    
         if(!ModifyResult)
         {
            int err = GetLastError();
            Alert("Stop Loss and Take Profit not set on order ",ticketNumber, " Error = ", err);
            Print ("Error ", err, " returned from OrderModify");
         }  //if(Ticket >= 0)
         return (ModifyResult);
}
void RecordTrade(int ticketNumber, double stopLoss = 0.0, double takeProfit = 0.0)
{
              if (OrderSelect(ticketNumber, SELECT_BY_TICKET))
            {
               if (stopLoss == 0.0) tradeSL[nextOpenTicketNumber -1] = OrderStopLoss();
               else tradeSL[nextOpenTicketNumber-1] = stopLoss;
               if (takeProfit == 0.0) tradeTP[nextOpenTicketNumber -1] = OrderTakeProfit();
               else tradeTP[nextOpenTicketNumber -1] = takeProfit;
               WriteCurrentOrder(nextOpenTicketNumber - 1);
            }
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



int TradesOpen()
{ 
   int totalOrdersCount = OrdersTotal();
   int ordersForThisSymbol = 0;
   
   if (totalOrdersCount == 0)
      if (nextOpenTicketNumber == 0) return (0);
      else
      {
         // An order must have closed
         for (int ix=0; ix < nextOpenTicketNumber; ix++)
         {
            if (OrderSelect(openTicketNumbers[ix], SELECT_BY_TICKET))
            {
               closeTime[ix] = OrderCloseTime();
               if (closeTime[ix] != 0)
               {
                  closePrice[ix] = OrderClosePrice();
                  WriteCurrentOrder(ix);
                  for (int jx = ix; jx < ArrayRange(openTicketNumbers, 0) - 1; jx++)
                  {
                     openTicketNumbers[jx] = openTicketNumbers[jx+1];
                     openTime[jx] = openTime[jx+1];
                     openPrice[jx] = openPrice[jx+1];
                     tradeSL[jx] = tradeSL[jx+1];
                     tradeTP[jx] = tradeTP[jx+1];
                     openATR[jx] = openATR[jx+1];
                     openFastMA[jx] = openFastMA[jx+1];
                     openFastMAShift5[jx] = openFastMAShift5[jx+1];
                     openSlowMA[jx] = openSlowMA[jx+1];
                     openSlowMAShift5[jx] = openSlowMAShift5[jx+1];
                     openQTEntryPrice[jx] = openQTEntryPrice[jx+1];
                     closeTime[jx] = closeTime[jx+1];
                     closePrice[jx] = closePrice[jx+1];
                  }
                     jx = ArrayRange(openTicketNumbers,0) - 1;
                     openTicketNumbers[jx] = 0;
                     openTime[jx] = 0;
                     openPrice[jx] = 0.0;
                     tradeSL[jx] = 0.0;
                     tradeTP[jx] = 0.0;
                     openATR[jx] = 0.0;
                     openFastMA[jx] = 0.0;
                     openFastMAShift5[jx] = 0.0;
                     openSlowMA[jx] = 0.0;
                     openSlowMAShift5[jx] = 0.0;
                     openQTEntryPrice[jx] = 0.0;
                     closeTime[jx] = 0;
                     closePrice[jx] = 0.0;
                  ix--;
               }
            }
         }
         nextOpenTicketNumber--;
      }
   //Print("Entering TradesOpen(). totalOrderCount = ", totalOrdersCount);
   for ( ix = 0; ix < totalOrdersCount; ix++)
   {
      //Print("In Open Trades. Examining openOrder[", ix, "] Symbol=", Symbol(), ", OrderSymbol()=", OrderSymbol(), ", OrderTicket=", OrderTicket());
      if (OrderSelect(ix, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol())
         {
            //Print("Order is for active symbol ", Symbol(), ". ordersForThisSymol = ", ordersForThisSymbol);
            //openTicketNumbers[ordersForThisSymbol] = OrderTicket();
            ordersForThisSymbol++;
         }
      }
   }
   //Print ("Returning ordersForThisSymbol = ", ordersForThisSymbol);
   return (ordersForThisSymbol);
}

bool ManageOpenTrade(datetime serverTime)
{
   
   if (serverTime >= brokerQTTerminate)
   {
      CloseOpenOrders();
      return (false);
   }
   for (int ix= 0; ix < nextOpenTicketNumber; ix++)
   {
      bool orderStopped = CloseOrderIfAtStopLoss(ix);
      if (IsMainOrder(ix))
      {
         bool orderProfit = CloseOrderIfAtTakeProfit(ix);
         
      }
   }
   return (true); // orders remain open, so don't attempt to enter a new one. 
}

bool CloseOrderIfAtStopLoss(int orderIndex)
{
/*
   if (ShouldClose(orderIndex, Bid, Ask, tradeSL[orderIndex]))
   {
      if (!CloseOrder(orderIndex, Red, "stop loss"))
      {
      	 HandleCloseError(orderIndex);
      }
      return (true);
   }
*/   
   return (false);
   
}
bool ShouldClose(int orderIndex, double bid, double ask, double triggerPrice)
{

   double priceToClose;
   int comparison;
   if (orderType[orderIndex] == OP_SELL) 
   {
      priceToClose = ask;
      if (openPrice[orderIndex] > triggerPrice) // then this is take profit
         comparison = -1;
      else
         comparison = 1;
   }
   else
   {
       priceToClose = bid;
       if (openPrice[orderIndex] < triggerPrice) // then this is take profit
          comparison = 1;
       else
       	  comparison = -1;
   }
   
	if (debug & DEBUG_ORDERCLOSING != 0)
 	Print("ShouldClose, orderType=", orderType[orderIndex], ", priceToClose = ",
		DoubleToStr(priceToClose, Digits),
		", triggerPrice = ", DoubleToStr(triggerPrice, Digits),
		", comparison= ", comparison,
		", entryPrice = ", DoubleToStr(openPrice[orderIndex], Digits));
   return ((priceToClose - triggerPrice)*comparison >= 0);
}
bool IsMainOrder(int orderIndex)
{
   return (true);
}

bool CloseOrderIfAtTakeProfit(int orderIndex)
{
   if (ShouldClose(orderIndex, Bid, Ask, tradeTP[orderIndex]))
   {
   	if (!CloseOrder(orderIndex, Blue, "take profit"))
	  {
	    HandleCloseError(orderIndex);
   	}
	  return(true);

   }
   return (false);
   
}

bool CloseOrder(int orderIndex, color ArrowColor, string action)
{
      double priceToClose = Bid;
      if (orderType[orderIndex] == OP_SELL) priceToClose = Ask;
      if (debug & DEBUG_ORDERCLOSING != 0)
      {
         Print ("Closing order ", openTicketNumbers[orderIndex], " by ", action, " at ", DoubleToStr(priceToClose, Digits), " TP price = ", DoubleToStr(tradeTP[orderIndex], Digits));
      }
      bool result = OrderClose(openTicketNumbers[orderIndex], lots[orderIndex], priceToClose, 3, ArrowColor);
      return (result);
}

void HandleCloseError(int orderIndex)
{
	int errorNumber = GetLastError();
	Alert("Order ", openTicketNumbers[orderIndex], " failed to close: Error ", 
		ErrorDescription(errorNumber));
	Print("ERROR: Order", openTicketNumbers[orderIndex], " failed to close. Error = ", errorNumber, " (",
		ErrorDescription(errorNumber), ")");
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
   //Print("Entering FindServerOffset()");
   if (Testing) return (3600); // an arbitrary number - anything will do for testing
   if (serverFirstBar == 0)
   {

      serverFirstBar = iTime(Symbol(), PERIOD_M1, 0);
      //Print ("Set serverFirstBar to ", TimeToStr(serverFirstBar));
      return (-1);
   }
   
   datetime ServerNow = iTime(Symbol(), PERIOD_M1, 0);
   //Print("Comparing ServerNow to serverFirstBar. ServerNow =", TimeToStr(ServerNow));
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
   nextOpenTicketNumber = 0;      
}

bool ATRFilter()
{

   if (atrInPips >  StopLossPips*ATRRatioToSLLimit)
   {
      Print("ATR over last ", 5, " Minutes is ", DoubleToStr(atrInPips, Digits), " which is greater than StopLossRatio ", DoubleToStr(StopLossPips*ATRRatioToSLLimit, Digits));
      return (false);
   }
   return(true);
}
void CalculateNewPerBarValues()
{
   double atr = iATR(Symbol(), PERIOD_M1, ATRAveraging, 1);
   double atrInPoints = atr/Point;
   atrInPips = atrInPoints/FiveDig;
   Print("atr= ", DoubleToStr(atr, Digits), ", atrInPoints= ", DoubleToStr(atrInPoints, Digits), ", atrInPips= ", DoubleToStr(atrInPips, Digits));
}

bool NewBar()
{
   datetime timeNow =  iTime(NULL, PERIOD_M1, 0);
   if (time0 == timeNow) return(false);
   time0 = timeNow;
   return (true);
}

void InitializeTrackingFile()
{
 datetime currentTime = TimeCurrent();
   trackingFileName = TimeYear(currentTime) + "-" +StringSubstr( (100 +TimeMonth(currentTime))+ "", 1) + "-" + StringSubstr((100 + TimeDay(currentTime))+ "", 1) + ".CSV";
   trackingFileHandle = FileOpen(trackingFileName,  FILE_READ | FILE_WRITE | FILE_CSV, ',');
   FileSeek(trackingFileHandle, 0, SEEK_END);
   if (FileTell(trackingFileHandle) == 0) // new file
   {
      //Write out a header
      FileWrite(trackingFileHandle,
          "TicketNumber"
          , "Type"
          , "Currency"
          , "Entry Time"
          , "Entry Time"
          , "Entry Price"
          , "Stop Loss"
          , "Take Profit"
          , "QT Entry Price"
          , "ATR"
          , "Slow MA"
          , "Slow MA Shift 5"
          , "Fast MA"
          , "Fast MA Shift 5"
          , "Closing Time"
          , "Closing Time"
          , "Closing Price"
          , "Profit"
          );
      FileFlush(trackingFileHandle);
   }

}

void RecordOrder(int ticketNumber)
{
   int ticketArrayIndex = nextOpenTicketNumber;
   openTicketNumbers[nextOpenTicketNumber] = ticketNumber;
   nextOpenTicketNumber++;
   if (debug & DEBUG_ORDERARRAY != 0)
   {
      Print("Recording open order[", ticketArrayIndex, "] for ticket ", ticketNumber);
   }
   if (OrderSelect(ticketNumber, SELECT_BY_TICKET))
   {
      openTime[ticketArrayIndex] = OrderOpenTime();
      openPrice[ticketArrayIndex] = OrderOpenPrice();
      lots[ticketArrayIndex] = OrderLots();
      tradeSL[ticketArrayIndex] = 0.0;
      tradeTP[ticketArrayIndex] = 0.0;
      openATR[ticketArrayIndex] = atrInPips;
      openFastMA[ticketArrayIndex] = iMA(NULL, PERIOD_M1, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      openFastMAShift5[ticketArrayIndex] = iMA(NULL, PERIOD_M1, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 6);
      openSlowMA[ticketArrayIndex] = iMA(NULL, PERIOD_M1, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      openSlowMAShift5[ticketArrayIndex] = iMA(NULL, PERIOD_M1, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 6);
      openQTEntryPrice[ticketArrayIndex] = QuietTimeEntryPrice;     
      closeTime[ticketArrayIndex] = 0;
      closePrice[ticketArrayIndex] = 0.0;
      orderType[ticketArrayIndex] = OrderType();
      orderProfit[ticketArrayIndex] = 0;
   }
}

void WriteCurrentOrder(int ticketIndex)
{
   int ticketArrayIndex = ticketIndex;
   if (trackingFileHandle == 0) InitializeTrackingFile();
   string orderT = "BUY";
   if (orderType[ticketArrayIndex] == OP_SELL) orderT = "SELL";
   double profit = 0.0;
   if (closePrice[ticketArrayIndex] != 0.0) profit = closePrice[ticketArrayIndex] - openPrice[ticketArrayIndex];
   if (orderType[ticketArrayIndex] == OP_SELL) profit = -profit;
      FileWrite(trackingFileHandle,
          openTicketNumbers[ticketArrayIndex]  //"TicketNumber"
          , orderT
          , Symbol()
          , openTime[ticketArrayIndex] // "Entry Time"
          , TimeToStr(openTime[ticketArrayIndex])
          , openPrice[ticketArrayIndex] //"Entry Price"
          , tradeSL[ticketArrayIndex]  //"Stop Loss"
          , tradeTP[ticketArrayIndex]  //"Take Profit"
          , openQTEntryPrice[ticketArrayIndex]  //"QT Entry Price"
          , openATR[ticketArrayIndex] // "ATR"
          , openSlowMA[ticketArrayIndex] //"Slow MA"
          , openSlowMAShift5[ticketArrayIndex] //"Slow MA Shift 5"
          , openFastMA[ticketArrayIndex] //"Fast MA"
          , openFastMAShift5[ticketArrayIndex] //"Fast MA Shift 5"
          , closeTime[ticketArrayIndex]
          , TimeToStr(closeTime[ticketArrayIndex])
          , closePrice[ticketArrayIndex]
          , profit
          );
      FileFlush(trackingFileHandle);
   
}
void DeleteAllObjects()
   {
   int objs = ObjectsTotal();
   string name;
   for(int cnt=ObjectsTotal()-1;cnt>=0;cnt--)
      {
      name=ObjectName(cnt);
      if (StringFind(name,Prefix,0)>-1) 
         ObjectDelete(name);
      WindowRedraw();
      }
   } //void DeleteAllObjects()

void DrawVersion()
   {
   string name;
   name = StringConcatenate(Prefix,"Version");
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,Version,8,TextFont,TextColor);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,5);
   ObjectSet(name,OBJPROP_YDISTANCE,2);
   } //void DrawVersion()
void SetGV(string VarName,double VarVal)
   {
   string strVarName = StringConcatenate(Prefix,Symbol(),"_",VarName);

   GlobalVariableSet(strVarName,VarVal);
   if(debug & DEBUG_GLOBALVARIABLES != 0)
      Print("###Set GV ",strVarName," Value=",VarVal);
   } //void SetGV

double GetGV(string VarName)
   {
   string strVarName = StringConcatenate(Prefix,Symbol(),"_",VarName);
   double VarVal = -99999999;

   if(GlobalVariableCheck(strVarName))
      {
      VarVal = GlobalVariableGet(strVarName);
      if(debug & DEBUG_GLOBALVARIABLES != 0)
         Print("###Get GV ",strVarName," Value=",VarVal);
      }

   return(VarVal); 
   } //double GetGV(string VarName)

void HeartBeat(int TimeFrame=PERIOD_H1)
   {
   static datetime LastHeartBeat;
   datetime CurrentTime;

   if(GlobalVariableCheck(StringConcatenate(Prefix,"HeartBeat")))
      {
      if(GlobalVariableGet(StringConcatenate(Prefix,"HeartBeat")) == 1)
         HeartBeat = true;
      else
         HeartBeat = false;
   }  //void HeartBeat(int TimeFrame=PERIOD_H1)

   if(HeartBeat)
      { 
      CurrentTime = iTime(NULL,TimeFrame,0);
      if(CurrentTime > LastHeartBeat)
         {
         Print(Version," HeartBeat ",TimeToStr(TimeCurrent(),TIME_DATE|TIME_MINUTES));
         LastHeartBeat = CurrentTime;
         } //if(CurrentTime > ...
      } //if(HeartBeat)

   } //HeartBeat()
void CheckGlobals()
{
   if(GlobalVariableCheck(StringConcatenate(Prefix,"debug")))
      {
      debug = GlobalVariableGet(StringConcatenate(Prefix,"debug"));
      }

   if(GlobalVariableCheck(StringConcatenate(Prefix,"HeartBeat")))
      {
      HeartBeat = GlobalVariableGet(StringConcatenate(Prefix,"HeartBeat"));
      }
}
