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
/* 2023-05-22   Tyrion      1.6             change errmsg col to fit tmp table columns  */
/****************************************************************************************/
--EXEC [BI].[LIT_support_ikea_interface_tool_Mode7] '0017653344
--0017653345
--0017655792
--',''--FOR TEST
CREATE   PROCEDURE [BI].[LIT_support_ikea_interface_tool_Mode7]
--         @MODE            INT ,--remove mode Tyrion
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
--IF @MODE = 7 --CSMΘçìµÄ¿ --remove mode Tyrion
   BEGIN
      CREATE TABLE #RESULTALL7(CKEY NVARCHAR(10),CMESSAGE NVARCHAR(MAX))

      DECLARE  @CDELIVERYPLACE   NVARCHAR(30),
      @CTRANSMITLOGKEY NVARCHAR(10)

      IF ISNULL(@ORDERSWORD,'')=''
         BEGIN
--Tyrion1.6  
            SELECT N'Φ»╖Φ╛ôσàÑσìòσÅ╖',''
            GOTO QUIT_SP
         END
      ELSE IF LEN(@ORDERSWORD)%10<>0
         BEGIN
--Tyrion1.6  
            SELECT N'Φ»╖µúÇµƒÑσìòσÅ╖µò░ΘçÅσÆîΣ╜ìµò░µÿ»σÉªµ¡úτí«,µÿ»σÉªσîàσÉ½Σ║åσñÜΣ╜ÖτÜäτ⌐║µá╝',''
            GOTO QUIT_SP
         END
      ELSE
         BEGIN--µê¬σÅûσìòσÅ╖
            WHILE LEN(@ORDERSWORD)>=10 AND ISNULL(@ORDERSWORD,'')<>''
               BEGIN
                  INSERT INTO #ORDERLIST 
                  VALUES (SUBSTRING(@ORDERSWORD,0,11))
                  SET @ORDERSWORD=SUBSTRING(@ORDERSWORD,11,LEN(@ORDERSWORD)-10)
               END
         END
      --ΦºªσÅæµúÇµƒÑ         
      DECLARE CUR CURSOR FAST_FORWARD READ_ONLY FOR SELECT DISTINCT C_ORDERKEY FROM #ORDERLIST(NOLOCK)
      OPEN CUR
      FETCH NEXT FROM CUR INTO @CUR_ORDERKEY
      WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT  @CTRANSMITLOGKEY=A.TRANSMITLOGKEY,@TIME=A.EDITDATE,@TRANSMITFLAG=A.TRANSMITFLAG,@CDELIVERYPLACE=B.DELIVERYPLACE,@ORDERCHECK=ORDERKEY FROM BI.V_TRANSMITLOG2 A WITH (NOLOCK) 
            JOIN BI.V_ORDERS B(NOLOCK)ON A.KEY1=B.ORDERKEY         
            WHERE A.TABLENAME='WSSOADDLOG2'AND B.ORDERKEY =@CUR_ORDERKEY
            IF ISNULL(@ORDERCHECK,'')=''OR @@ROWCOUNT=0
               BEGIN
                  INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                  VALUES (@CUR_ORDERKEY,N'Φ«óσìòσìòΣ╕ìσ¡ÿσ£¿µêûσ»╣σ║öCSMΦºªσÅæσÖ¿Σ╕ìσ¡ÿσ£¿∩╝îΦ»╖τí«Φ«ñ')
               END
            ELSE IF ISNULL(@CDELIVERYPLACE,'')<>'' 
               BEGIN
                  INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                  VALUES (@CUR_ORDERKEY,N'µ¡ñσìòσ╖▓µ£ëCSM')
               END
            ELSE IF  DATEDIFF(S,@TIME,GETDATE())<600  
               BEGIN
                  INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                  VALUES (@CUR_ORDERKEY,N'ΘçìµÄ¿Θù┤ΘÜöµ£¬σê░σìüσêåΘÆƒ')
               END
            ELSE IF @TRANSMITFLAG <>'9'
               BEGIN 
                  INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                  VALUES (@CUR_ORDERKEY,N'ΦºªσÅæσÖ¿τè╢µÇüσ╝éσ╕╕')
               END
            ELSE IF EXISTS(SELECT COUNT(ID) FROM BI.V_TCPSOCKET_QUEUETASK_LOG(NOLOCK)WHERE TRANSMITLOGKEY=@CTRANSMITLOGKEY HAVING COUNT(ID)>=20)
               BEGIN
                  INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                  VALUES (@CUR_ORDERKEY,N'ΘçìµÄ¿µ¼íµò░σñºΣ║Ä20')
               END
            ELSE
               BEGIN
                  UPDATE BI.V_TRANSMITLOG2 SET TRANSMITFLAG='0'WHERE TRANSMITLOGKEY=@CTRANSMITLOGKEY
                  IF @@ERROR='0'
                     BEGIN
                        INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                        VALUES (@CUR_ORDERKEY,N'ΘçìµÄ¿µêÉσèƒ∩╝ü')
                     END
                  ELSE
                     BEGIN
                        INSERT INTO #RESULTALL7(CKEY,CMESSAGE)
                        VALUES (@CUR_ORDERKEY,N'ΘçìµÄ¿σñ▒Φ┤Ñ∩╝üΦ»╖ΘçìΦ»ò')
                     END
               END
            
            FETCH NEXT FROM CUR INTO @CUR_ORDERKEY
         END
      CLOSE CUR
      DEALLOCATE CUR
      SELECT * FROM #RESULTALL7(NOLOCK)ORDER BY CMESSAGE
      DROP TABLE #RESULTALL7
   END
QUIT_SP: 
DROP TABLE #ORDERLIST
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