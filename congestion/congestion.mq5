#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Moving Averages Configuration
input int      MA1_Period = 9;         // First Moving Average Period
input int      MA2_Period = 21;        // Second Moving Average Period
input ENUM_MA_METHOD MA_Method = MODE_SMA; // Moving Average Method

//--- Congestion Detection Parameters
input double   Proximity_Threshold = 0.5;  // Proximity Threshold (%) - when MAs are close
input int      Slope_Window = 10;      // Window for calculating slope (bars)
input double   Slope_Threshold = 1.0;  // Slope Threshold (%) - combined slope magnitude
input int      SR_LookbackWindow = 50; // Lookback window to find S/R peaks

//--- global variables
int ma1_handle, ma2_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- create handles for moving averages
   ma1_handle = iMA(_Symbol, _Period, MA1_Period, 0, MA_Method, PRICE_CLOSE);
   if(ma1_handle == INVALID_HANDLE) return(INIT_FAILED);

   ma2_handle = iMA(_Symbol, _Period, MA2_Period, 0, MA_Method, PRICE_CLOSE);
   if(ma2_handle == INVALID_HANDLE) return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate slope of MA over window
//+------------------------------------------------------------------+
double CalculateSlope(double &ma_buffer[], int index, int window)
  {
   if(index < window) return 0;
   double slope = ma_buffer[index] - ma_buffer[index - window];
   return slope / ma_buffer[index - window] * 100; // percentage change
  }

//+------------------------------------------------------------------+
//| Helper: Check if MAs are within threshold proximity
//+------------------------------------------------------------------+
bool AreMAsClose(double ma1, double ma2, double threshold)
  {
   double avg = (ma1 + ma2) / 2.0;
   double diff_pct = MathAbs(ma1 - ma2) / avg * 100;
   return (diff_pct <= threshold);
  }

//+------------------------------------------------------------------+
//| Helper: Check if combined slope magnitude is low
//+------------------------------------------------------------------+
bool IsSlopeNeutral(double slope1, double slope2, double threshold)
  {
   double combined_slope = MathAbs(slope1) + MathAbs(slope2);
   return (combined_slope <= threshold);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate average high/low in lookback window
//+------------------------------------------------------------------+
void FindAverageLevels(const double &high[], const double &low[], int index, int window, 
                       double &resistance, double &support)
  {
   int start = MathMax(0, index - window);
   int count = index - start + 1;
   
   double sum_high = 0, sum_low = 0;
   for(int i = start; i <= index; i++)
     {
      sum_high += high[i];
      sum_low += low[i];
     }
   
   resistance = sum_high / count;
   support = sum_low / count;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int min_period = MathMax(MA2_Period, Slope_Window + 1);
   if(rates_total < min_period) return(0);

   static int last_drawn_idx = -1;
   static datetime last_drawn_end_time = 0;

   //--- Copy MA buffers
   double ma1[], ma2[];
   if(CopyBuffer(ma1_handle, 0, 0, rates_total, ma1) <= 0) return(0);
   if(CopyBuffer(ma2_handle, 0, 0, rates_total, ma2) <= 0) return(0);

   //--- Segment tracking
   bool in_segment = false;
   int seg_start = 0;
   datetime seg_start_time = 0;
   datetime seg_end_time = 0;
   double seg_support = DBL_MAX, seg_resistance = -DBL_MAX;
   int segment_count = 0;
   int start_idx = prev_calculated > 0 ? prev_calculated - 1 : min_period;

   for(int i = start_idx; i < rates_total; i++)
     {
      //--- Calculate conditions
      bool proximity_ok = AreMAsClose(ma1[i], ma2[i], Proximity_Threshold);
      
      double slope1 = CalculateSlope(ma1, i, Slope_Window);
      double slope2 = CalculateSlope(ma2, i, Slope_Window);
      bool slopes_ok = IsSlopeNeutral(slope1, slope2, Slope_Threshold);

      //--- Determine congestion: both conditions required
      bool congested = proximity_ok && slopes_ok;

      //--- Check day boundary
      bool day_changed = false;
      if(i > 0)
        {
         MqlDateTime dt_curr, dt_prev;
         TimeToStruct(time[i], dt_curr);
         TimeToStruct(time[i-1], dt_prev);
         day_changed = (dt_curr.day != dt_prev.day) || (dt_curr.mon != dt_prev.mon) || (dt_curr.year != dt_prev.year);
        }

      //--- Segment logic
      if((congested && !day_changed) || (day_changed && in_segment && !congested))
        {
         if(!in_segment)
           {
            in_segment = true;
            seg_start = i;
            seg_start_time = time[i];
            double temp_res, temp_sup;
            FindAverageLevels(high, low, i, SR_LookbackWindow, temp_res, temp_sup);
            seg_resistance = temp_res;
            seg_support = temp_sup;
           }
         else
           {
            double temp_res, temp_sup;
            FindAverageLevels(high, low, i, SR_LookbackWindow, temp_res, temp_sup);
            seg_support = (seg_support + temp_sup) / 2.0;  // Running average
            seg_resistance = (seg_resistance + temp_res) / 2.0;
           }
         seg_end_time = time[i];
        }
      else
        {
         if(in_segment)
           {
            if(seg_end_time != last_drawn_end_time)
              {
               string base = "CongestionZone_" + IntegerToString(segment_count);
               string s_name = base + "_SUP";
               string r_name = base + "_RES";

               ObjectDelete(0, s_name + "_PROG");
               ObjectDelete(0, r_name + "_PROG");

               if(ObjectCreate(0, s_name, OBJ_TREND, 0, seg_start_time, seg_support, seg_end_time, seg_support))
                 {
                  ObjectSetInteger(0, s_name, OBJPROP_COLOR, clrLime);
                  ObjectSetInteger(0, s_name, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, s_name, OBJPROP_STYLE, STYLE_SOLID);
                 }

               if(ObjectCreate(0, r_name, OBJ_TREND, 0, seg_start_time, seg_resistance, seg_end_time, seg_resistance))
                 {
                  ObjectSetInteger(0, r_name, OBJPROP_COLOR, clrRed);
                  ObjectSetInteger(0, r_name, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, r_name, OBJPROP_STYLE, STYLE_SOLID);
                 }

               last_drawn_end_time = seg_end_time;
               segment_count++;
              }

            in_segment = false;
           }
        }

      //--- Handle day boundary close
      if(day_changed && in_segment)
        {
         string base = "CongestionZone_" + IntegerToString(segment_count);
         string s_name = base + "_SUP";
         string r_name = base + "_RES";

         if(ObjectCreate(0, s_name, OBJ_TREND, 0, seg_start_time, seg_support, seg_end_time, seg_support))
           {
            ObjectSetInteger(0, s_name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, s_name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, s_name, OBJPROP_STYLE, STYLE_SOLID);
           }

         if(ObjectCreate(0, r_name, OBJ_TREND, 0, seg_start_time, seg_resistance, seg_end_time, seg_resistance))
           {
            ObjectSetInteger(0, r_name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, r_name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, r_name, OBJPROP_STYLE, STYLE_SOLID);
           }

         last_drawn_end_time = seg_end_time;
         segment_count++;
         in_segment = false;
         seg_support = DBL_MAX;
         seg_resistance = -DBL_MAX;
        }
     }

   //--- In-progress segment (current congestion)
   if(in_segment)
     {
      string base_prog = "CongestionZone_PROGRESS";
      string s_name_prog = base_prog + "_SUP_PROG";
      string r_name_prog = base_prog + "_RES_PROG";

      ObjectDelete(0, s_name_prog);
      ObjectDelete(0, r_name_prog);

      if(ObjectCreate(0, s_name_prog, OBJ_TREND, 0, seg_start_time, seg_support, seg_end_time, seg_support))
        {
         ObjectSetInteger(0, s_name_prog, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, s_name_prog, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, s_name_prog, OBJPROP_STYLE, STYLE_DOT);
        }

      if(ObjectCreate(0, r_name_prog, OBJ_TREND, 0, seg_start_time, seg_resistance, seg_end_time, seg_resistance))
        {
         ObjectSetInteger(0, r_name_prog, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, r_name_prog, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, r_name_prog, OBJPROP_STYLE, STYLE_DOT);
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- release handles
   if(ma1_handle != INVALID_HANDLE) IndicatorRelease(ma1_handle);
   if(ma2_handle != INVALID_HANDLE) IndicatorRelease(ma2_handle);

//--- remove all congestion zone objects
   int total_objects = ObjectsTotal(0);
   for(int i = total_objects - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, "CongestionZone_", 0) == 0 || StringFind(name, "PROGRESS", 0) >= 0)
         ObjectDelete(0, name);
     }
  }