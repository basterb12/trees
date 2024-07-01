import binascii
from datetime import datetime
import pandas as pd


class SensorFileParser:
    def __init__(self):
        self.date_format = '%Y-%m-%d%H:%M:%S'
        self.cols_meteo = ['time', 'temperature', 'humidity', 'pressure', 'temperature2']
        self.cols_env = ['time', 'pm_1', 'pm_25', 'pm_10', 'pm_4']
        #self.cols_voc = ['time', 'voc'] #edit

    def parse_file(self, filepath, date) -> (pd.DataFrame, pd.DataFrame, pd.DataFrame):
        f = open(filepath)
        lines = f.readlines()
        if not lines:
            return

        line_iter = iter(lines)  # here
        list_meteo = []
        list_env = []
       # list_voc = [] #edit
        for ln in line_iter:
            ln = ln.strip()
            line_data = ln.split(",")
            #must use a try/exception because sometimes there are other data in the text file.
            #If the first entry is not a timestamp- the line is not read
            try:
                timestamp = datetime.strptime(date + line_data[0], self.date_format)
            except:
                continue

            if len(line_data) == 4 and line_data[3].startswith("Updated Value of Characteristic"):
                char_line = line_data[3].split(" ")
                if len(char_line) > 6:
                  #  if len(char_line) == 8: #voc values edit
                   #     voc = self.byteInt1(char_line[6][0:4])/1000 #edit
                    #    list_voc.append([voc]) #edit
                    if len(char_line) == 10:  #short data line (humidity,temp,pressure,temp precision)
                        temp = self.byteInt1(char_line[6][0:2])
                        hum = self.byteInt1(char_line[6][2:4])
                        pressure = self.byteInt1(char_line[7] + char_line[8])/100
                        temp_prec = self.byteInt1(char_line[9][0:4])/100
                        list_meteo.append([timestamp, hum, temp, pressure, temp_prec])
                    if len(char_line) == 12: #long data line (pm values)
                        pm1 = self.byteInt1(char_line[6] + char_line[7][0:2])/100
                        pm25 = self.byteInt1(char_line[7][2:4] + char_line[8])/100
                        pm10 = self.byteInt1(char_line[9] + char_line[10][0:2])/100
                        pm4 = self.byteInt1(char_line[10][2:4] + char_line[11][0:4])/100
                        list_env.append([timestamp, pm1, pm25, pm10, pm4])

        df_meteo = pd.DataFrame(list_meteo, columns=self.cols_meteo)
        df_env = pd.DataFrame(list_env, columns=self.cols_env)
      #  df_voc = pd.DataFrame(list_voc, columns=self.cols_voc) #edit
        

        return df_meteo, df_env#, df_voc #edit

    
  #this is method used - considers little-endian encoding
    @staticmethod
    def byteInt1(x):
        return int.from_bytes(bytes.fromhex(x), byteorder="little")
    
#alternative methods below - tested but didn't seem to match
    @staticmethod
    def byteToInt(x: str) -> int:
        return int.from_bytes(binascii.unhexlify(x), byteorder='little')

    #This is the standard encoding for temerature data in 16 bit (Q7) but somehow result is different -> not used
    @staticmethod
    def decode16BitQ7(x):
        return (x - 0x10000 if (x & 0x8000) else x) * 0.0078125

    #variant for 12 bit but also not the right one
    @staticmethod
    def decode12BitQ4(selfself, x):
        return ((x - 0x10000 if (x & 0x8000) else x) >> 4) * 0.0625