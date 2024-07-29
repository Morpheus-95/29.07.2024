
/* Importieren der Produktionsdaten */
PROC IMPORT DATAFILE="/home/u63897214/Pumpwerk/Beispieldaten/production.xlsx"
    DBMS=XLSX
    OUT=Work.Produktion
    REPLACE;
RUN;

/* Importieren der Fehlerprotokolle */
DATA Work.Fehlerprotokolle;
    INFILE '/home/u63897214/Pumpwerk/Beispieldaten/error_logs.csv' DSD FIRSTOBS=2 DELIMITER=',';
    INPUT Date :ddmmyy10. Error_Code :$10. Description :$50.;
    FORMAT Date ddmmyy10.;
RUN;

/* Importieren der Sensordaten */
LIBNAME sensor XML "/home/u63897214/Pumpwerk/Beispieldaten/sensor_data.xml";

DATA Work.SensorDaten;
    SET sensor.Record;
RUN;

LIBNAME sensor CLEAR;

/* Schritt 1: Erstellen einer neuen Spalte 'Week' */
DATA Work.SensorDaten;
    SET Work.SensorDaten;
    FORMAT Week $7.;
    Week = PUT(INTCK('WEEK', '01JAN2024'D, Date) + 1, Z2.);
RUN;


/* Schritt 2: Boxplot der Motorlastdaten vor der Bereinigung für jede Woche */
PROC SGPLOT DATA=Work.SensorDaten;
    VBOX Motor_load / CATEGORY=Week;
    TITLE "Boxplot der Motorlastdaten vor der Bereinigung (Wöchentlich)";
    XAXIS LABEL="Woche" LABELATTRS=(size=8);
    YAXIS LABEL="Motorlast (%)" MAX=200;
RUN;

/* Schritt 3: Bereinigung der Daten */
DATA Work.SensorDaten_Bereinigt;
    SET Work.SensorDaten;
    /* Ausschließen von Werten außerhalb der Grenzwerte */
    IF 0 <= Temperature <= 150 AND 0 <= Motor_load <= 100;
RUN;

/* Schritt 4: Aggregation der bereinigten Sensordaten auf wöchentlicher Basis */
PROC SQL;
    CREATE TABLE Work.SensorDaten_Bereinigt_Täglich AS
    SELECT Date, 
           MEAN(Temperature) AS Avg_Temperature,
           MEAN(Motor_load) AS Avg_Motor_load
    FROM Work.SensorDaten_Bereinigt
    GROUP BY Date;
QUIT;

/* Schritt 5: Erstellen einer neuen Spalte 'Week' für die bereinigten Daten */
DATA Work.SensorDaten_Bereinigt;
    SET Work.SensorDaten_Bereinigt_Täglich;
    FORMAT Week $7.;
    Week = PUT(INTCK('WEEK', '01JAN2024'D, Date) + 1, Z2.);
RUN;

RUN;

/* Schritt 5: Boxplot der Motorlastdaten nach der Bereinigung für jede Woche */
PROC SGPLOT DATA=Work.SensorDaten_Bereinigt;
    VBOX Avg_Motor_load / CATEGORY=Week;
    TITLE "Boxplot der Motorlastdaten nach der Bereinigung (Wöchentlich)";
    XAXIS LABEL="Woche" LABELATTRS=(size=8);
    YAXIS LABEL="Motorlast (%)" MAX=200;
RUN;

/* Schritt 6: Auswahl der relevanten Daten für Pumpe C */
DATA Work.PumpeC;
    SET Work.Produktion;
    KEEP Date produced_units_Model_C;
RUN;

/* Schritt 6: Zusammenführen der Produktionsdaten und Sensordaten  (bereinigt)*/
PROC SQL;
    CREATE TABLE Work.PumpeC_Sensoren AS
    SELECT a.Date, a.produced_units_Model_C, b.Avg_Temperature, b.Avg_Motor_load
    FROM Work.PumpeC a
    LEFT JOIN Work.SensorDaten_Bereinigt b
    ON a.Date = b.Date;
QUIT;

TITLE "Korrelationsanalyse der Produktionsdaten, Temperatur und Motorlast nach Bereinigung";

/* Schritt 6: Korrelationsanalyse*/
PROC CORR DATA=Work.PumpeC_Sensoren;
    VAR produced_units_Model_C Avg_Temperature Avg_Motor_load;
RUN;
