SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************************************/        
/* Stored Procedure: [dbo].[isp_Transmit_MailStdGroup]                                                            */        
/* Creation Date: 2019-04-15                                                                                      */        
/* Copyright: IDS                                                                                                 */        
/* Written by: kelvinongcy                                                                                        */        
/*                                                                                                                */        
/* Remarks:                                                                                                       */        
/*                                                                                                                */        
/* Purpose:  Create Delivery AutoEmail Alert for  respective consignee                                            */        
/*                                                                                                                */        
/*                                                                                                                */        
/* Called By:                                                                                                     */        
/*                                                                                                                */        
/* PVCS Version:                                                                                                  */        
/*                                                                                                                */        
/* Version:                                                                                                       */        
/*                                                                                                                */        
/* Data Modifications:                                                                                            */        
/*                                                                                                                */        
/* Updates:                                                                                                       */        
/* Date         Author        Ver  Purposes                                                                       */        
/* 2019-04-15    kocy        1.0   https://jira.lfapps.net/browse/WMS-8555                                        */        
/* 25-Feb-2020  kocy          1.1  https://jira.lfapps.net/browse/WMS-12239                                       */  
/* 03-Jun-2020  kocy02        1.2  https://jira.lfapps.net/browse/WMS-13482 (Changed ShipDate to DepartureDate,   */  
/*                                 Added Total Quantities (PackHeader.TTLCNTS and SUM(Orders.ShippedQty ) )       */   
/* 04-Jun-2020  kocy03        1.3  Bug fix - TML3 will have  duplicate same key1 with different table.            */  
/*                                 need filter out by @Code in  @Stmt and @StmtDet.Else cause double count        */  
/* 04-aug-2020  kocy04        1.4  https://jiralfl.atlassian.net/browse/WMS-13946  need to group by mbolkey for   */  
/*                                  trigger one email alert per one mbol is mark shipped. @Mbolkey only used      */  
/*                                 in Unilever task                                                               */
/* 23-Sept-2020  kocy05       1.5  Bug fix  for Unilever storer. Only SendTo got valid email only sent automail   */
/******************************************************************************************************************/         
CREATE PROC  [dbo].[isp_Transmit_MailStdGroup]   
(  
   @StorerKey  nvarchar(15)        
  ,@LISTNAME   nvarchar(30)        
  ,@Code       nvarchar(30)   -- TRANSMITLOG3.tablename        
  ,@Debug  bit   = 0   
 )  
