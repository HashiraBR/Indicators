#property copyright "Copyright 2026"
#property link      "https://www.autotradex.com.br"
#property version   "1.00"
#property description "VWAP - Volume Weighted Average Price"
#property description "Autor: AutoTradex | https://www.autotradex.com.br | @AutoTradex"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2

input int InpPeriod = 0; // Período VWAP (0 = abertura do dia)

double vwapBuffer[];

//+------------------------------------------------------------------+
//| Função para encontrar o índice da barra de início do período    |
//+------------------------------------------------------------------+
int GetBarStartIndex(int currentBar, int period, const datetime &time[])
{
   if (period == 0)
   {
      // Reset diário - encontra a abertura do dia
      for (int j = currentBar; j >= 1; j--)
      {
         long day1 = time[j] / 86400;
         long day2 = time[j-1] / 86400;
         if (day1 != day2)
         {
            return j;
         }
      }
      return 0; // Fallback
   }
   else
   {
      // Últimas N barras
      int start = currentBar - period + 1;
      return (start < 0) ? 0 : start;
   }
}

//+------------------------------------------------------------------+
//| Função para calcular VWAP a partir de um índice inicial         |
//+------------------------------------------------------------------+
double CalculateVWAP(int startBar, int endBar, const double &high[], const double &low[], const double &close[], const long &volume[])
{
   double priceVolumeSum = 0.0;
   double volumeSum = 0.0;
   
   for (int j = startBar; j <= endBar; j++)
   {
      double typicalPrice = (high[j] + low[j] + close[j]) / 3.0;
      double vol = (double)volume[j];
      
      priceVolumeSum += typicalPrice * vol;
      volumeSum += vol;
   }
   
   return (volumeSum > 0.0) ? (priceVolumeSum / volumeSum) : 0.0;
}

int OnInit()
{
   SetIndexBuffer(0, vwapBuffer, INDICATOR_DATA);
   PlotIndexSetString(0, PLOT_LABEL, "VWAP");
   return INIT_SUCCEEDED;
}

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
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   
   for (int i = start; i < rates_total; i++)
   {
      int barStart = GetBarStartIndex(i, InpPeriod, time);
      vwapBuffer[i] = CalculateVWAP(barStart, i, high, low, close, volume);
   }
   
   return rates_total;
}
