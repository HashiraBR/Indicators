#property indicator_chart_window
#property indicator_plots 0

#property copyright "Copyright 2026"
#property link      "https://www.autotradex.com.br"
#property version   "1.00"
#property description "Candle Timer - Mostra tempo restante da vela atual"
#property description "Autor: AutoTradex | https://www.autotradex.com.br | @AutoTradex"

// Definição das opções de posicionamento
enum ENUM_POSITION_MODE
{
    POSITION_NEAR_CANDLE = 0,    // Ao lado da última vela
    POSITION_RIGHT_UPPER = 1,    // Canto direito superior
    POSITION_RIGHT_LOWER = 2,    // Canto direito inferior
    POSITION_LEFT_UPPER = 3,     // Canto esquerdo superior
    POSITION_LEFT_LOWER = 4      // Canto esquerdo inferior
};

// Input parameters
input ENUM_POSITION_MODE position_mode = POSITION_NEAR_CANDLE; // Modo de posicionamento do timer
input bool countdown_mode = true; // true = decrescente, false = crescente
input int font_size = 14; // Tamanho da fonte para o timer
input string font_name = "Arial"; // Nome da fonte para o timer
input color text_color = clrBlue; // Cor do texto
input int offset_x = 75; // Distância horizontal (pixels)
input int offset_y = 10; // Distância vertical (pixels)

int OnInit()
{
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
    if(rates_total < 1) return 0;

    datetime current_bar_time = time[rates_total - 1];
    datetime next_bar_time = current_bar_time + PeriodSeconds();
    datetime current_time = TimeCurrent();
    
    int elapsed_seconds = (int)(current_time - current_bar_time);
    int remaining_seconds = (int)(next_bar_time - current_time);
    
    string timer_text;
    int display_value;
    
    if(countdown_mode)
    {
        display_value = remaining_seconds;
        timer_text = StringFormat("%02d:%02d", display_value / 60, display_value % 60);
    }
    else
    {
        display_value = elapsed_seconds;
        timer_text = StringFormat("%02d:%02d", display_value / 60, display_value % 60);
    }
    
    UpdateLabelPosition(timer_text, time, high, low, rates_total);
    
    return rates_total;
}

void UpdateLabelPosition(string timer_text, const datetime &time[], const double &high[], const double &low[], int rates_total)
{
    string label_name = "candle_timer_label";
    ObjectDelete(0, label_name);
    
    // Largura do texto em pixels (aproximadamente 8-10 pixels por caractere + fonte)
    int text_width = StringLen(timer_text) * (font_size - 4) + font_size;
    int text_height = font_size + 8;
    
    int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    
    int x_pos = offset_x;
    int y_pos = offset_y;
    
    // Se seguir a última vela, posicionar ao lado dela
    if(position_mode == POSITION_NEAR_CANDLE && rates_total > 0)
    {
        // Obter posição da última vela (candle em formação)
        datetime last_candle_time = time[rates_total - 1];
        double last_candle_high = high[rates_total - 1];
        double last_candle_low = low[rates_total - 1];
        
        // Converter coordenadas de tempo/preço para coordenadas de pixel
        int candle_x, candle_y_high, candle_y_low;
        if(ChartTimePriceToXY(0, 0, last_candle_time, last_candle_high, candle_x, candle_y_high) &&
           ChartTimePriceToXY(0, 0, last_candle_time, last_candle_low, candle_x, candle_y_low))
        {
            // Posicionar à direita da vela (offset_x pixels à direita)
            x_pos = candle_x + offset_x;
            
            // Posicionar no meio da vela (entre high e low)
            y_pos = (candle_y_high + candle_y_low) / 2 - text_height / 2 + offset_y;
            
            // Garantir que não saia da tela à direita
            if(x_pos + text_width > chart_width - 10)
            {
                x_pos = chart_width - text_width - 10;
            }
            
            // Garantir que não saia da tela acima/abaixo
            if(y_pos < 10) y_pos = 10;
            if(y_pos + text_height > chart_height - 10) y_pos = chart_height - text_height - 10;
            
            // Usar coordenadas absolutas (canto superior esquerdo como referência)
            ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0);
            ObjectSetString(0, label_name, OBJPROP_TEXT, timer_text);
            ObjectSetString(0, label_name, OBJPROP_FONT, font_name);
            ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, font_size);
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, text_color);
            ObjectSetInteger(0, label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, x_pos);
            ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, y_pos);
            return;
        }
    }
    
    // Fallback: usar posicionamento por canto se não conseguir posicionar ao lado da vela
    ENUM_BASE_CORNER use_corner = CORNER_RIGHT_UPPER;
    
    // Para canto à direita, ajustar se sair do gráfico
    if(use_corner == CORNER_RIGHT_UPPER || use_corner == CORNER_RIGHT_LOWER)
    {
        if(offset_x + text_width > chart_width - 20)
        {
            x_pos = chart_width - text_width - 20;
            if(x_pos < 5) x_pos = 5;
        }
        else
        {
            x_pos = offset_x;
        }
    }
    
    // Para canto inferior, ajustar se sair do gráfico
    if(use_corner == CORNER_RIGHT_LOWER || use_corner == CORNER_LEFT_LOWER)
    {
        if(offset_y + text_height > chart_height - 20)
        {
            y_pos = chart_height - text_height - 20;
            if(y_pos < 5) y_pos = 5;
        }
        else
        {
            y_pos = offset_y;
        }
    }
    
    ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, label_name, OBJPROP_TEXT, timer_text);
    ObjectSetString(0, label_name, OBJPROP_FONT, font_name);
    ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, font_size);
    ObjectSetInteger(0, label_name, OBJPROP_COLOR, text_color);
    ObjectSetInteger(0, label_name, OBJPROP_CORNER, use_corner);
    ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, x_pos);
    ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, y_pos);
}

void OnDeinit(const int reason)
{
    ObjectDelete(0, "candle_timer_label");
}
