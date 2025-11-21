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
/****************************************************************************************/
--EXEC [BI].[LIT_support_ikea_interface_tool_Mode5] '0009789233','' --FOR TEST tyrion
CREATE   PROCEDURE [BI].[LIT_support_ikea_interface_tool_Mode5]
     --    @MODE            INT ,--remove mode Tyrion
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
--','')--ÏƒÃ„â•—Î˜Ã–Ã±ÏƒÂ¢â‚§Î¦â•œÂªâˆ©â•Ã®Ïƒâ–‘Ã¥ÏƒÃ¬Ã²ÏƒÃ…â•–ÏƒÃ‰ÃªÏƒâ•£â•¢ÂµÃªÃ‰Î£â••Ã‡Î¦Ã­Ã®Î¦â”Â¢Î¦Ã­Ã®ÂµÃªÂ¬ÏƒÃ…Ã»
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
--IF @MODE = 5 --SHIPÏƒÂ»â•£ÂµÃ„Ã‘ÂµÆ’Ã‘Î¦Â»Ã³ --remove mode Tyrion
   BEGIN
      CREATE TABLE #SHIPINTERFACE(ERR NVARCHAR(55)NULL,TXT NVARCHAR(MAX)NULL,CDATE DATETIME NULL,OI NVARCHAR(1)NULL,BATCHNO NVARCHAR(25)NULL)
      DECLARE @ORDERSSHIP NVARCHAR(12)='',
            @BATCHNUM   NVARCHAR(25)=''

      SELECT @C_KEYCHECK=STATUS FROM BI.V_ORDERS(NOLOCK)WHERE ORDERKEY=@ORDERSWORD AND SOSTATUS='9'
      SELECT @TRANSMITFLAG=TRANSMITFLAG FROM BI.V_TRANSMITLOG2(NOLOCK)WHERE KEY1=@ORDERSWORD AND TABLENAME='WSSOCFMLOG2'
      SELECT @ORDERSSHIP='%'+@ORDERSWORD+'%'

      IF ISNULL(@ORDERSWORD,'')=''
         BEGIN
            INSERT INTO #SHIPINTERFACE(ERR) 
            VALUES(N'Î¦Â»â•–Î¦â•›Ã´ÏƒÃ Ã‘ORDERKEY')
         END
      ELSE IF ISNULL(@C_KEYCHECK,'')<>'9'OR ISNULL(@C_KEYCHECK,'')=''
         BEGIN
            INSERT INTO #SHIPINTERFACE(ERR) 
            VALUES(N'Î¦Â»â•–ÂµÃºÃ‡ÂµÆ’Ã‘KEYÂµÃ¿Â»ÏƒÃ‰ÂªÂµÂ¡ÃºÏ„Ã­Â«âˆ©â•Ã®ORDERÂµÂ£Â¬ÏƒÃ â”‚ÏƒÃ¬Ã²ÂµÃªÃ»ÂµÆ’Ã‘Î¦Â»Ã³Î£â••Ã¬ÏƒÃªâ–‘')
         END
      ELSE IF ISNULL(@TRANSMITFLAG,'')=''OR ISNULL(@TRANSMITFLAG,'')<>'9'
         BEGIN
            INSERT INTO #SHIPINTERFACE(ERR) 
            VALUES(N'Î¦ÂºÂªÏƒÃ…Ã¦Ïƒâ•Ã©Ïƒâ••â••âˆ©â•Ã®Î¦Â»â•–ÂµÃ…Ã‰TICKET')
         END
      ELSE 
         BEGIN
            SELECT DISTINCT BATCHNO INTO #TEMPTABLE5 FROM 
            (SELECT DISTINCT BATCHNO  FROM CNDTSITF..WSOUTBOUND (NOLOCK)
            WHERE DATASTREAM='6227'AND WSDATA LIKE @ORDERSSHIP
            UNION
            SELECT DISTINCT BATCHNO FROM CNDTSITF..WSOUTBOUND_LOG (NOLOCK)
            WHERE DATASTREAM='6227'AND WSDATA LIKE @ORDERSSHIP)AS A
            SELECT TOP 1 @BATCHNUM= BATCHNO FROM #TEMPTABLE5(NOLOCK)
            IF ISNULL(@BATCHNUM,'')<>''
               BEGIN
                  DECLARE @KEY NVARCHAR(25)
                  DECLARE CUR CURSOR FAST_FORWARD READ_ONLY FOR SELECT BATCHNO FROM #TEMPTABLE5
                  OPEN CUR
                  FETCH NEXT FROM CUR INTO @KEY
                  WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        INSERT INTO #SHIPINTERFACE
                        SELECT ERRMSG,WSDATA,ADDDATE,DIRECTION,BATCHNO FROM CNDTSITF..WSOUTBOUND(NOLOCK)WHERE DATASTREAM='6227'AND BATCHNO=@KEY
                        UNION
                        SELECT ERRMSG,WSDATA,ADDDATE,DIRECTION,BATCHNO FROM CNDTSITF..WSOUTBOUND_LOG(NOLOCK)WHERE DATASTREAM='6227'AND BATCHNO=@KEY

                        FETCH NEXT FROM CUR INTO @KEY
                     END
                  CLOSE CUR
                  DEALLOCATE CUR
                  DROP TABLE #TEMPTABLE5
               END
            ELSE 
               BEGIN
                  INSERT INTO #SHIPINTERFACE(ERR) 
                  VALUES(N'ÂµÃ²â–‘ÂµÃ¬Â«Ïƒâ•Ã©Ïƒâ••â••2âˆ©â•Ã®Î¦Â»â•–ÂµÃ…Ã‰TICKET')
               END
         END
      UPDATE #SHIPINTERFACE SET ERR=N'MESSAGE DELIVEREDÏƒÂ»â•£ÂµÃ„Ã‘ÂµÃªÃ‰ÏƒÃ¨Æ’âˆ©â•Ã®Î¦Â»â•–ÂµÃºÃ‡ÂµÆ’Ã‘ÏƒÂ»â•£ÂµÃ„Ã‘Î¦Â«Ã³ÏƒÃ¬Ã²ÂµÃ¿Â»ÏƒÃ‰ÂªÏƒÂ«Ã®ÂµÃ²â”¤'WHERE OI='I'AND TXT LIKE '%MESSAGE DELIVERED%'
      UPDATE #SHIPINTERFACE SET ERR=N'ÏƒÂ»â•£ÂµÃ„Ã‘Ïƒâ•Ã©Ïƒâ••â••âˆ©â•Ã®Î¦Â»â•–ÂµÃ…Ã‰TICKET'WHERE OI='I'AND TXT NOT LIKE '%MESSAGE DELIVERED%'
      UPDATE #SHIPINTERFACE SET ERR=N'Î¦Â«Ã³ÏƒÃ¬Ã²ÏƒÂ£Â¿ÂµÂ¡Ã±ÏƒÃªÃ¹ÂµÃ¨Ã‘ÂµÃ»Ã§Î£â••Â¡âˆ©â•Ã®Î¦Â»â•–ÏƒÂ»â•£Ïƒâ•‘Ã¶BATCHNOÏƒÂ»â•ÏƒÃ§â•‘ÂµÆ’Ã‘Ï„Â£Ã¯ÏƒÂ»â•£ÂµÃ„Ã‘Î¦Â«Ã³ÏƒÃ¬Ã²ÏƒÂ«Ã®ÂµÃ²â”¤ÂµÃ‡Âº'WHERE OI='O'
      SELECT * FROM #SHIPINTERFACE(NOLOCK)ORDER BY BATCHNO,OI
      DROP TABLE #SHIPINTERFACE
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