AS        
BEGIN        
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;        
   SET ANSI_NULLS OFF   ;   SET ANSI_WARNINGS OFF  ;        
                    
   DECLARE @ConsigneeKey    nvarchar(15)          
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
   ,@ExternOrderKey nvarchar(30)        
   ,@HolidayUDF        nvarchar(20)        
   ,@C01Agg NVARCHAR (25)   --kocy01        
   ,@C02Agg NVARCHAR (25)        
   ,@C03Agg NVARCHAR (25)        
   ,@C04Agg NVARCHAR (25)        
   ,@C05Agg NVARCHAR (25)        
   ,@C06Agg NVARCHAR (25)        
   ,@C07Agg NVARCHAR (25)        
   ,@C08Agg NVARCHAR (25)        
   ,@C09Agg NVARCHAR (25)        
   ,@C10Agg NVARCHAR (25)        
   ,@C11Agg NVARCHAR (25)        
   ,@C12Agg NVARCHAR (25)        
   ,@C13Agg NVARCHAR (25)        
   ,@C14Agg NVARCHAR (25)        
   ,@C15Agg NVARCHAR (25)        
   ,@ShipDate nvarchar(20)   
   ,@MbolKey nvarchar(15)  
        
   DECLARE @MailQ table( Qid int NOT NULL)           
   IF OBJECT_ID('tempdb..#M','u') IS NOT NULL  DROP TABLE  #M;          
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
        
   EXEC dbo.isp_GetCodeLkup @LISTNAME, @StorerKey, @Code, 'ColAggOptions' , @ErrMsg OUTPUT ,@Err OUTPUT     --kocy01        
   , ''            , ''             ,@C06Agg  OUTPUT, ''    , ''          
   , @C01Agg OUTPUT, @C02Agg OUTPUT,  @C03Agg OUTPUT,@C04Agg OUTPUT  , @C05Agg OUTPUT        
              
   EXEC dbo.isp_GetCodeLkup @LISTNAME, @StorerKey, @Code, 'ColAgg2Options' , @ErrMsg OUTPUT ,@Err OUTPUT    --kocy01        
   , @C07Agg OUTPUT, ''             , @C08Agg OUTPUT, @C09Agg OUTPUT, @C10Agg OUTPUT          
   , @C11Agg OUTPUT, @C12Agg OUTPUT , @C13Agg OUTPUT, @C14Agg OUTPUT, @C15Agg OUTPUT         
        
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
   SELECT o.ConsigneeKey,o.MBOLKey, CONVERT(char(8),m.DepartureDate,112) AS DepartureDate    --kocy02 kocy04  
   FROM TRANSMITLOG3 AS t WITH (NOLOCK)        
   JOIN ORDERS   AS o WITH (NOLOCK) ON o.OrderKey = t.key1        
   JOIN storer       AS c WITH (nolock) on o.consigneekey = c.storerkey        
   JOIN MBOLDetail   AS md WITH (nolock) ON md.OrderKey = o.OrderKey        
   JOIN MBOL  AS m WITH (nolock) ON m.MBolKey = md.MBOLKey        
   LEFT JOIN packheader   AS p WITH (nolock) on p.orderkey    = o.orderkey             
   LEFT JOIN packdetail   AS pd WITH (nolock) on pd.pickslipno  = p.pickslipno        
   WHERE t.key3 = @StorerKey        
   AND t.tablename = @Code        
   AND t.transmitflag ='0'        
   AND   o.DocType <> 'E'        
   AND c.[Type] = '2'        
   AND o.[Status] IN ('9')        
   AND m.[Status] IN ('9')        
   AND NOT EXISTS (SELECT 1 FROM MailQDet WITH (NOLOCK) WHERE OrderKey = o.OrderKey)       
   GROUP BY o.ConsigneeKey, o.MBOLKey, CONVERT(CHAR(8),m.DepartureDate, 112)      
   HAVING CONVERT(CHAR(8),m.DepartureDate, 112) = CONVERT(CHAR(8), GETDATE(), 112)        
       
        
   SELECT @Err = @@ERROR        
   IF @Err <> 0        
   BEGIN        
      SET @ErrMsg = 'NSQL'+CONVERT(Char(5),@Err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'        
   END        
        
   OPEN CUR_TML        
   FETCH NEXT FROM CUR_TML INTO @ConsigneeKey, @MbolKey,  @ShipDate        
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
      
        
       IF @Debug = 1         
       BEGIN        
          SELECT @ConsigneeKey 'ConsigneeKey', @ShipDate 'ShipDate'      
       END         
             
        UPDATE t with (ROWLOCK)   SET t.transmitflag = '1'         
        FROM TRANSMITLOG3 AS t        
        JOIN ORDERS   AS o WITH (NOLOCK) ON o.OrderKey = t.key1        
        JOIN OrderDetail  AS od WITH (nolock) ON od.OrderKey = o.OrderKey        
        JOIN storer       AS c WITH (nolock) on o.consigneekey = c.storerkey        
        JOIN MBOLDetail   AS md WITH (nolock) ON md.OrderKey = o.OrderKey        
        JOIN MBOL  AS m WITH (nolock) ON m.MBolKey = md.MBOLKey        
        LEFT JOIN packheader   AS p WITH (nolock) on p.orderkey    = o.orderkey             
        LEFT JOIN packdetail   AS pd WITH (nolock) on pd.pickslipno  = p.pickslipno        
        WHERE t.key3 = @StorerKey        
        AND t.tablename = @Code        
        AND t.transmitflag ='0'        
        AND o.DocType <> 'E'        
        AND c.[Type] = '2'        
        AND o.[Status] IN ('9')        
        AND m.[Status] IN ('9')        
        AND o.ConsigneeKey = @ConsigneeKey  
        AND m.Mbolkey  = @MbolKey  
        AND CONVERT(char(8),m.DepartureDate,112) = @ShipDate      
           
      /* kocy03 - need pass by @Code due to duplicate same TML3.key1 records will cause double count sum total */  
      SET @Parm = '@StorerKey nvarchar(15), @Code nvarchar(30), @ConsigneeKey nvarchar(15), @MbolKey nvarchar(15) ,@ShipDate char(8)'      
      BEGIN TRY        
         IF @Debug = 1 PRINT @Stmt       
         INSERT INTO #M        
         EXEC sp_ExecuteSql @Stmt ,@Parm ,@StorerKey, @Code, @ConsigneeKey, @MbolKey,  @ShipDate      
      END TRY        
      BEGIN CATCH        
         SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');        
         SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);        
         SET @Err = @@ERROR + 50000;        
         THROW @Err, @ErrMsg, 1;        
      END CATCH        
      EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''        
      INSERT ALERT(AlertKey, ModuleName          ,AlertMessage,Severity     ,NotifyId   ,Status,ResolveDate, Resolution  ,Storerkey,Activity,TaskDetailKey,UCCNo    )         
      VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@ErrMsg   ,@ErrSeverity,HOST_NAME(),@Err,@dBegin    ,@Stmt   ,@StorerKey   ,@Code ,@ConsigneeKey   ,@ExternOrderKey);        
      
      -- kocy05 unilever only sent email if SendTo if have valid email
      IF @StorerKey = 'Unilever'
      BEGIN
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
         WHERE SendTo <> ';'
      END
      ELSE
      BEGIN
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
      END
        
     IF (@SendTo <> '')
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
      ,[C01Agg],[C02Agg], [C03Agg], [C04Agg], [C05Agg], [C06Agg], [C07Agg],[C08Agg], [C09Agg],[C10Agg], [C11Agg], [C12Agg],[C13Agg],[C14Agg],[c15Agg] --kocy01        
      ) OUTPUT INSERTED.Qid INTO @MailQ        
      VALUES ( 0        
      ,@StorerKey        
      ,@ConsigneeKey        
      ,'DeliveryConsignee'        
      ,CASE WHEN @Debug=1 THEN 'kelvinongcy@LFLogistics.com' ELSE @SendTo END        
      ,CASE WHEN @Debug=1 THEN '' ELSE @Cc END        
      ,CASE WHEN @Debug=1 THEN '' ELSE @Bcc END        
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
      ,ISNULL(@C01Agg, ''), ISNULL(@C02Agg, ''), ISNULL(@C03Agg, ''), ISNULL(@C04Agg, ''), ISNULL(@C05Agg, ''), ISNULL(@C06Agg, ''), ISNULL(@C07Agg, ''), ISNULL(@C08Agg, '')  --kocy01        
      ,ISNULL(@C09Agg, ''), ISNULL(@C10Agg, ''), ISNULL(@C11Agg, ''), ISNULL(@C12Agg, ''), ISNULL(@C13Agg, ''), ISNULL(@C14Agg, ''), ISNULL(@C15Agg, '')  --kocy01        
      )

      SELECT @Qid = Qid FROM @MailQ
     END
     
              
        
      IF ISNULL(@Qid,0) > 0        
      BEGIN    
         /* kocy03 - need pass by @Code due to duplicate same TML3.key1 records will cause double count sum total */  
         SET @Parm = '@Qid INT, @StorerKey nvarchar(15) , @Code nvarchar(30), @ConsigneeKey nvarchar(15) ,@MbolKey nvarchar(15) ,@ShipDate char(8)'        
         BEGIN TRY        
            IF @Debug = 1 PRINT @StmtDet        
            INSERT INTO MailQDet ( [Qid]        
            ,[C01],[C02],[C03],[C04]        
            ,[C05],[C06],[C07],[C08]        
            ,[C09],[C10],[C11],[C12]        
            ,[C13],[C14],[C15],OrderKey )        
            EXEC sp_ExecuteSql @StmtDet ,@Parm ,@Qid ,@StorerKey ,@Code, @ConsigneeKey, @MbolKey, @ShipDate      
         END TRY        
         BEGIN CATCH        
            SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');        
            SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);        
            SET @Err = @@ERROR + 50000;        
            EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''        
            INSERT ALERT(AlertKey, ModuleName          ,AlertMessage,Severity     ,NotifyId   ,Status,ResolveDate, Resolution  ,Storerkey,Activity,TaskDetailKey,UCCNo    )         
            VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@ErrMsg   ,@ErrSeverity,HOST_NAME(),@Err,@dBegin    ,@Stmt   ,@StorerKey   ,@Code ,@ConsigneeKey   ,@ExternOrderKey);        
            THROW @Err, @ErrMsg, 1;        
         END CATCH        
        
         IF @Err = 0        
         BEGIN        
            EXEC dbo.isp_MailQBuildCalcGrandTotal @Qid        
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
        
        UPDATE t with (ROWLOCK)   SET t.transmitflag = '9'         
        FROM TRANSMITLOG3 AS t        
        JOIN ORDERS   AS o WITH (NOLOCK) ON o.OrderKey = t.key1        
        JOIN storer       AS c WITH (nolock) on o.consigneekey = c.storerkey        
        JOIN MBOLDetail   AS md WITH (nolock) ON md.OrderKey = o.OrderKey        
        JOIN MBOL  AS m WITH (nolock) ON m.MBolKey = md.MBOLKey        
        LEFT JOIN packheader   AS p WITH (nolock) on p.orderkey    = o.orderkey             
        LEFT JOIN packdetail   AS pd WITH (nolock) on pd.pickslipno  = p.pickslipno        
        WHERE t.key3 = @StorerKey        
        AND t.tablename = @Code        
        AND t.transmitflag ='1'        
        AND o.DocType <> 'E'        
        AND c.[Type] = '2'        
        AND o.[Status] IN ('9')        
        AND m.[Status] IN ('9')        
        AND o.ConsigneeKey = @ConsigneeKey   
        AND m.Mbolkey  = @MbolKey  
        AND CONVERT(char(8),m.DepartureDate,112) = @ShipDate      
        
        
    FETCH NEXT FROM CUR_TML INTO @ConsigneeKey, @MbolKey, @ShipDate      
   END        
        
   CLOSE CUR_TML        
   DEALLOCATE CUR_TML        
END /* main procedure */   

GO