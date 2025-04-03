//+------------------------------------------------------------------+
//|                                           Dunnigan Indicator.mq5 |
//|                                Copyright 2019, Leonardo Sposina. |
//|           https://www.mql5.com/en/users/leonardo_splinter/seller |
//+------------------------------------------------------------------+

#include "Dunnigan.mqh"
#include "DunniganSignal.mqh"

#define ICON_ARROW_UP 225
#define ICON_ARROW_DOWN 226
#define ICON_SHIFT 6

enum ENUM_COUNT_DAYS {
  today           = 0,
  past_one_day    = 1,
  past_two_days   = 2,
  past_three_days = 3,
  past_four_days  = 4,
  past_five_days  = 5,
  past_six_days   = 6,
};

input ENUM_COUNT_DAYS Starting_Calculation_Period = past_one_day;

Dunnigan* dunniganBuy;
Dunnigan* dunniganSell;

double volumeProfile[100]; // Array to store volume profile data
int firstCandleShiftIndex;
datetime calculatedTimestamp;
int currentCandleIndex = 0;

int OnInit() {
  dunniganBuy = new Dunnigan(0, "Dunnigan - Buy signal", ICON_ARROW_UP, ICON_SHIFT);
  dunniganSell = new Dunnigan(1, "Dunnigan - Sell signal", ICON_ARROW_DOWN, -ICON_SHIFT);

  calculatedTimestamp = createPastTimestampWithoutHour(Starting_Calculation_Period);

  ArrayInitialize(volumeProfile, 0);

  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
  Comment("");
  delete dunniganBuy;
  delete dunniganSell;
  ChartRedraw();
}

int OnCalculate(
  const int rates_total,
  const int prev_calculated,
  const datetime &time[],
  const double &open[],
  const double &high[],
  const double &low[],
  const double &close[],
  const long &tick_volume[],
  const long &volume[],
  const int &spread[]
) {
  firstCandleShiftIndex = iBarShift(_Symbol, _Period, calculatedTimestamp);

  if (firstCandleShiftIndex <= 0) 
    return(rates_total);

  if (isNewCandle(rates_total)) {
    dunniganBuy->resetBuffer();
    dunniganSell->resetBuffer();
    ArrayInitialize(volumeProfile, 0);
  }

  for (int i = rates_total - firstCandleShiftIndex; i < rates_total; i++) {
    ENUM_DUNNIGAN_SIGNAL signal = DunniganSignal::check(i, low, high, open, close);
    
    if (signal == DUNNIGAN_SIGNAL_BUY && isTickVolumeHigher(i, tick_volume)) {
      dunniganBuy->setValue(i, high[i - 1]);
      dunniganBuy->showComment();
    } else if (signal == DUNNIGAN_SIGNAL_SELL && isTickVolumeHigher(i, tick_volume)) {
      dunniganSell->setValue(i, low[i - 1]);
      dunniganSell->showComment();
    }
    
    // Volume Profile Calculation
    int index = int((close[i] - low[firstCandleShiftIndex]) / (high[firstCandleShiftIndex] - low[firstCandleShiftIndex]) * 99);
    if (index >= 0 && index < 100) {
      volumeProfile[index] += volume[i];
    }
  }
  
  DrawVolumeProfile(low[firstCandleShiftIndex], high[firstCandleShiftIndex]);
  
  return(rates_total);
}

void DrawVolumeProfile(double lowPrice, double highPrice) {
  for (int i = 0; i < 100; i++) {
    string objName = "VolumeProfile_" + IntegerToString(i);
    if (volumeProfile[i] > 0) {
      if (!ObjectFind(0, objName)) {
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, lowPrice + (highPrice - lowPrice) * i / 99);
      }
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE1, lowPrice + (highPrice - lowPrice) * i / 99);
    }
  }
}

bool isNewCandle(int ratesTotal) {
  if (currentCandleIndex != ratesTotal) {
    currentCandleIndex = ratesTotal;
    return true;
  }
  return false;
}

datetime createPastTimestampWithoutHour(int pastDays) {
  MqlDateTime timestamp;
  TimeToStruct(TimeCurrent(), timestamp);
  timestamp.day -= pastDays;
  timestamp.hour = 0;
  timestamp.min = 0;
  timestamp.sec = 0;
  return StructToTime(timestamp);
}

bool isTickVolumeHigher(int index, const long &volume[]) {
  return (index > 0 && volume[index] > volume[index - 1]);
}
