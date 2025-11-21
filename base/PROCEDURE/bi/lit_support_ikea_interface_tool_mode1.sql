SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************************/
/* STORED PROC:                                                                         */
/* CREATION DATE: 2020-09-16                                                            */
/*                                                                                      */
/* PURPOSE:  IKEA_INTERFACE_TOOL                                                        */
/* AUTHER:IVAN YI                                                                       */
/* DATA MODIFICATIONS:                                                                  */
/*                                                                                      */
/* UPDATES:                                                                             */
/* DATE         AUTHOR      VER PURPOSES    DESCR                                       */
/* 2021-09-14   IVANYI      1.1             ADD OPEN PALLET FUNCTION                    */
/* 2021-09-29   IVANYI      1.2             ADD SF INTERFACE RETRIGGER                  */
/* 2022-07-04   IVANYI      1.3             SHIPINTERFACE CHANGED                       */
/* 2022-07-06   IVANYI      1.4             ADD CSM RETRIGGER AND CODE OPTIMIZATION     */
/* 2023-04-10   Tyrion      1.5             Split Procedure by @Mode                    */
/* 2023-05-22   Tyrion      1.6             change select * to detail column as   Jreport */
/*                                          doesn't support result with diff columns      */   
/****************************************************************************************/
--EXEC [BI].[LIT_support_ikea_interface_tool_Mode1] '0017655792
--0017653345
--0017653344
--0017651323',''--FOR TEST Tyrion
CREATE   PROCEDURE [BI].[LIT_support_ikea_interface_tool_Mode1] 
   -- Add the parameters for the stored procedure here
      --   @MODE            INT, --remove mode Tyrion
         @ORDERSWORD      NVARCHAR(MAX)='',
         @CMBOLKEY         NVARCHAR(10)=''
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @Debug   BIT = 1
       , @LogId     INT
       , @LinkSrv   NVARCHAR(128)
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "ORDERSWORD":"'    +@ORDERSWORD+'", '
                                    + '"CMBOLKEY":"'      +@CMBOLKEY+'"  '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = ''
      , @Proc = @Proc
      , @ParamIn = @cParamIn
      , @LogId = @LogId OUTPUT
      , @Debug = @Debug OUTPUT
      , @Schema = @Schema;

   DECLARE @Stmt    NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

SET @ORDERSWORD=REPLACE(REPLACE(REPLACE(@ORDERSWORD,CHAR(13),''),' ',''),CHAR(10),'')
--   SET @ORDERSWORD=REPLACE(@ORDERSWORD,'
--','')--σÄ╗ΘÖñσ¢₧Φ╜ª∩╝îσ░åσìòσÅ╖σÉêσ╣╢µêÉΣ╕ÇΦíîΦ┐¢Φíîµê¬σÅû


DECLARE   
      @ORDERINFO3         NVARCHAR(30)='',
      @TRANSMITFLAG      NVARCHAR(5)='',
      @TIME            DATETIME,
      @CUR_ORDERKEY      NVARCHAR(10)='',
      @ORDERCHECK         NVARCHAR(10)='',
      @TCPLOGCHECK      NVARCHAR(1)='',
      @C_EXTERNMBOLKEY   NVARCHAR(20)='',
      @C_KEYCHECK         NVARCHAR(20)='',
      @C_SHIPPERKEY      NVARCHAR(20)=''

SELECT @C_EXTERNMBOLKEY=EXTERNMBOLKEY FROM BI.V_MBOL(NOLOCK)WHERE MBOLKEY=@CMBOLKEY
CREATE TABLE #ORDERLIST(C_ORDERKEY NVARCHAR(10))

--IF @MODE = 1 --µ╗æΘüôσÅ╖µƒÑΦ»óµ¿íσ╝Å --remove mode Tyrion
   BEGIN
--    Tyrion 1.6
      IF ISNULL(@ORDERSWORD,'')=''
         BEGIN
            SELECT N'Φ»╖Φ╛ôσàÑσìòσÅ╖','','','','','','','','',''
         END
      ELSE IF LEN(@ORDERSWORD)%10<>0
         BEGIN
            SELECT N'Φ»╖µúÇµƒÑσìòσÅ╖µò░ΘçÅσÆîΣ╜ìµò░µÿ»σÉªµ¡úτí«','','','','','','','','',''
         END
      ELSE
         BEGIN
            WHILE LEN(@ORDERSWORD)>=10 AND ISNULL(@ORDERSWORD,'')<>''
               BEGIN
                  INSERT INTO #ORDERLIST 
                  VALUES (SUBSTRING(@ORDERSWORD,0,11))
                  SET @ORDERSWORD=SUBSTRING(@ORDERSWORD,11,LEN(@ORDERSWORD)-10)
               END
--   SELECT * FROM BI.V_ORDERINFO(NOLOCK)WHERE ORDERKEY IN (SELECT DISTINCT C_ORDERKEY FROM #ORDERLIST(NOLOCK))
--    Tyrion 1.6
         SELECT [OrderKey]
              ,[OrderInfo01]
              ,[OrderInfo02]
              ,[OrderInfo03]
              ,[OrderInfo04]
              ,[OrderInfo05]
              ,[OrderInfo06]
              ,[OrderInfo07]
              ,[OrderInfo08]
              ,[OrderInfo09]
              ,[OrderInfo10]
           FROM [BI].[V_OrderInfo] WHERE ORDERKEY IN (SELECT DISTINCT C_ORDERKEY FROM #ORDERLIST(NOLOCK))
       END
   END
-------------------------------------------------------------------------------------
IF DATENAME(WEEKDAY,GETDATE())='MONDAY'--CALCULATION OF USAGE TIMES IVANYI 2022-07-18
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(UDF01,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF01=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(UDF01,LEN(UDF01)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF01=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END
ELSE IF DATENAME(WEEKDAY,GETDATE())='TUESDAY'
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(UDF02,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF02=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(UDF02,LEN(UDF02)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF02=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END
ELSE IF DATENAME(WEEKDAY,GETDATE())='WEDNESDAY'
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(UDF03,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF03=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(UDF03,LEN(UDF03)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF03=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END
ELSE IF DATENAME(WEEKDAY,GETDATE())='THURSDAY'
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(UDF04,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF04=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(UDF04,LEN(UDF04)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF04=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END
ELSE IF DATENAME(WEEKDAY,GETDATE())='FRIDAY'
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(UDF05,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF05=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(UDF05,LEN(UDF05)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET UDF05=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END
ELSE IF DATENAME(WEEKDAY,GETDATE())='SATURDAY'
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(LONG,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET LONG=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(LONG,LEN(LONG)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET LONG=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END
ELSE IF DATENAME(WEEKDAY,GETDATE())='SUNDAY'
   BEGIN
      IF EXISTS(SELECT 1 FROM BI.V_CODELKUP(NOLOCK)WHERE LEFT(NOTES,10)=CONVERT(NVARCHAR(10),GETDATE(),120)AND LISTNAME='HBLCOUNT'AND CODE='1')
         BEGIN
            UPDATE BI.V_CODELKUP SET NOTES=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+CONVERT(NVARCHAR(100),(RIGHT(NOTES,LEN(NOTES)-11)+1)),CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END
      ELSE
         BEGIN
            UPDATE BI.V_CODELKUP SET NOTES=CONVERT(NVARCHAR(10),GETDATE(),120)+'_'+'1',CODE2=CODE2+1 WHERE LISTNAME='HBLCOUNT'AND CODE='1'
         END      
   END

   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO