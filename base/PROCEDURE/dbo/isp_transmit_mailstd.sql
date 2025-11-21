SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- 2018-07-23 created ===============================================
-- Author   : KHLim   https://jira.lfapps.net/browse/WMS-5656
-- Purpose  : standard for isp_TRANSMITLOG3Alert & isp_Transmit_Mail_ASN
-- Called By: SQL Server Agent Scheduler
-- Date       Author   Ver Purpose
-- 2018-09-03 KH01   Check ShppedQty https://jira.lfapps.net/browse/WMS-6224
-- 2018-10-15 KH02   RCPTMAIL https://jira.lfapps.net/browse/WMS-6490
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
-- ==================================================================
CREATE PROC  [dbo].[isp_Transmit_MailStd]
   @StorerKey  nvarchar(15)
  ,@LISTNAME   nvarchar(30)
  ,@Code       nvarchar(30)   -- TRANSMITLOG3.tablename
  ,@Debug      bit   = 0
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS OFF   ;   SET ANSI_WARNINGS OFF  ;
            
   DECLARE @UniqueKey    nvarchar(10)  
   ,@Subject     nvarchar(255)
   ,@SendTo      varchar(4000)
   ,@Cc          varchar(4000)
   ,@Bcc         varchar(4000)
   ,@dETA        datetime
   ,@Err         int
   ,@ErrMsg      NVARCHAR(255)
   ,@Stmt        nvarchar(MAX) 
   ,@StmtDet     nvarchar(MAX) 
   ,@Parm        nvarchar(4000)
   ,@cSQL        nvarchar(4000)
   ,@Qid         INT
   ,@RowCount    INT
   ,@Header      nvarchar(2000)
   ,@Footer      nvarchar(2000)
   ,@THColor     char(6)
   ,@R01Name     nvarchar(128)  ,@R01         nvarchar(1000)
   ,@R02Name     nvarchar(128)  ,@R02         nvarchar(1000)
   ,@R03Name     nvarchar(128)  ,@R03         nvarchar(1000)
   ,@R04Name     nvarchar(128)  ,@R04         nvarchar(1000)
   ,@R05Name     nvarchar(128)  ,@R05         nvarchar(1000)
   ,@R06Name     nvarchar(128)  ,@R06         nvarchar(1000)
   ,@R07Name     nvarchar(128)  ,@R07         nvarchar(1000)
   ,@R08Name     nvarchar(128)  ,@R08         nvarchar(1000)
   ,@R09Name     nvarchar(128)  ,@R09         nvarchar(1000)
   ,@R10Name     nvarchar(128)  ,@R10         nvarchar(1000)
   ,@R11Name     nvarchar(128)  ,@R11         nvarchar(1000)
   ,@R12Name     nvarchar(128)  ,@R12         nvarchar(1000)
   ,@R13Name     nvarchar(128)  ,@R13         nvarchar(1000)
   ,@R14Name     nvarchar(128)  ,@R14         nvarchar(1000)
   ,@R15Name     nvarchar(128)  ,@R15         nvarchar(1000)
   ,@C01Align    char(1)        ,@C01Name     nvarchar(128)
   ,@C02Align    char(1)        ,@C02Name     nvarchar(128)
   ,@C03Align    char(1)        ,@C03Name     nvarchar(128)
   ,@C04Align    char(1)        ,@C04Name     nvarchar(128)
   ,@C05Align    char(1)        ,@C05Name     nvarchar(128)
   ,@C06Align    char(1)        ,@C06Name     nvarchar(128)
   ,@C07Align    char(1)        ,@C07Name     nvarchar(128)
   ,@C08Align    char(1)        ,@C08Name     nvarchar(128)
   ,@C09Align    char(1)        ,@C09Name     nvarchar(128)
   ,@C10Align    char(1)        ,@C10Name     nvarchar(128)
   ,@C11Align    char(1)        ,@C11Name     nvarchar(128)
   ,@C12Align    char(1)        ,@C12Name     nvarchar(128)
   ,@C13Align    char(1)        ,@C13Name     nvarchar(128)
   ,@C14Align    char(1)        ,@C14Name     nvarchar(128)
   ,@C15Align    char(1)        ,@C15Name     nvarchar(128)
   ,@Short        NVARCHAR(10) ,@Notes2 NVARCHAR(4000)
   ,@dBegin       DATETIME
   ,@ErrSeverity INT
   ,@c_AlertKey   char(18)
   ,@transmitlogkey nvarchar(10)
   ,@ExternOrderKey nvarchar(50)   --tlting_ext
   ,@HolidayUDF        nvarchar(20) 

   DECLARE @MailQ table( Qid int NOT NULL)
   IF OBJECT_ID('tempdb..#K','u') IS NOT NULL  DROP TABLE  #K;
   IF OBJECT_ID('tempdb..#M','u') IS NOT NULL  DROP TABLE  #M;
   CREATE TABLE #K ( key1 nvarchar(10) NOT NULL PRIMARY KEY )
   CREATE TABLE #M (
   SendTo      varchar(4000)   NULL,
	Cc          varchar(4000)   NULL,
	Bcc         varchar(4000)   NULL,
	[Subject]   nvarchar(255)   NULL,
   R01         nvarchar(1000)  NULL,
   R02         nvarchar(1000)  NULL,
   R03         nvarchar(1000)  NULL,
   R04         nvarchar(1000)  NULL,
   R05         nvarchar(1000)  NULL,
   R06         nvarchar(1000)  NULL,
   R07         nvarchar(1000)  NULL,
   R08         nvarchar(1000)  NULL,
   R09         nvarchar(1000)  NULL,
   R10         nvarchar(1000)  NULL,
   R11         nvarchar(1000)  NULL,
   R12         nvarchar(1000)  NULL,
   R13         nvarchar(1000)  NULL,
   R14         nvarchar(1000)  NULL,
   R15         nvarchar(1000)  NULL )

   SELECT @Err = 0, @ErrMsg = '', @ErrSeverity = 0

   EXEC dbo.isp_GetCodeLkup @LISTNAME, @StorerKey, @Code, 'MailOptions', @ErrMsg OUTPUT ,@Err OUTPUT
   , @Footer  OUTPUT, @THColor OUTPUT, @R06Name OUTPUT, @Stmt    OUTPUT, @Header  OUTPUT
   , @R01Name OUTPUT, @R02Name OUTPUT, @R03Name OUTPUT, @R04Name OUTPUT, @R05Name OUTPUT

   EXEC dbo.isp_GetCodeLkup @LISTNAME, @StorerKey, @Code, 'RowOptions' , @ErrMsg OUTPUT ,@Err OUTPUT
   , @R07Name OUTPUT, @Short   OUTPUT, @R08Name OUTPUT, @R09Name OUTPUT, @R10Name OUTPUT
   , @R11Name OUTPUT, @R12Name OUTPUT, @R13Name OUTPUT, @R14Name OUTPUT, @R15Name OUTPUT

   EXEC dbo.isp_GetCodeLkup @LISTNAME, @StorerKey, @Code, 'LineOptions', @ErrMsg OUTPUT ,@Err OUTPUT
   , @SendTo  OUTPUT, ''             , @C06Name OUTPUT, @StmtDet OUTPUT, @Notes2  OUTPUT
   , @C01Name OUTPUT, @C02Name OUTPUT, @C03Name OUTPUT, @C04Name OUTPUT, @C05Name OUTPUT

   EXEC dbo.isp_GetCodeLkup @LISTNAME, @StorerKey, @Code, 'ColOptions' , @ErrMsg OUTPUT ,@Err OUTPUT
   , @C07Name OUTPUT, ''             , @C08Name OUTPUT, @C09Name OUTPUT, @C10Name OUTPUT
   , @C11Name OUTPUT, @C12Name OUTPUT, @C13Name OUTPUT, @C14Name OUTPUT, @C15Name OUTPUT
   SELECT @C01Align= SUBSTRING(@Notes2, 1,1)
         ,@C02Align= SUBSTRING(@Notes2, 2,1)
         ,@C03Align= SUBSTRING(@Notes2, 3,1)
         ,@C04Align= SUBSTRING(@Notes2, 4,1)
         ,@C05Align= SUBSTRING(@Notes2, 5,1)
         ,@C06Align= SUBSTRING(@Notes2, 6,1)
         ,@C07Align= SUBSTRING(@Notes2, 7,1)
         ,@C08Align= SUBSTRING(@Notes2, 8,1)
         ,@C09Align= SUBSTRING(@Notes2, 9,1)
         ,@C10Align= SUBSTRING(@Notes2,10,1)
         ,@C11Align= SUBSTRING(@Notes2,11,1)
         ,@C12Align= SUBSTRING(@Notes2,12,1)
         ,@C13Align= SUBSTRING(@Notes2,13,1)
         ,@C14Align= SUBSTRING(@Notes2,14,1)
         ,@C15Align= SUBSTRING(@Notes2,15,1)

   IF @Code = 'RCPTMAIL'  --KH02
   BEGIN
      INSERT #K SELECT key1
      FROM TRANSMITLOG3 t WITH (nolock)
      WHERE tablename    = @Code
      and   key3         = @StorerKey
      and   transmitflag = '0'
      GROUP BY key1
   END
   ELSE
   BEGIN
      INSERT #K SELECT key1 --KH01
      FROM TRANSMITLOG3 t WITH (nolock)
      WHERE tablename    = @Code
      and   key3         = @StorerKey
      and   transmitflag = '0'
      AND   EXISTS ( SELECT 1 FROM ORDERDETAIL d WHERE d.OrderKey=t.Key1 AND ShippedQty > 0 ) --KH01
      GROUP BY key1
   END

   IF @Debug=1 
   BEGIN
      SELECT * FROM #K
      SELECT '@Stmt'= @Stmt, '@StmtDet'= @StmtDet
   END

   DECLARE CUR_TML  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT key1 FROM #K

   SELECT @Err = @@ERROR
   IF @Err <> 0
   BEGIN
      SET @ErrMsg = 'NSQL'+CONVERT(Char(5),@Err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'
   END

   OPEN CUR_TML
   FETCH NEXT FROM CUR_TML INTO @UniqueKey --KH01
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT -- must reset all variables
         @SendTo =''
      ,@Cc     =''
      ,@Bcc    =''
      ,@Subject=''
      ,@R01    =''
      ,@R02    =''
      ,@R03    =''
      ,@R04    =''
      ,@R05    =''
      ,@R06    =''
      ,@R07    =''
      ,@R08    =''
      ,@R09    =''
      ,@R10    =''
      ,@R11    =''
      ,@R12    =''
      ,@R13    =''
      ,@R14    =''
      ,@R15    =''
      TRUNCATE TABLE #M

      UPDATE TRANSMITLOG3 SET transmitflag = '1' WHERE transmitflag = '0' --KH01
      AND tablename=@Code AND key1=@UniqueKey AND key3=@StorerKey 

      SET @Parm = '@StorerKey nvarchar(15) ,@'+CASE WHEN @Code='RCPTMAIL' THEN 'Receipt' ELSE 'Order' END+'Key nvarchar(10)'
      BEGIN TRY
         IF @Debug = 1 PRINT @Stmt
         INSERT INTO #M
         EXEC sp_ExecuteSql @Stmt ,@Parm ,@StorerKey ,@UniqueKey
      END TRY
      BEGIN CATCH
         SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');
         SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);
         SET @Err = @@ERROR + 50000;
         THROW @Err, @ErrMsg, 1;
      END CATCH
      EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
      INSERT ALERT(AlertKey, ModuleName          ,AlertMessage,Severity     ,NotifyId   ,Status,ResolveDate, Resolution  ,Storerkey,Activity,TaskDetailKey,UCCNo    ) 
      VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@ErrMsg   ,@ErrSeverity,HOST_NAME(),@Err,@dBegin    ,@Stmt   ,@StorerKey   ,@Code ,@UniqueKey   ,@ExternOrderKey);

      SELECT 
       @SendTo =ISNULL(SendTo   ,'')
      ,@Cc     =ISNULL(Cc       ,'')
      ,@Bcc    =ISNULL(Bcc      ,'')
      ,@Subject=ISNULL([Subject],'')
      ,@R01    =ISNULL(R01      ,'')
      ,@R02    =ISNULL(R02      ,'')
      ,@R03    =ISNULL(R03      ,'')
      ,@R04    =ISNULL(R04      ,'')
      ,@R05    =ISNULL(R05      ,'')
      ,@R06    =ISNULL(R06      ,'')
      ,@R07    =ISNULL(R07      ,'')
      ,@R08    =ISNULL(R08      ,'')
      ,@R09    =ISNULL(R09      ,'')
      ,@R10    =ISNULL(R10      ,'')
      ,@R11    =ISNULL(R11      ,'')
      ,@R12    =ISNULL(R12      ,'')
      ,@R13    =ISNULL(R13      ,'')
      ,@R14    =ISNULL(R14      ,'')
      ,@R15    =ISNULL(R15      ,'')
      FROM #M     

      IF ISNULL(@Short,'') = 'ETARule'
      BEGIN
         SET @dETA = @R07

         IF DatePart(dw,@dETA) = 1
         BEGIN
            SET @dETA = DATEADD(day, 1, @dETA)
         END

         IF EXISTS ( SELECT TOP 1 1                   FROM HolidayDetail d JOIN HolidayHeader h ON h.HolidayKey=d.HolidayKey 
               WHERE h.UserDefine01=YEAR(GETDATE()) AND HolidayDate = CONVERT(CHAR(8),@dETA,112) )
         BEGIN
            SELECT TOP 1 @HolidayUDF = d.UserDefine01 FROM HolidayDetail d JOIN HolidayHeader h ON h.HolidayKey=d.HolidayKey 
               WHERE h.UserDefine01=YEAR(GETDATE()) AND HolidayDate = CONVERT(CHAR(8),@dETA,112)
            IF ISNUMERIC(@HolidayUDF)<1
            BEGIN
               SET @HolidayUDF = '1'
            END
            SET @dETA = DATEADD(day, TRY_CAST(@HolidayUDF AS int), @dETA)
         END

         SET @R07 = convert(varchar,@dETA,106)
      END

      INSERT MailQ (mailitem_id
,StorerKey
,UniqueKey
,UniqueKeyName
,[SendTo]
,[Cc]
,[Bcc]
,[Subject]
,[Header]
,[Footer]
,[THColor]
,[R01Name],[R01],[R02Name],[R02],[R03Name],[R03],[R04Name],[R04]
,[R05Name],[R05],[R06Name],[R06],[R07Name],[R07],[R08Name],[R08]
,[R09Name],[R09],[R10Name],[R10],[R11Name],[R11],[R12Name],[R12]
,[R13Name],[R13],[R14Name],[R14],[R15Name],[R15]
,[C01Align],[C01Name],[C02Align],[C02Name],[C03Align],[C03Name],[C04Align],[C04Name]
,[C05Align],[C05Name],[C06Align],[C06Name],[C07Align],[C07Name],[C08Align],[C08Name]
,[C09Align],[C09Name],[C10Align],[C10Name],[C11Align],[C11Name],[C12Align],[C12Name]
,[C13Align],[C13Name],[C14Align],[C14Name],[C15Align],[C15Name]
) OUTPUT INSERTED.Qid INTO @MailQ
VALUES ( 0
,@StorerKey
,@UniqueKey
,CASE WHEN @Code='RCPTMAIL' THEN 'ReceiptKey' ELSE 'OrderKey' END
,CASE WHEN @Debug=1 AND LEFT(DB_NAME(),2)='CN' THEN 'LinkLin@lflogistics.com;AdrianAwYoung@lflogistics.com'
      WHEN @Debug=1 AND LEFT(DB_NAME(),2)='ID' THEN 'TriWahyuAji@lflogistics.com' ELSE @SendTo END
,CASE WHEN @Debug=1 THEN 'OSGITSWMSDBA@lifung.com' ELSE @Cc END
,CASE WHEN @Debug=1 THEN 'KahHweeLim@lflogistics.com' ELSE @Bcc END
,ISNULL(@Subject ,'')
,ISNULL(@Header  ,'')
,ISNULL(@Footer  ,'')
,ISNULL(@THColor ,'')
,ISNULL(@R01Name ,''),ISNULL(@R01,''),ISNULL(@R02Name,''),ISNULL(@R02,''),ISNULL(@R03Name,''),ISNULL(@R03,''),ISNULL(@R04Name,''),ISNULL(@R04,'')
,ISNULL(@R05Name ,''),ISNULL(@R05,''),ISNULL(@R06Name,''),ISNULL(@R06,''),ISNULL(@R07Name,''),ISNULL(@R07,''),ISNULL(@R08Name,''),ISNULL(@R08,'')
,ISNULL(@R09Name ,''),ISNULL(@R09,''),ISNULL(@R10Name,''),ISNULL(@R10,''),ISNULL(@R11Name,''),ISNULL(@R11,''),ISNULL(@R12Name,''),ISNULL(@R12,'')
,ISNULL(@R13Name ,''),ISNULL(@R13,''),ISNULL(@R14Name,''),ISNULL(@R14,''),ISNULL(@R15Name,''),ISNULL(@R15,'')
,ISNULL(@C01Align,''),ISNULL(@C01Name,''),ISNULL(@C02Align,''),ISNULL(@C02Name,''),ISNULL(@C03Align,''),ISNULL(@C03Name,''),ISNULL(@C04Align,''),ISNULL(@C04Name,'')
,ISNULL(@C05Align,''),ISNULL(@C05Name,''),ISNULL(@C06Align,''),ISNULL(@C06Name,''),ISNULL(@C07Align,''),ISNULL(@C07Name,''),ISNULL(@C08Align,''),ISNULL(@C08Name,'')
,ISNULL(@C09Align,''),ISNULL(@C09Name,''),ISNULL(@C10Align,''),ISNULL(@C10Name,''),ISNULL(@C11Align,''),ISNULL(@C11Name,''),ISNULL(@C12Align,''),ISNULL(@C12Name,'')
,ISNULL(@C13Align,''),ISNULL(@C13Name,''),ISNULL(@C14Align,''),ISNULL(@C14Name,''),ISNULL(@C15Align,''),ISNULL(@C15Name,'')
)

      SELECT @Qid = Qid FROM @MailQ

      IF ISNULL(@Qid,0) > 0
      BEGIN
         SET @Parm    = '@Qid int, @StorerKey nvarchar(15)  ,@'+CASE WHEN @Code='RCPTMAIL' THEN 'Receipt' ELSE 'Order' END+'Key nvarchar(10)'
         BEGIN TRY
            IF @Debug = 1 PRINT @StmtDet
            INSERT INTO MailQDet ( [Qid]
            ,[C01],[C02],[C03],[C04]
            ,[C05],[C06],[C07],[C08]
            ,[C09],[C10],[C11],[C12]
            ,[C13],[C14],[C15],OrderKey )
            EXEC sp_ExecuteSql @StmtDet ,@Parm ,@Qid ,@StorerKey ,@UniqueKey
         END TRY
         BEGIN CATCH
            SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');
            SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);
            SET @Err = @@ERROR + 50000;
            EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
            INSERT ALERT(AlertKey, ModuleName          ,AlertMessage,Severity     ,NotifyId   ,Status,ResolveDate, Resolution  ,Storerkey,Activity,TaskDetailKey,UCCNo    ) 
            VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@ErrMsg   ,@ErrSeverity,HOST_NAME(),@Err,@dBegin    ,@Stmt   ,@StorerKey   ,@Code ,@UniqueKey   ,@ExternOrderKey);
            THROW @Err, @ErrMsg, 1;
         END CATCH

         IF @Err = 0
         BEGIN
            EXEC dbo.isp_MailQBuild @Qid
         END
         ELSE
         BEGIN
            PRINT @Qid
         END
      END
      ELSE
      BEGIN
         PRINT 'No @Qid'
      END

      UPDATE TRANSMITLOG3 SET transmitflag = '9' WHERE transmitflag = '1' --KH01
      AND tablename=@Code AND key1=@UniqueKey AND key3=@StorerKey 

      FETCH NEXT FROM CUR_TML INTO @UniqueKey --KH01
   END

   CLOSE CUR_TML
   DEALLOCATE CUR_TML
END /* main procedure */


GO