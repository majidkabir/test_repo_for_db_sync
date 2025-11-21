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
--EXEC [BI].[LIT_support_ikea_interface_tool_Mode3] '','0000766471' --FOR TEST Tyrion
CREATE   PROCEDURE [BI].[LIT_support_ikea_interface_tool_Mode3]
   --      @MODE            INT ,--remove mode Tyrion
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
--IF @MODE = 3 --ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–ÂµÆ’Ã‘Î¦Â»Ã³ÂµÂ¿Ã­Ïƒâ•Ã… --remove mode Tyrion
   BEGIN
      CREATE TABLE #MBOL3 ( WORD NVARCHAR(40), COUNTNUMBER NVARCHAR(30)NULL)
      DECLARE @STATUSCHECK      NVARCHAR(2)='',
            @SHOULD            NVARCHAR(20)='',
            @HAVE            NVARCHAR(20)='',
            @MAXCHECK3         NVARCHAR(5)=''
      SELECT @C_KEYCHECK=ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY
      SELECT @C_SHIPPERKEY=SHIPPERKEY,@MAXCHECK3=M_FAX2 FROM BI.V_ORDERS(NOLOCK)WHERE ORDERKEY=@C_KEYCHECK
      SELECT @STATUSCHECK=STATUS FROM BI.V_MBOL(NOLOCK)WHERE MBOLKEY=@CMBOLKEY

      IF ISNULL(@CMBOLKEY,'')=''
         BEGIN
         INSERT INTO #MBOL3(WORD) VALUES(N'Î¦Â»â•–Î¦â•›Ã´ÏƒÃ Ã‘MBOLKEY')
         END
      ELSE IF ISNULL(@C_KEYCHECK,'')=''
         BEGIN
         INSERT INTO #MBOL3(WORD) VALUES(N'Î¦Â»â•–ÂµÃºÃ‡ÂµÆ’Ã‘KEYÂµÃ¿Â»ÏƒÃ‰ÂªÂµÂ¡ÃºÏ„Ã­Â«âˆ©â•Ã®ÂµÆ’Ã‘Î¦Â»Ã³Î£â••Ã¬ÏƒÃªâ–‘Î¦Â«Ã³ÏƒÃ¬Ã²')
         END
      ELSE IF ISNULL(@STATUSCHECK,'')=''OR ISNULL(@STATUSCHECK,'')='9'
         BEGIN
         INSERT INTO #MBOL3(WORD) VALUES(N'MBOLÏ„Ã¨â•¢ÂµÃ‡Ã¼Ïƒâ•Ã©Ïƒâ••â••âˆ©â•Ã®Î¦Â»â•–ÂµÃºÃ‡ÂµÆ’Ã‘')
         END
      ELSE IF ISNULL(@CMBOLKEY,'')<>''AND ISNULL(@C_KEYCHECK,'')<>''
         BEGIN
            IF ISNULL(@C_SHIPPERKEY,'')=''
               BEGIN--JDÏƒÃ¬Ã²ÏƒÂ¡Ã‰
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•–â–“Ï„Ã¶Æ’ÂµÃªÃ‰ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–Ï„Â«â–’ÂµÃ²â–‘',COUNT(ROWREF)  FROM BI.V_CARTONTRACK(NOLOCK)WHERE LABELNO IN (SELECT ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY)AND TRACKINGNO LIKE '%-%'
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•–â–“ÂµÃ«Â½ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–Ï„Â«â–’ÂµÃ²â–‘',COUNT(PALLETKEY)  FROM BI.V_PALLETDETAIL(NOLOCK)WHERE PALLETKEY=@C_EXTERNMBOLKEY
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•‘Ã¶ÂµÃ«Â½ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–Ï„Â«â–’ÂµÃ²â–‘',COUNT(PICKSLIPNO) FROM BI.V_PACKINFO(NOLOCK)WHERE PICKSLIPNO IN (
                  SELECT PICKSLIPNO FROM BI.V_PACKHEADER(NOLOCK)WHERE ORDERKEY IN (SELECT ORDERKEY FROM BI.V_MBOLDETAIL(NOLOCK)WHERE MBOLKEY=@CMBOLKEY))
                  SELECT @C_KEYCHECK=''
                  SELECT @C_KEYCHECK=ROWREF FROM BI.V_CARTONTRACK WITH (NOLOCK)  WHERE LABELNO IN (SELECT ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY)AND TRACKINGNO LIKE '%-%'
                  AND TRACKINGNO NOT IN(SELECT CASEID FROM BI.V_PALLETDETAIL WITH (NOLOCK) WHERE PALLETKEY =@C_EXTERNMBOLKEY)
                  SELECT @SHOULD=COUNT(PICKSLIPNO) FROM BI.V_PACKINFO(NOLOCK)WHERE PICKSLIPNO IN (
                  SELECT PICKSLIPNO FROM BI.V_PACKHEADER(NOLOCK)WHERE ORDERKEY IN (SELECT ORDERKEY FROM BI.V_MBOLDETAIL(NOLOCK)WHERE MBOLKEY=@CMBOLKEY))
                  SELECT @HAVE=COUNT(PALLETKEY)  FROM BI.V_PALLETDETAIL(NOLOCK)WHERE PALLETKEY=@C_EXTERNMBOLKEY
               END
            ELSE IF ISNULL(@C_SHIPPERKEY,'')='SN'--AND @MAXCHECK3<>'SF'
               BEGIN--SNÏƒÃ¬Ã²ÏƒÂ¡Ã‰
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•–â–“Ï„Ã¶Æ’ÂµÃªÃ‰ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–Ï„Â«â–’ÂµÃ²â–‘',COUNT(ROWREF)  FROM BI.V_CARTONTRACK(NOLOCK)WHERE LABELNO IN (SELECT ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY)
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•–â–“ÂµÃ«Â½ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–Ï„Â«â–’ÂµÃ²â–‘',COUNT(PALLETKEY)  FROM BI.V_PALLETDETAIL(NOLOCK)WHERE PALLETKEY=@C_EXTERNMBOLKEY
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•‘Ã¶ÂµÃ«Â½ÏƒÂ¡Ã‰ÏƒÃ¬Ã²ÏƒÃ…â•–Ï„Â«â–’ÂµÃ²â–‘',COUNT(PICKSLIPNO) FROM BI.V_PACKINFO(NOLOCK)WHERE PICKSLIPNO IN (
                  SELECT PICKSLIPNO FROM BI.V_PACKHEADER(NOLOCK)WHERE ORDERKEY IN (SELECT ORDERKEY FROM BI.V_MBOLDETAIL(NOLOCK)WHERE MBOLKEY=@CMBOLKEY))
                  SELECT @C_KEYCHECK=''
                  SELECT @C_KEYCHECK=ROWREF FROM BI.V_CARTONTRACK WITH (NOLOCK)  WHERE LABELNO IN (SELECT ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY)
                  AND TRACKINGNO NOT IN(SELECT CASEID FROM BI.V_PALLETDETAIL WITH (NOLOCK) WHERE PALLETKEY =@C_EXTERNMBOLKEY)
                  SELECT @SHOULD=COUNT(PICKSLIPNO) FROM BI.V_PACKINFO(NOLOCK)WHERE PICKSLIPNO IN (
                  SELECT PICKSLIPNO FROM BI.V_PACKHEADER(NOLOCK)WHERE ORDERKEY IN (SELECT ORDERKEY FROM BI.V_MBOLDETAIL(NOLOCK)WHERE MBOLKEY=@CMBOLKEY))
                  SELECT @HAVE=COUNT(PALLETKEY)  FROM BI.V_PALLETDETAIL(NOLOCK)WHERE PALLETKEY=@C_EXTERNMBOLKEY
               END
            ELSE
               BEGIN 
               INSERT INTO #MBOL3(WORD) VALUES( N'Î¦Â»â•–Ï„Ã­Â«Î¦Â«Ã±Î¦Â«Ã³ÏƒÃ¬Ã²SHIPPERKEYÂµÃ¿Â»ÏƒÃ‰ÂªÎ£â••â•‘SNÂµÃªÃ»Î£â••â•‘Ï„âŒâ•‘âˆ©â•ÃªÂµÃ»â–‘Ï„â–’â•—Ïƒâ‚§Ã¯Î¦Â»â•–ÂµÃ…Ã‰Î£â•‘Ã±TICKETÎ£â”Â«ÂµÃ¶â•£ÂµÂ£Â¼Ïƒâ•–Ã‘ÏƒÃ â•–âˆ©â•Ã«')
            --GOTO 
               END
            --Î£â•‘Ã®ÂµÂ«â•¡Î˜Â¬Ã®Î¦Â»Ã¼
            IF ISNULL(@C_KEYCHECK,'')=''
               BEGIN
                  INSERT INTO #MBOL3 VALUES( N'Ïƒâ•‘Ã¶ÏƒÃªÃ¡Î˜Ã–Ã±Ï„ÃœÃ¤Ïƒâ•‘Ã…ÏƒÃ…â•–:',N'ÂµÃ¹Ã¡Ïƒâ•‘Ã…ÏƒÃ…â•–ÏƒÃ…Â»ÏƒÃªÃ¡âˆ©â•Ã®Î¦Â»â•–Ï„Ã­Â«Î¦Â«Ã±KEYÂµÃªÃ»Ïƒâ–‘Â¥Î¦Â»Ã²ÏƒÃ â”‚ÂµÂ¥â”')
               END
            ELSE IF ISNULL(@C_SHIPPERKEY,'')=''AND @HAVE=@SHOULD
               BEGIN
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•‘Ã¶ÏƒÃªÃ¡Î˜Ã–Ã±Ï„ÃœÃ¤Ïƒâ•‘Ã…ÏƒÃ…â•–:',ISNULL(ROWREF,'') FROM BI.V_CARTONTRACK WITH (NOLOCK)  WHERE LABELNO IN (SELECT ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY)AND TRACKINGNO LIKE '%-%'
                  AND TRACKINGNO NOT IN(SELECT CASEID FROM BI.V_PALLETDETAIL WITH (NOLOCK) WHERE PALLETKEY =@C_EXTERNMBOLKEY)
               END
            ELSE IF ISNULL(@C_SHIPPERKEY,'')=''AND @HAVE<>@SHOULD
               BEGIN
                  INSERT INTO #MBOL3 VALUES( N'Ïƒâ•‘Ã¶ÏƒÃªÃ¡Î˜Ã–Ã±Ï„ÃœÃ¤Ïƒâ•‘Ã…ÏƒÃ…â•–:',N'Ï„Â«â–’ÂµÃ²â–‘Î£â••Ã¬Ï„Â¼Âªâˆ©â•Ã®Î¦Â»â•–ÂµÃºÃ‡ÂµÆ’Ã‘Ï„Â«â–’ÂµÃ²â–‘ÂµÃ¿Â»ÏƒÃ‰ÂªÏƒâ•–â–“ÂµÃ«Â½ÏƒÃ Â¿ÂµÃªÃ»PACKINFOÂµÃ²â–‘ÂµÃ¬Â«ÂµÃ¿Â»ÏƒÃ‰ÂªÏƒÂ«Ã®ÂµÃ²â”¤')
               END
            ELSE IF ISNULL(@C_SHIPPERKEY,'')='SN'AND @HAVE=@SHOULD
               BEGIN
                  INSERT INTO #MBOL3
                  SELECT N'Ïƒâ•‘Ã¶ÏƒÃªÃ¡Î˜Ã–Ã±Ï„ÃœÃ¤Ïƒâ•‘Ã…ÏƒÃ…â•–:',ISNULL(ROWREF,'') FROM BI.V_CARTONTRACK WITH (NOLOCK)  WHERE LABELNO IN (SELECT ORDERKEY FROM BI.V_ORDERS(NOLOCK)WHERE MBOLKEY=@CMBOLKEY)
                  AND TRACKINGNO NOT IN(SELECT CASEID FROM BI.V_PALLETDETAIL WITH (NOLOCK) WHERE PALLETKEY =@C_EXTERNMBOLKEY)
               END
            ELSE IF ISNULL(@C_SHIPPERKEY,'')='SN'AND @HAVE<>@SHOULD
               BEGIN
                  INSERT INTO #MBOL3 VALUES( N'Ïƒâ•‘Ã¶ÏƒÃªÃ¡Î˜Ã–Ã±Ï„ÃœÃ¤Ïƒâ•‘Ã…ÏƒÃ…â•–:',N'Ï„Â«â–’ÂµÃ²â–‘Î£â••Ã¬Ï„Â¼Âªâˆ©â•Ã®Î¦Â»â•–ÂµÃºÃ‡ÂµÆ’Ã‘Ï„Â«â–’ÂµÃ²â–‘ÂµÃ¿Â»ÏƒÃ‰ÂªÏƒâ•–â–“ÂµÃ«Â½ÏƒÃ Â¿ÂµÃªÃ»PACKINFOÂµÃ²â–‘ÂµÃ¬Â«ÂµÃ¿Â»ÏƒÃ‰ÂªÏƒÂ«Ã®ÂµÃ²â”¤')
               END
         END
      SELECT * FROM #MBOL3(NOLOCK)
      DROP TABLE #MBOL3
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