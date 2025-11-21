SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- 2018-07-23 created ===============================================
-- Author   : KHLim
-- Purpose  : split from isp_TRANSMITLOG3Alert for NIKEMY & SG sos#284315
-- Called By: SQL Server Agent Scheduler
-- Date       Author   Ver Purpose
-- 2013-09-18 Leong    1.1 SOS# 290010 - Change email subject.      
-- 2013-12-10 KHLim    1.2 SOS# 284315 diff NIKEMY & SG changes KH01
-- 2014-11-20 SPChin   1.3 SOS326444 - Change CC to BCC             
-- 2015-01-16 KHLim    1.4 SOS#330846 Check Orders.Status  (KH02) 
-- 2015-03-17 KHLim    1.5 SOS#330846 Join Transmitlog3.transmitflag in detail line (KH03) 
-- 2015-03-24 Leong    1.6 SOS#335834 - Revise BCC for NIKESG only. 
-- 2015-03-30 KHLim    1.7 SOS#330846 - Revise SQL & exclude CANC orders (KH04) 
-- 2015-05-07 KHLim    1.8 SOS#330846 - filter OrderStatus (KH05) 
-- 2015-06-03 KHLim    1.9 SOS#330846 - Disclaimer         (KH06) 
-- 2015-08-11 KHLim    2.0 SOS#348457 add LoadPlan.Status  (KH07) 
-- 2017-09-25 KHLim    2.1 WMS-2937 CR_NIKE Auto_Email Format (KH08)
-- 2018-08-10 KHLim    2.2 Revamp https://jira.lfapps.net/browse/WMS-5849
-- ==================================================================
CREATE PROC  [dbo].[isp_TRANSMITLOG3Alert_NIKE]
   @StorerKey  nvarchar(15)
  ,@LISTNAME   nvarchar(30)
  ,@Code       nvarchar(30)   -- TRANSMITLOG3.tablename
  ,@Debug      bit   = 0
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS OFF   ;   SET ANSI_WARNINGS OFF  ;

   DECLARE @OrderKey    nvarchar(10)  
   ,@Subject     nvarchar(255)
   ,@SendTo      varchar(4000)
   ,@Cc          varchar(4000)
   ,@Bcc         varchar(4000)
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
   ,@ErrSeverity  INT          
   ,@c_AlertKey   char(18)
   ,@Host         NVARCHAR(128)
   ,@Module       NVARCHAR(128)
   ,@Row          INT
   ,@ConsigneeKey NVARCHAR(15)
   ,@DeliveryDate CHAR(8)

   SET @Module      = ISNULL(OBJECT_NAME(@@PROCID),'')  --KH08
   IF  @Module = ''
      SET @Module   = 'isp_TRANSMITLOG3Alert_NIKE'
   SET @Host        = ISNULL(HOST_NAME(),'')

   DECLARE @MailQ table( Qid int NOT NULL)
   IF OBJECT_ID('tempdb..#M','u') IS NOT NULL  DROP TABLE  #M;
   CREATE TABLE #M (
   SendTo      varchar(4000)   NULL,
	Cc          varchar(4000)   NULL,
   Bcc         varchar(1024)   NULL,
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

   DECLARE CUR_TML  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT o.ConsigneeKey, convert(char(8),o.deliverydate,112)
   FROM transmitlog3 AS t WITH (nolock)
   JOIN orders       AS o  WITH (nolock) on t.key1        = o.orderkey
   JOIN LoadPlan     AS l WITH (nolock) on l.LoadKey     = o.LoadKey     --KH07
   JOIN packheader   AS p WITH (nolock) on p.orderkey    = o.orderkey    --KH04
   JOIN packdetail   AS pd WITH (nolock) on pd.pickslipno  = p.pickslipno
   JOIN storer       AS c WITH (nolock) on o.consigneekey = c.storerkey
   WHERE t.key3         = @StorerKey 
   and   t.tablename    = @Code
   and   t.transmitflag = '0'         -- CASE @Debug WHEN 0 THEN '0' ELSE '9' END
   and   c.Email1       <> ''
   AND   o.Status       IN ( CASE WHEN @StorerKey <> 'NIKESG' THEN '5' END, '9' ) --KH04
   AND   l.Status       IN ( CASE WHEN @StorerKey <> 'NIKESG' THEN '5' END, '9' ) --KH07
   GROUP BY o.ConsigneeKey, o.deliverydate

   SELECT @Err = @@ERROR
   IF @Err <> 0
   BEGIN
      SET @ErrMsg = 'NSQL'+CONVERT(Char(5),@Err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'
   END

   OPEN CUR_TML
   FETCH NEXT FROM CUR_TML INTO @ConsigneeKey, @DeliveryDate
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

      IF @Debug = 1 PRINT 'Consignee: '+@ConsigneeKey+' Delivery: '+@DeliveryDate

      UPDATE t with (ROWLOCK)   SET transmitflag  = '1'
      FROM transmitlog3 AS t
      JOIN orders       AS o  WITH (nolock) on t.key1        = o.orderkey
      JOIN LoadPlan     AS l  WITH (nolock) on l.LoadKey     = o.LoadKey     --KH07
      JOIN packheader   AS p  WITH (nolock) on p.orderkey    = o.orderkey    --KH05
      JOIN packdetail   AS pd WITH (nolock) on pd.pickslipno = p.pickslipno
      JOIN storer       AS c  WITH (nolock) on o.consigneekey= c.storerkey
      WHERE t.key3        = @StorerKey
      AND   t.tablename   = @Code
      AND   t.transmitflag= '0'
      --AND   c.Email1      <> ''
      AND   o.Status       IN ( CASE WHEN @StorerKey <> 'NIKESG' THEN '5' END, '9' ) --KH05
      AND   l.Status       IN ( CASE WHEN @StorerKey <> 'NIKESG' THEN '5' END, '9' ) --KH07
      AND o.ConsigneeKey   = @ConsigneeKey
      AND o.deliverydate   = @DeliveryDate

      SET @Parm = '@StorerKey nvarchar(15) ,@ConsigneeKey nvarchar(15) ,@DeliveryDate char(8)'

      BEGIN TRY
         IF @Debug = 1 PRINT @Stmt
         INSERT INTO #M
         EXEC sp_ExecuteSql @Stmt ,@Parm ,@StorerKey ,@ConsigneeKey ,@DeliveryDate
         SET @Row = @@ROWCOUNT
      END TRY
      BEGIN CATCH
         SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');
         SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);
         SET @Err = @@ERROR + 50000;
         EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
