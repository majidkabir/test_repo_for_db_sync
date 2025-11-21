SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- 2012-06-14 created ===============================================
-- Author   : KHLim
-- Purpose  : improve TH isp_NikePickingEmailAlert
-- Called By: SQL Server Agent Scheduler
-- Date       Author   Ver Purpose
-- 2012-07-18  Kunakorn  change data report for other STBTH 
-- 2012-08-04  Kunakorn  change master query on Email to use Email1&Email2 on table storer 
-- 2013-02-05  KHLim     remove hardcoding 
-- 2013-03-08  KHLim     ensure email don't start with semicolon KH01 
-- 2013-03-18  KHLim     use Notes2 as email 2 --KH02
-- 2013-03-21  KHLim     validate email address for Notes2  KH03 
-- 2013-08-22  KHLim     codelkup setup & Unilever change   KH04
-- 2013-12-18  KHLim     sos#298244 extend from 255 to 4000 KH05     
-- 2014-03-20  Kunakorn  attach interface files
-- 2015-03-04  KHLim     335326 Include Email2 for 9415007  KH06
-- 2015-05-05  KHLim     Bug fixes  KH07
-- 2015-06-12  KHLim     335326 Include Email2 for 2157  KH06
-- 2015-11-16  KHLim     353886 Different Header for BDF01  KH08
-- 2016-01-19  KHLim     361166 add param to exclude facility KH09
-- 2016-02-04  KHLim     363092 Add SoldToCode & Company Name KH10
-- 2016-03-14  KHLim     365390 Orders.InvoiceNo for SHELL  KH11
-- 2016-06-10  KHLim     370327 Update ETA SOCFMAIL BDF01   KH12
-- 2017-02-27  KHLim   WMS-636 ID-Receipt & Ship Confirmation Send thru - ATI KH13
-- 2018-07-08  KHLim   https://jira.lfapps.net/browse/WMS-5590 KH14
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
-- ==================================================================
CREATE  PROC  [dbo].[isp_TRANSMITLOG3Alert]
   @cKey3   nvarchar(20)
  ,@cTable  nvarchar(30)
  ,@cTo     NVARCHAR(max)
  ,@cCc     NVARCHAR(max) = ''
  ,@cExcludeFacility NVARCHAR(4000) = '' --KH09
  ,@bDebug bit           = 0
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS OFF   ;   SET ANSI_WARNINGS OFF  ;
            
   DECLARE @cBody       nvarchar(MAX),          
           @cEmail1     NVARCHAR(4000),      
           @cEmail2     NVARCHAR(4000),      
           @cRecip      NVARCHAR(4000),      
           @cRecipCc    NVARCHAR(4000),      
           @cOrderkey   nvarchar(30),      
           @cConsignee  nvarchar(50),
		     @cColumns    nvarchar(4000), --KH05     
           @cCompany    nvarchar(45),      
           @cB_Company  nvarchar(45),   --KH10
           @cBranch     nvarchar(45),    
           @cSubject    nvarchar(255),     
           @cRType      nvarchar(30), 
           @cFilename   nvarchar(30),--Kunakorn 20-Mar-2014
           @cExecScript nvarchar(4000),  
           @dDelivery   datetime
         , @dOrder      datetime  --KH08
         , @dShip       datetime  --KH08
         , @dETA        datetime  --KH08
         , @n_err       int
         , @c_errmsg    NVARCHAR(255)  --KH08
         , @cExecStmt   nvarchar(MAX) 
         , @cExecAgmt   nvarchar(4000)
         , @cSQL        nvarchar(4000) 
         , @cName       nvarchar(250)
         , @cShort      nvarchar(10)   --KH08
         , @cExternPOKey    nvarchar(20)--KH08
         , @cExternOrderKey nvarchar(50)--KH08   --tlting_ext
         , @cFacility   nvarchar(5)    --KH08
         , @cBillToKey  nvarchar(15)   --KH08
         , @cSUSR1      nvarchar(20)   --KH08
         , @cSUSR2      nvarchar(20)   --KH08
         , @cSUSR3      nvarchar(20)   --KH12
         , @cLeadTime   nvarchar(20)   --KH12
         , @cTransMethod nvarchar(30)  --KH08
         , @cInvoiceNo  nvarchar(20)   --KH11
         , @cOutput     nvarchar(MAX)
         , @cUDF        nvarchar(20)   --KH12
         ,@dBegin       DATETIME       --KH13
         ,@b_success    INT            --KH13
         ,@nErrSeverity INT            --KH13
         ,@nErrState    INT            --KH13
         ,@c_AlertKey   char(18)       --KH13
         ,@cUDF01       nvarchar(60)   --KH13

   SELECT @n_err = 0, @c_ErrMsg = '', @b_success = 0, @nErrSeverity = 0 --KH13

   SELECT @cName     = Long
         ,@cShort    = Short --KH08
         ,@cExecStmt = Notes
         ,@cColumns  = Notes2
         ,@cUDF01    = UDF01  --KH13
   FROM  CODELKUP WITH (nolock)
   WHERE LISTNAME    = 'TML3Alert'
   AND   Code        = @cTable
   AND   Storerkey   = @cKey3

   -- Default to NIKE if no CODELKUP record found
   IF @cName IS NULL
   BEGIN
      SET @cName = 'Nike'
   END


   IF @cExecStmt IS NULL
   BEGIN
      SET @cExecStmt = 'SELECT  td = ISNULL(od.Userdefine04,''''), '''',        
            ''td/@align'' = ''left'',        
            td = ISNULL(o.Externpokey,''''), '''',       
            ''td/@align'' = ''left'',        
            td = ISNULL(case when s.busr7=10 then ''AP'' when s.busr7=20 then ''FW'' when s.busr7=30 then ''EQ'' else Null end,''''), '''',        
            ''td/@align'' = ''left'',        
            td =  ISNULL(substring(s.sku,1,6)+''-''+substring(s.sku,7,3),''''), '''',        
            ''td/@align'' = ''left'',      
            td =  ISNULL(substring(s.sku,10,13),''''), '''',        
            ''td/@align'' = ''right'',        
            td =  ISNULL(s.descr,''''), '''',      
            ''td/@align'' = ''right'',       
            td =  ISNULL(CAST(sum(p.qty) AS nvarchar(10)),''''), '''',      
            ''td/@align'' = ''right'',        
            td = ISNULL(CAST(CEILING(case 
               when s.busr7=10 then CONVERT(FLOAT,sum(p.qty))/CONVERT(FLOAT,36)
               when s.busr7=20 then CONVERT(FLOAT,sum(p.qty))/CONVERT(FLOAT,6) 
               when s.busr7=30 then CONVERT(FLOAT,sum(p.qty))/CONVERT(FLOAT,48)
               else Null end) AS nvarchar(99)),''''),'''',      
            ''td/@align'' = ''center'',       
            td = ''-''        
         FROM transmitlog3 AS tf WITH (nolock)
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         JOIN sku          AS s  WITH (nolock) on p.storerkey    = s.storerkey
                                              and p.sku          = s.sku
         WHERE o.storerkey = @cKey3 
         AND   o.orderkey  = @cOrderkey
         AND   p.qty       <> 0      
         GROUP BY od.Userdefine04, o.Externpokey, s.busr7, substring(s.sku,1,6)+''-''+substring(s.sku,7,3), substring(s.sku,10,13), s.descr
         FOR XML PATH(''tr'')           
      '

   END

   SET @cExecStmt = N'SELECT @cOutput=('+@cExecStmt+')'

   IF @bDebug = 1
   BEGIN
      SELECT '@cExecStmt'=@cExecStmt
   END

   IF @cColumns IS NULL
   BEGIN
      SET @cColumns =  '<th>OrderNumber</th>
                        <th>PONumber</th>
                        <th>Division</th>
                        <th>MaterialCode</th>
                        <th>Size</th>
                        <th>MaterialDescr</th>
                        <th>QTY</th>
                        <th>Carton(s)</th>
                        <th>SpecialNotes</th>'  --KH04
   END

   /*********************************************/      
   /* Std - Update Transmitflag to 'IGNOR' (Start)  */
   IF @cExcludeFacility <> '' --KH09
   BEGIN
      SET @cSQL = 
     'UPDATE tf with (ROWLOCK)   SET transmitflag  = ''IGNOR''
         FROM transmitlog3 AS tf 
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
         WHERE tf.key3        = '''+@cKey3   +'''
         AND   tf.tablename   = '''+@cTable  +'''
         AND   tf.transmitflag= ''0''
         AND   o.Facility   IN ('''+REPLACE(@cExcludeFacility,',',''',''')+''') '
      IF @bDebug = 1
      BEGIN
         SELECT '@cSQL'=@cSQL
      END
      EXEC sp_ExecuteSql @cSQL
   END
   IF EXISTS (SELECT TOP 1 1 
         FROM transmitlog3 AS tf 
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         LEFT OUTER JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
         WHERE tf.key3        = @cKey3
         AND   tf.tablename   = @cTable
         AND   tf.transmitflag= '0'
         AND   ISNULL(st.Email1,'') = '' )--KH09
   BEGIN
      IF @bDebug = 1
      BEGIN
         SELECT 'updating IGNOR'
      END
      UPDATE tf with (ROWLOCK)   SET transmitflag  = 'IGNOR'
         FROM transmitlog3 AS tf 
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         LEFT OUTER JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
         WHERE tf.key3        = @cKey3
         AND   tf.tablename   = @cTable
         AND   tf.transmitflag= '0'
         AND   ISNULL(st.Email1,'') = ''
   END
   /* Std - Update Transmitflag to 'IGNOR' (End)    */
   /*********************************************/      


   /*********************************************/      
   /* Std - Update Transmitflag to '1' (Start)  */      
   /*********************************************/      

   BEGIN TRAN       
      
      IF @bDebug = 1
      BEGIN
         SELECT 'updating 1'
      END
      UPDATE tf with (ROWLOCK)   SET transmitflag  = '1'
         FROM transmitlog3 AS tf 
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
         WHERE tf.key3        = @cKey3
         AND   tf.tablename   = @cTable
         AND   tf.transmitflag= '0'
         AND   st.Email1      <> ''

   IF @@error <> 0
   BEGIN
      IF @bDebug = 1
      BEGIN
         SELECT 'updating 5'
      END
      UPDATE tf with (ROWLOCK)   SET transmitflag  = '5'
         FROM transmitlog3 AS tf 
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
         WHERE tf.key3        = @cKey3
         AND   tf.tablename   = @cTable
         AND   tf.transmitflag= '0'
         AND   st.Email1      <> ''
   END
   ELSE
   BEGIN
      COMMIT TRAN
   END
       
   /*********************************************/      
   /* Std - Update Transmitflag to '1' (End)    */      
   /*********************************************/      

      
   DECLARE GEN_Email  CURSOR LOCAL FAST_FORWARD READ_ONLY   FOR      
       
   SELECT RTRIM(tf.key1) key1  
	      ,RTRIM(ISNULL(st.Email1+';'+RTRIM(ISNULL(case when LEFT(o.storerkey,4) ='NIKE' OR o.storerkey = '9415007' OR o.storerkey = '2157' then st.Email2 else '' end,'')),'')) Email1
         --,st.Email2 Email2   
         ,Email2     = st.Notes2 --KH02
         ,CASE WHEN o.StorerKey = 'BDF01' AND ISNULL(o.SalesMan,'')<>'' THEN o.SalesMan ELSE o.ExternPOKey END   --KH08 KH14
         ,o.ExternOrderKey --KH08
         ,o.Facility       --KH08
         ,o.BillToKey      --KH08
         ,o.OrderDate      --KH08
         ,o.EditDate       --KH08
         ,st.SUSR1         --KH08
         ,st.SUSR2         --KH08
         ,st.SUSR3         --KH12
         ,o.InvoiceNo      --KH11
         ,RTRIM(st.company) company
         ,RTRIM(st.address2) address2
         ,RTRIM(o.consigneekey) consigneekey
         ,RTRIM(o.B_Company) --KH10
         ,convert(varchar,case when LEFT(o.storerkey,4)='NIKE' then o.Userdefine06 else o.deliverydate end,106) deliverydate  --' change by Kuankorn 18-July-2012
         ,[Subject]  ='AutoEmail '+CASE 
         WHEN @cUDF01 = 'st.Company+'' <SOCFM> ''+o.Facility+'' ''+o.externorderkey'            --KH13
            THEN  RTRIM(st.company)+ ' Shipping Confirmation '+o.Facility+' '+o.ExternOrderKey  --KH13
         WHEN ISNULL(@cShort,'') = 'ShipHeader'  --KH08
            THEN 'Shipping Alert '+@cName+' of DI # '+o.ExternOrderKey  --KH11
            ELSE 'Picking Alert '+RTRIM(st.company)+' '+RTRIM(st.address2)+' '+@cName+' Delivery Alert '+  
          convert(varchar,case when LEFT(o.storerkey,4)='NIKE' then o.Userdefine06 else o.deliverydate end,106) END     --' change by Kuankorn 18-July-2012
          +CASE WHEN ISNULL(@cShort,'') = 'ShipHeader' THEN ' '+ISNULL(o.C_City,'') ELSE '' END --KH12
         ,[RType]    =case when st.susr1='A' then 'A' else 'D' end -- Change by Kunakorn A = Attach , D=Display
		   ,[Filename] =RTRIM(o.consigneekey)+convert(varchar, getdate(), 112)+'.csv'
   FROM transmitlog3 AS tf WITH (nolock)
   JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
   JOIN orderdetail  AS od WITH (nolock) on o.orderkey    = od.orderkey
   JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                         and od.orderlinenumber = p.orderlinenumber 
   JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
   WHERE tf.key3         = @cKey3
   and   tf.tablename    = @cTable
   and   tf.transmitflag = '1'
   and   st.Email1        <> ''
    
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Error when declare cursor (isp_TRANSMITLOG3Alert).'
   END

   OPEN GEN_Email

   FETCH NEXT FROM GEN_Email INTO @cOrderkey, @cEmail1, @cEmail2,
                                  @cExternPOKey, @cExternOrderKey, @cFacility, @cBillToKey, @dOrder, @dShip, @cSUSR1, @cSUSR2,  --KH08
                                  @cSUSR3, --KH12
                                  @cInvoiceNo,  --KH11
                                  @cCompany, @cBranch, @cConsignee, @cB_Company, --KH10
                                  @dDelivery, @cSubject, @cRType, @cFilename
   WHILE @@FETCH_STATUS = 0          

   BEGIN

      --KH08 start   KH12
      IF ISNULL(@cShort,'') = 'ShipHeader'
      BEGIN
         SET @dETA = @dShip

         SELECT @cTransMethod = TransMethod
         FROM MBOL m WITH (NOLOCK)
         JOIN MBOLDETAIL d WITH (NOLOCK)
         ON m.MbolKey = d.MbolKey
         WHERE OrderKey = @cOrderkey

         IF      @cFacility='CBT01' AND @cTransMethod IN ('S4','FT','L' )
         BEGIN
            SET @cLeadTime =      LEFT(@cSUSR1,2)
         END
         ELSE IF @cFacility='CBT01' AND @cTransMethod IN ('LT','S3') 
         BEGIN
            SET @cLeadTime = SUBSTRING(@cSUSR1,4,2)
         END
         ELSE IF @cFacility='CBT01' AND @cTransMethod IN ('U') 
         BEGIN
            SET @cLeadTime = SUBSTRING(@cSUSR1,7,2)
         END
         ELSE IF @cFacility='CBT01' AND @cTransMethod IN ('U1') 
         BEGIN
            SET @cLeadTime =     RIGHT(@cSUSR1,2)
         END

         ELSE IF @cFacility='SUB01' AND @cTransMethod IN ('S4','FT','L' )
         BEGIN
            SET @cLeadTime =      LEFT(@cSUSR2,2)
         END
         ELSE IF @cFacility='SUB01' AND @cTransMethod IN ('LT','S3') 
         BEGIN
            SET @cLeadTime = SUBSTRING(@cSUSR2,4,2)
         END
         ELSE IF @cFacility='SUB01' AND @cTransMethod IN ('U') 
         BEGIN
            SET @cLeadTime = SUBSTRING(@cSUSR2,7,2)
         END
         ELSE IF @cFacility='SUB01' AND @cTransMethod IN ('U1') 
         BEGIN
            SET @cLeadTime =     RIGHT(@cSUSR2,2)
         END

         ELSE IF @cFacility='MLG01' AND @cTransMethod IN ('S4','FT','L' )
         BEGIN
            SET @cLeadTime =      LEFT(@cSUSR3,2)
         END
         ELSE IF @cFacility='MLG01' AND @cTransMethod IN ('LT','S3') 
         BEGIN
            SET @cLeadTime = SUBSTRING(@cSUSR3,4,2)
         END
         ELSE IF @cFacility='MLG01' AND @cTransMethod IN ('U') 
         BEGIN
            SET @cLeadTime = SUBSTRING(@cSUSR3,7,2)
         END
         ELSE IF @cFacility='MLG01' AND @cTransMethod IN ('U1') 
         BEGIN
            SET @cLeadTime =     RIGHT(@cSUSR3,2)
         END

         ELSE
         BEGIN
            SET @cLeadTime = 0
         END

         IF ISNUMERIC(@cLeadTime)=1
         BEGIN
            SET @dETA = DATEADD(day, CAST(@cLeadTime AS INT), @dETA)
         END

         IF DatePart(dw,@dETA) = 1
         BEGIN
            SET @dETA = DATEADD(day, 1, @dETA)
         END

         IF EXISTS ( SELECT TOP 1 1 FROM HolidayDetail WHERE HolidayDate = CONVERT(CHAR(8),@dETA,112) )
         BEGIN
            SELECT TOP 1 @cUDF = UserDefine01 
                                    FROM HolidayDetail WHERE HolidayDate = CONVERT(CHAR(8),@dETA,112)
            IF ISNUMERIC(@cUDF)<1
            BEGIN
               SET @cUDF = '1'
            END
            SET @dETA = DATEADD(day, CAST(@cUDF AS int), @dETA)
         END
      END
      --KH08 end  KH12

      SET @cBody = ''        
        
      SET @cBody = @cBody + '<style type="text/css">         
         ul    {  font-family: Arial; font-size: 11px; color: #686868;  }        
         p.a1  {  font-family: Arial; font-size: 11px; color: #686868;  }        
         p.a2  {  font-family: Arial; font-size: 11px; color: #686868; font-style:italic  }        
         table {  font-family: Arial;  }        
         th    {  font-size: 13px;font-family: Tahoma;}        
         td    {  font-size: 11px;  }        
         </style>'

      SET @cBody = @cBody + '<p class=a1>Dear Customer,</p>'        
      SET @cBody = @cBody + '<p class=a2>We would like to inform you on the delivery schedule of '+@cName+' products to your Shop/Warehouse,</p>'       
      SET @cBody = @cBody + '<p class=a2>kindly see detail below.</p>'        
        
        
      SET @cBody = @cBody +         
          N'<p class=a1><b>'+@cName+' Delivery Alert Report &nbsp </b>' +        
         N'</p><table border="1" cellspacing="0" cellpadding="1">' +        
            CASE WHEN ISNULL(@cShort,'') = 'ShipHeader' 
            THEN
         N'<tr><th bgcolor=#CAFF70 align=left>' + 
                  CASE WHEN @cKey3 = '68098627' -- SHELL Indonesia
                     THEN                    'Shipment #    </th><th align=right>' + @cInvoiceNo 
                     ELSE                    'PO #          </th><th align=right>' + @cExternPOKey END + '</th></tr>'+      --KH11
         N'<tr><th bgcolor=#CAFF70 align=left>DI #          </th><th align=right>' + @cExternOrderKey + '</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>Shipping Point</th><th align=right>' + @cFacility +'</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>Doc Date      </th><th align=right>' + convert(varchar,@dOrder,106) +'</th></tr>'+
         N'<tr><th bgcolor=#CAFF70 align=left>Dispatch Date </th><th align=right>' + convert(varchar,@dShip,106) +'</th></tr>'+   
         N'<tr><th bgcolor=#CAFF70 align=left>Delivery Date </th><th align=right>' + convert(varchar,@dDelivery,106) +'</th></tr>'+   
         N'<tr><th bgcolor=#CAFF70 align=left>ETA           </th><th align=right>' + convert(varchar,@dETA,106) +'</th></tr>'+   
         N'<tr><th bgcolor=#CAFF70 align=left>Ship To Code  </th><th align=right>' + @cConsignee +'</th></tr>'+
         N'<tr><th bgcolor=#CAFF70 align=left>Company Name  </th><th align=right>' + @cCompany + '</th></tr>'+
         N'<tr><th bgcolor=#CAFF70 align=left>Sold To Code  </th><th align=right>' + @cBillToKey +'</th></tr>'+   --KH10
         N'<tr><th bgcolor=#CAFF70 align=left>Company Name  </th><th align=right>' + @cB_Company + '</th></tr>'    --KH10 
            ELSE
         N'<tr><th bgcolor=#CAFF70 align=left>Delivery Date </th><th align=right>' + convert(varchar,@dDelivery,106) +'</th></tr>'+   
         N'<tr><th bgcolor=#CAFF70 align=left>Customer Name </th><th align=right>' + @cCompany + '</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>Branch        </th><th align=right>' + @cBranch +'</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>ShipTo        </th><th align=right>' + @cConsignee +'</th></tr>'
            END+
         N'<tr bgcolor=#CAFF70 align=center>'+@cColumns+'</tr>'  --KH04


      SET @cExecAgmt    = N'@cKey3     nvarchar(20)
                           ,@cOrderkey nvarchar(30)
                           ,@cOutput   nvarchar(MAX) OUTPUT'
      IF @bDebug = 1
      BEGIN
         SELECT          @cExecStmt
                        ,@cExecAgmt
                        ,@cKey3
                        ,@cOrderkey
                        ,@cOutput
      END

      SET @dBegin = GETDATE()
      BEGIN TRY   --KH11
         EXEC sp_ExecuteSql @cExecStmt
                           ,@cExecAgmt
                           ,@cKey3
                           ,@cOrderkey
                           ,@cOutput OUTPUT
         SELECT @n_err = @@ERROR
      END TRY
      BEGIN CATCH
         SET @c_ErrMsg     = ISNULL(ERROR_MESSAGE(),'');
         SET @nErrSeverity = ISNULL(ERROR_SEVERITY(),0);
         SET @nErrState    = ERROR_STATE();
         RAISERROR ( @c_ErrMsg, @nErrSeverity, @nErrState );
      END CATCH
      IF OBJECT_ID('ALERT','u') IS NOT NULL  --KH11
      BEGIN
         EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
         INSERT ALERT(AlertKey, ModuleName          ,AlertMessage,Severity     ,NotifyId   ,Status,ResolveDate, Resolution  ,Storerkey,Activity,TaskDetailKey,UCCNo    ) 
         VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@c_ErrMsg   ,@nErrSeverity,HOST_NAME(),@n_err,@dBegin    ,@cExecStmt   ,@cKey3   ,@cTable ,@cOrderkey   ,@cExternOrderKey)
      END

      IF @n_err <> 0
      BEGIN
         SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Error executing dynamic SQL (isp_TRANSMITLOG3Alert) - '+@cExecStmt
      END

-- ================================Below script for attached file======================================
	SET @cExecScript ='set nocount on  SELECT  ISNULL(od.Userdefine04,'''')as OrderNumber,       
           ISNULL(o.Externpokey,'''') as PONumber,      
           ISNULL(case when s.busr7=10 then ''AP'' when s.busr7=20 then ''FW'' when s.busr7=30 then ''EQ'' else Null end,'''') as Division,        
           ISNULL(substring(s.sku,1,6)+''-''+substring(s.sku,7,3),'''') as MaterialCode,      
           ISNULL(substring(s.sku,10,13),'''') as Size,
           ISNULL(s.descr,'''') as MaterialDescr, 
           ISNULL(CAST(sum(p.qty) AS nvarchar(10)),'''') as QTY, 
           ISNULL(CAST(CEILING(case   
               when s.busr7=10 then CONVERT(FLOAT,sum(p.qty))/CONVERT(FLOAT,36)  
               when s.busr7=20 then CONVERT(FLOAT,sum(p.qty))/CONVERT(FLOAT,6)   
               when s.busr7=30 then CONVERT(FLOAT,sum(p.qty))/CONVERT(FLOAT,48)  
               else Null end) AS nvarchar(99)),'''') as Cartons
         FROM transmitlog3 AS tf WITH (nolock)
         JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
         JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
         JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                              and od.orderlinenumber = p.orderlinenumber 
         JOIN sku          AS s  WITH (nolock) on p.storerkey    = s.storerkey
                                              and p.sku          = s.sku
         WHERE o.storerkey = '''+@cKey3+''' 
         and   o.orderkey  = '''+@cOrderkey+'''
         and   p.qty       <> 0        
         GROUP BY od.Userdefine04,o.Externpokey,s.busr7,substring(s.sku,1,6)+''-''+substring(s.sku,7,3), substring(s.sku,10,13), s.descr '
--================================End script for attached file==========================

      SET @cBody = @cBody + @cOutput + N'</table>'
              
      SET @cBody = @cBody + '<p class=a1><b>Best Regards,</b><br><b>Delivery Team<b/>'        
      
      IF RTRIM(@cEmail1) <> ''   --KH01
      BEGIN
         SET @cRecip = @cEmail1 + CASE WHEN RIGHT(RTRIM(@cEmail1),1) = ';' THEN '' ELSE ';' END + @cTo
      END
      ELSE
      BEGIN
         SET @cRecip = @cTo
      END

      IF ( RTRIM(@cEmail2) <> ''   --KH01
            AND CHARINDEX(' ',LTRIM(RTRIM(@cEmail2))) = 0     --No embedded spaces
            AND  LEFT(LTRIM(@cEmail2),1) <> '@'    --'@' can't be the first character of an email address
            AND  RIGHT(RTRIM(@cEmail2),1) <> '.'   --'.' can't be the last character of an email address
            AND  CHARINDEX('.',@cEmail2 ,CHARINDEX('@',@cEmail2)) - CHARINDEX('@',@cEmail2 ) > 1   --There must be a '.' somewhere after '@'
            AND  LEN(LTRIM(RTRIM(@cEmail2 ))) - LEN(REPLACE(LTRIM(RTRIM(@cEmail2)),'@','')) >= 1    --at least a '@' sign is found
            AND  CHARINDEX('.',REVERSE(LTRIM(RTRIM(@cEmail2)))) >= 3    --Domain name should end with at least 2 character extension
            AND  (CHARINDEX('.@',@cEmail2 ) = 0 AND CHARINDEX('..',@cEmail2 ) = 0)  --can't have patterns like '.@' and '..'
         )     --KH03
      BEGIN
         SET @cRecipCc = @cEmail2 + CASE WHEN RIGHT(RTRIM(@cEmail2),1) = ';' THEN '' ELSE ';' END + @cCc
      END
      ELSE
      BEGIN
         SET @cRecipCc = @cCc
      END

      IF @n_err = 0
      BEGIN
         IF @cRType <> 'A'
         BEGIN
            --INSERT INTO DTSITF.dbo.DBMailQueue ( mail_type, profile_name, recipients, copy_recipients, subject, body, AddSource, body_format )
            --VALUES ( 'MAIL', 'DBA Profile', @cRecip, @cRecipCc, @cSubject, @cBody, 'isp_TRANSMITLOG3Alert', 'HTML' )
            EXEC msdb.dbo.sp_send_dbmail
               @recipients      = @cRecip,
               @copy_recipients = @cRecipCc,
               @subject         = @cSubject,
               @body            = @cBody,
               @body_format     = 'HTML'
         END
         ELSE
         BEGIN
            --INSERT INTO DTSITF.dbo.DBMailQueue ( mail_type, profile_name, recipients, copy_recipients, subject, body, AddSource, body_format
            --   ,query ,attach_query_result_as_file ,query_attachment_filename ,query_result_separator ,query_result_no_padding ,exclude_query_output)
            --VALUES ( 'MAIL', 'DBA Profile', @cRecip, @cRecipCc, @cSubject, @cBody, 'isp_TRANSMITLOG3Alert', 'HTML' 
            --   ,@cExecScript ,1  ,@cFilename ,',' ,1 ,1)
            EXEC msdb.dbo.sp_send_dbmail
               @recipients      = @cRecip,
               @copy_recipients = @cRecipCc,
               @subject         = @cSubject,
               @body            = @cBody,
               @query           = @cExecScript,
               @attach_query_result_as_file = 1,
               @query_attachment_filename   = @cFilename,
               @query_result_separator      = ',',
               @query_result_no_padding     = 1,
               @exclude_query_output        = 1,
               @body_format     = 'HTML'
         END
         SELECT @n_err = @@ERROR
      END

      /*********************************************/      
      /* Std - Update Transmitflag to '9' (Start)  */      
      /*********************************************/      

      BEGIN TRAN       

      IF @n_err <> 0
      BEGIN
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_TRANSMITLOG3Alert'

         IF @bDebug = 1
         BEGIN
            SELECT 'updating 7'
         END
         UPDATE tf with (ROWLOCK)   SET transmitflag  = '7'
            FROM transmitlog3 AS tf 
            JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
            JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
            JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                                 and od.orderlinenumber = p.orderlinenumber 
            JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
            WHERE tf.key3        = @cKey3
            AND   tf.tablename   = @cTable
            AND   tf.transmitflag= '1'
            AND   st.Email1      <> ''
            AND   tf.key1        = @cOrderkey
      END
      ELSE
      BEGIN
         IF @bDebug = 1
         BEGIN
            SELECT 'updating 9'
         END
         UPDATE tf with (ROWLOCK)   SET transmitflag  = '9'
            FROM transmitlog3 AS tf 
            JOIN orders       AS o  WITH (nolock) on tf.key1        = o.orderkey
            JOIN orderdetail  AS od WITH (nolock) on o.orderkey     = od.orderkey
            JOIN pickdetail   AS p  WITH (nolock) on od.orderkey    = p.orderkey
                                                 and od.orderlinenumber = p.orderlinenumber 
            JOIN storer       AS st WITH (nolock) on o.consigneekey = st.storerkey
            WHERE tf.key3        = @cKey3
            AND   tf.tablename   = @cTable
            AND   tf.transmitflag= '1'
            AND   st.Email1      <> ''
            AND   tf.key1        = @cOrderkey
      END

      COMMIT TRAN

      /*********************************************/      
      /* Std - Update Transmitflag to '9' (End)    */      
      /*********************************************/      

      FETCH NEXT FROM GEN_Email INTO @cOrderkey, @cEmail1, @cEmail2,
                                     @cExternPOKey, @cExternOrderKey, @cFacility, @cBillToKey, @dOrder, @dShip, @cSUSR1, @cSUSR2,  --KH08
                                     @cSUSR3, --KH12
                                     @cInvoiceNo,  --KH11
                                     @cCompany, @cBranch, @cConsignee, @cB_Company, --KH10
                                     @dDelivery, @cSubject, @cRType, @cFilename
   END

   CLOSE GEN_Email
   DEALLOCATE GEN_Email


END /* main procedure */


GO