INSERT ALERT(AlertKey,ModuleName,AlertMessage,Severity,NotifyId,Status,ResolveDate, Resolution,Storerkey, Sku,UOMQty,            Qty             ,ID            ) 
VALUES   (@c_AlertKey,@Module,@Subject,@ErrSeverity,@Host,@Err,@DeliveryDate,@Stmt,@StorerKey,@ConsigneeKey,@Row,DATEDIFF(s,@dBegin,GETDATE()),LEFT(@ErrMsg,20));
         THROW @Err, @ErrMsg, 1;
      END CATCH

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

      IF @R04 > 0  -- check >0 carton  KH04
      BEGIN

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
,@DeliveryDate+@ConsigneeKey
,'DeliveryConsignee'
,CASE WHEN @Debug>0 THEN 'CalvinKhor@LiFung.com' ELSE @SendTo END
,CASE WHEN @Debug>0 THEN 'OSGITSWMSDBA@lifung.com' ELSE @Cc END
,CASE WHEN @Debug>0 THEN 'KahHweeLim@lflogistics.com' ELSE @Bcc END
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
      IF @Debug = 1 PRINT ''
      SELECT @Qid = Qid FROM @MailQ

      IF ISNULL(@Qid,0) > 0
      BEGIN
         SET @Parm    = '@Qid int, @StorerKey nvarchar(15) ,@ConsigneeKey nvarchar(15) ,@DeliveryDate char(8)'
         BEGIN TRY
            IF @Debug = 1 PRINT @StmtDet
            INSERT INTO MailQDet ( [Qid]
            ,[C01],[C02],[C03],[C04]
            ,[C05],[C06],[C07],[C08]
            ,[C09],[C10],[C11],[C12]
            ,[C13],[C14],[C15],OrderKey )
            EXEC sp_ExecuteSql @StmtDet ,@Parm ,@Qid ,@StorerKey ,@ConsigneeKey, @DeliveryDate
            SET @Row = @@ROWCOUNT
         END TRY
         BEGIN CATCH
            SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');
            SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);
            SET @Err = @@ERROR + 50000;
            EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
   INSERT ALERT(AlertKey,ModuleName,AlertMessage,Severity,NotifyId,Status,ResolveDate, Resolution,Storerkey, Sku,UOMQty,            Qty             ,ID               ) 
   VALUES   (@c_AlertKey,@Module,@Subject,@ErrSeverity,@Host,@Err,@DeliveryDate,@StmtDet,@StorerKey,@ConsigneeKey,@Row,DATEDIFF(s,@dBegin,GETDATE()),LEFT(@ErrMsg,20));
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

      END -- end of check >0 carton KH04

      UPDATE t with (ROWLOCK)   SET transmitflag  = '9'
      FROM transmitlog3 AS t
      JOIN orders       AS o  WITH (nolock) on t.key1        = o.orderkey
      JOIN LoadPlan     AS l  WITH (nolock) on l.LoadKey     = o.LoadKey     --KH07
      JOIN packheader   AS p  WITH (nolock) on p.orderkey    = o.orderkey    --KH05
      JOIN packdetail   AS pd WITH (nolock) on pd.pickslipno = p.pickslipno
      JOIN storer       AS c  WITH (nolock) on o.consigneekey= c.storerkey
      WHERE t.key3        = @StorerKey
      AND   t.tablename   = @Code
      AND   t.transmitflag= '1'
      AND   c.Email1      <> ''
      AND   o.Status       IN ( CASE WHEN @StorerKey <> 'NIKESG' THEN '5' END, '9' ) --KH05
      AND   l.Status       IN ( CASE WHEN @StorerKey <> 'NIKESG' THEN '5' END, '9' ) --KH07
      AND o.ConsigneeKey   = @ConsigneeKey
      AND o.deliverydate   = @DeliveryDate

      FETCH NEXT FROM CUR_TML INTO @ConsigneeKey, @DeliveryDate
   END

   CLOSE CUR_TML
   DEALLOCATE CUR_TML
END /* main procedure */

GO