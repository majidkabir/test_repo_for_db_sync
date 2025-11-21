SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*-------------------------------------------------------------------------------------------------------*/
/* Stored Procedure: isp_Transmit_Mail_ASN                                                               */
/* Creation Date: 27-October-2015                                                                        */
/* Copyright: LF LOGISTICS                                                                               */
/* Written by: JayLim                                                                                    */
/*                                                                                                       */
/* Purpose: Transmit ASN Email                                                                           */
/* Called By: ALT - BDF SOCFM & RCPT Email , SHELL, ATI etc                         		               */
/*                                                                                                       */
/* Updates:                                                                                              */
/* Date         Author    Ver. Purposes                                                                  */
/* 24-Nov-2015  JayLim    -Remodify receiptdetail logic   (Jay01)                                        */
/* 02-Dec-2015  JayLim    -added ISNULL to ReceiptDetail.lottable04  (Jay02)                             */
/* 04-Dec-2015  JayLim    -modify to have default name from CODELKUP (Jay03)                             */
/* 06-Dec-2015  KHLim     sos ticket #353886                                                             */
/* 15-Dec-2015  JayLim    new header: Shipping Point, Vendor Name & Total detail count                   */
/* 19-Jan-2015  KHLim     361166 add param to exclude facility (KHLim09)                                 */
/* 09-Jun-2016  JayLim    sos ticket #370327  (Jay04)                                                    */
/* 01-Sep-2016  KHLim     Ref:TA:00122357 Display more debuging info (KHLim10)                           */
/* 06-Dec-2016  KHLim     WMS-636 ID-Receipt & Ship Confirmation Send thru Email Notification - ATI(KH11)*/
/* 27-Feb-2017  KHLim     WMS-636 ID-Receipt & Ship Confirmation Send thru                    - ATI(KH13)*/
/* 21-Dec-2020  LZG       INC1383108 - DISTINCT record to fix email duplication (ZG01)                   */
/*-------------------------------------------------------------------------------------------------------*/

CREATE PROCEDURE [dbo].[isp_Transmit_Mail_ASN] (
    @cKey3   nvarchar(20)      -- StorerKey
   ,@cTable  nvarchar(30)      -- RCPTMAIL
   ,@cTo     nvarchar(max)     -- To recipient list
   ,@cCc     nvarchar(max) = '' -- Cc recipient list
   ,@cExcludeFacility NVARCHAR(4000) = '' -- MLG01  KHLim09 (comma delimited)
   ,@bDebug bit           = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE ----------------------------------declaration of variables
      @cKey1               nvarchar(10),   -- TransmitLog.Key1 or RECEIPT.ReceiptKey
      @cBody               nvarchar(max),  -- gather all content for email's body
      @cEmail1             nvarchar(60),   -- get storer's email1
      @cEmail2             nvarchar(60),   -- get storer's email2
      @cRecip              varchar(1024),  -- recipient email To
      @cRecipCc            varchar(1024),  -- recipient email Cc
      @cSubject            nvarchar(255),  -- email subject
      @cName               nvarchar(250),  -- Customer Name          = CODELKUP.Long
      @cShort              nvarchar(10),   -- Email Title Type       = CODELKUP.Short
      @cExecStmt           nvarchar(max),  -- statement for exec     = CODELKUP.Notes
      @cSQL                nvarchar(4000),   --KHLim09
      @cColumns            nvarchar(4000), -- Detail table's columns = CODELKUP.Notes2
      @cExecAgmt           nvarchar(4000), -- argurment for exec
      @cFacility           nvarchar(30),   -- get facility code from FACILITY table
      @cBranch             nvarchar(45),   -- get city value based on facility
      @cReceiveDate        nvarchar(20),   -- get 1st table's row1/ReceivedDate value
      @cExternReceiptKey   nvarchar(20),   -- get 1st table's row2/ExternReceiptKey value
      @cReceiptGroup       nvarchar(40),   -- get 1st table's row3/ReceiptGroup value
      @cRecType            nvarchar(10),   -- get 1st table's row5/RecType value
      @cCarrierKey         nvarchar(15),   -- get 1st table's row6/CarrierType value
      @cCarrierName        nvarchar(60),   -- get 1st table's row7/CarrierName value
      @n_err               int,            -- error flag
      @c_ErrMsg            nvarchar(255),  -- error message
      @cOutput             nvarchar(max),  -- 2nd table output
      @cTotalOutput        nvarchar(max)   -- total output
     ,@dBegin              DATETIME        -- KH11
     ,@b_success           INT             -- KH11
     ,@nErrSeverity        INT             -- KH11
     ,@nErrState           INT             -- KH11
     ,@c_AlertKey          char(18)        -- KH11
     ,@cContainerKey       nvarchar(18)    -- KH11
     ,@cUDF01              nvarchar(60)    --KH13
     ,@cCompany            nvarchar(45)    --KH13

   SELECT @n_err = 0, @c_ErrMsg = '', @b_success = 0, @nErrSeverity = 0

   SET NOCOUNT ON

   /*********************************************/      
   /* Std - Update Transmitflag to 'IGNOR' (Start)  */
   IF @cExcludeFacility <> '' --KHLim09
   BEGIN
      SET @cSQL = 
     'UPDATE transmitlog3 with (ROWLOCK)   SET transmitflag  = ''IGNOR''
         FROM transmitlog3    AS tf 
         JOIN Receipt         AS r  WITH (nolock) on tf.key1         = r.ReceiptKey
         JOIN Receiptdetail   AS rd WITH (nolock) on r.Receiptkey    = rd.ReceiptKey
         JOIN storer          AS st WITH (nolock) on r.StorerKey     = st.StorerKey
         WHERE tf.key3        = '''+@cKey3   +'''
         AND   tf.tablename   = '''+@cTable  +'''
         AND   tf.transmitflag= ''0''
         AND   r.Facility   IN ('''+REPLACE(@cExcludeFacility,',',''',''')+''') '
      IF @bDebug = 1
      BEGIN
         SELECT '@cSQL'=@cSQL
      END
      EXEC sp_ExecuteSql @cSQL
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
      UPDATE transmitlog3 with (ROWLOCK)   SET transmitflag  = '1'
         FROM transmitlog3    AS tf 
         JOIN Receipt         AS r  WITH (nolock) on tf.key1         = r.ReceiptKey
         JOIN Receiptdetail   AS rd WITH (nolock) on r.Receiptkey    = rd.ReceiptKey
         JOIN storer          AS st WITH (nolock) on r.StorerKey     = st.StorerKey
         WHERE tf.key3        = @cKey3 
         AND   tf.tablename   = @cTable
         AND   tf.transmitflag= '0'
   IF @@error <> 0
   BEGIN
      IF @bDebug = 1
      BEGIN
         SELECT 'updating 5'
      END
      UPDATE transmitlog3 with (ROWLOCK)   SET transmitflag  = '5'
         FROM transmitlog3    AS tf 
         JOIN Receipt         AS r  WITH (nolock) on tf.key1         = r.ReceiptKey
         JOIN Receiptdetail   AS rd WITH (nolock) on r.Receiptkey    = rd.ReceiptKey
         JOIN storer          AS st WITH (nolock) on r.StorerKey     = st.StorerKey
         WHERE tf.key3        = @cKey3 
         AND   tf.tablename   = @cTable
         AND   tf.transmitflag= '0'
   END
   ELSE
   BEGIN
      COMMIT TRAN
   END  
   /*********************************************/      
   /* Std - Update Transmitflag to '1' (End)    */      
   /*********************************************/      
      
   DECLARE GEN_Email  CURSOR LOCAL FAST_FORWARD READ_ONLY   FOR      
       
   SELECT DISTINCT RTRIM(tf.key1) key1, ISNULL(r.Facility,''), r.ExternReceiptKey, -- ZG01
      ISNULL(r.rectype,''),  ISNULL(r.CarrierKey,''), ISNULL(r.CarrierName,''), ISNULL(CONVERT(VARCHAR, r.ReceiptDate, 106),''), 
      st.Email1, st.Email2, ISNULL(r.ReceiptGroup,'')
      ,ISNULL(r.ContainerKey,'') --KH11
      ,ISNULL(st.Company    ,'') --KH13
   FROM transmitlog3    AS tf WITH (nolock)
   JOIN Receipt         AS r  WITH (nolock) on tf.key1         = r.receiptkey
   JOIN Receiptdetail   AS rd WITH (nolock) on r.receiptkey    = rd.receiptkey
   JOIN storer          AS st WITH (nolock) on r.storerkey     = st.storerkey
   WHERE tf.key3         = @cKey3 
   and   tf.tablename    = @cTable
   and   tf.transmitflag = '1'
   
   SELECT @n_err = @@ERROR
   IF @n_err <> 0    --KHLim10
   BEGIN
      SET @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Error executing SQL for GEN_Email ('+OBJECT_NAME(@@PROCID)+')'
   END

   OPEN GEN_Email

   FETCH NEXT FROM GEN_Email INTO @cKey1, @cFacility, @cExternReceiptKey,
                             @cRecType, @cCarrierKey, @cCarrierName, @cReceiveDate,
                             @cEmail1, @cEmail2, @cReceiptGroup
                            ,@cContainerKey --KH11
                            ,@cCompany      --KH13
   WHILE @@FETCH_STATUS = 0       
   BEGIN
      /*---------------------------(Append @cBranch value)[start]------------------------*/
      IF @cFacility <>''
      BEGIN
         SELECT @cBranch = ISNULL(Short,'')
         FROM CODELKUP WITH (NOLOCK)
         WHERE LISTNAME ='TMLBranch '
         AND Code = @cFacility  --(Jay04)
      END

      IF @cBranch = ''
      BEGIN
         SET @cBranch = ISNULL(@cFacility,'') --(Jay04)
      END
      /*---------------------------(Append @cBranch value)[end]--------------------------*/

      SELECT @cName     = Long,
             @cShort    = Short,
             @cExecStmt = notes,
             @cColumns  = notes2
            ,@cUDF01    = UDF01  --KH13
      FROM  CODELKUP WITH (nolock)
      WHERE LISTNAME    = 'TMLMailASN'
      AND   Code        = @cTable
      AND   Storerkey   = @cKey3

      SET @cExecStmt = N'SELECT @cOutput=('+@cExecStmt+')'


      /*-------------------------------------(Email Body Layout (start))-------------------------------------*/
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
      SET @cBody = @cBody + '<p class=a2>We would like to inform you that we have received '+@cName+' products in warehouse,</p>'       
      SET @cBody = @cBody + '<p class=a2>kindly see detail below.</p>'        
      
      SET @cBody = @cBody +         
         N'<p class=a1><b>'+@cName+' Receiving Alert Report &nbsp </b>' +        
         N'</p><table border="1" cellspacing="0" cellpadding="1">' +        
            --CASE WHEN ISNULL(@cShort,'') = 'ShipHeader' 
            --THEN
         N'<tr><th bgcolor=#CAFF70 align=left>Received Date  </th><th align=right>' + @cReceiveDate + '</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>Delivery Number</th><th align=right>' + @cExternReceiptKey + '</th></tr>'+
         N'<tr><th bgcolor=#CAFF70 align=left>Shipping Point </th><th align=right>' + @cReceiptGroup + '</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>Branch         </th><th align=right>' + @cBranch +'</th></tr>' + --(Jay04)
         N'<tr><th bgcolor=#CAFF70 align=left>Document Type  </th><th align=right>' + @cRecType +'</th></tr>'+      
         N'<tr><th bgcolor=#CAFF70 align=left>Vendor Code    </th><th align=right>' + @cCarrierKey +'</th></tr>'+
         N'<tr><th bgcolor=#CAFF70 align=left>Vendor Name    </th><th align=right>' + @cCarrierName +'</th></tr>'+   
         N'<tr><th bgcolor=#CAFF70 align=left>Truck Ref#     </th><th align=right>' + @cContainerKey +'</th></tr>'+ --KH11
--            END+
         N'<tr bgcolor=#CAFF70 align=center>'+@cColumns+'</tr>'

      SET @cExecAgmt    = N'@cKey3     nvarchar(20)
                           ,@cKey1     nvarchar(30)
                           ,@cOutput   nvarchar(MAX) OUTPUT'
      SET @dBegin = GETDATE()
      BEGIN TRY   --KH11
         EXEC sp_ExecuteSql @cExecStmt
                           ,@cExecAgmt
                           ,@cKey3
                           ,@cKey1
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
         VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@c_ErrMsg   ,@nErrSeverity,HOST_NAME(),@n_err,@dBegin    ,@cExecStmt   ,@cKey3   ,@cTable ,@cKey1       ,@cExternReceiptKey)
      END
      IF @bDebug = 1 --KHLim10
      BEGIN
         SELECT '@cExecStmt'=@cExecStmt, '@cExecAgmt'=@cExecAgmt, '@cKey3'=@cKey3, '@cKey1'=@cKey1, '@cOutput'=@cOutput
      END
      IF @n_err <> 0
      BEGIN
         SET @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Error executing dynamic SQL ('+OBJECT_NAME(@@PROCID)+')'
      END

      /*-------------------------------------(Total output (start))-------------------------------------*/
      SET @cTotalOutput = ''
      IF ISNULL(@cShort,'') = 'RCPT_Total'
      BEGIN 
         DECLARE @nDec INT
         SET @nDec = 0
         IF CHARINDEX('DECIMAL(13,3)',@cExecStmt) > 0
            SET @nDec= 1

         SET @cTotalOutput = 'SELECT td = ''TOTAL'','''',
   td = '''','''',
   td = '''','''',
   td = rd.uom,'''',
   td = ISNULL(CONVERT(varchar(20),NULLIF(SUM(CONVERT('+CASE @nDec WHEN 1 THEN 'DECIMAL(13,3)' ELSE 'INT' END+',CASE
               when rd.uom = p.packuom1 then rd.QtyExpected/NULLIF(p.CASECNT,0)
               when rd.uom = p.packuom3 then rd.QtyExpected/NULLIF(p.qty,0)
               when rd.uom = p.packuom4 then rd.QtyExpected/NULLIF(p.pallet,0)
               end)),0'+CASE @nDec WHEN 1 THEN '.000' END+')),''''),'''',
   td = ISNULL(CONVERT(varchar(20),ISNULL(SUM(CONVERT('+CASE @nDec WHEN 1 THEN 'DECIMAL(13,3)' ELSE 'INT' END+',CASE 
               when rd.uom = p.packuom1 then rd.QtyReceived/NULLIF(p.CASECNT,0)
               when rd.uom = p.packuom3 then rd.QtyReceived/NULLIF(p.qty,0)
               when rd.uom = p.packuom4 then rd.QtyReceived/NULLIF(p.pallet,0)
               end)),0'+CASE @nDec WHEN 1 THEN '.000' END+')-ISNULL(SUM(CONVERT('+CASE @nDec WHEN 1 THEN 'DECIMAL(13,3)' ELSE 'INT' END+',dm.QtyDamaged)),0.000)),''''),'''',
   td = CONVERT(varchar(20),ISNULL(SUM(CONVERT('+CASE @nDec WHEN 1 THEN 'DECIMAL(13,3)' ELSE 'INT' END+',dm.QtyDamaged)),0.000)),'''',
   td = ISNULL(CONVERT(varchar(20),NULLIF(SUM(CONVERT('+CASE @nDec WHEN 1 THEN 'DECIMAL(13,3)' ELSE 'INT' END+',CASE 
               when rd.uom = p.packuom1 then rd.QtyReceived/NULLIF(p.CASECNT,0)
               when rd.uom = p.packuom3 then rd.QtyReceived/NULLIF(p.qty,0)
               when rd.uom = p.packuom4 then rd.QtyReceived/NULLIF(p.pallet,0)
               end)),0'+CASE @nDec WHEN 1 THEN '.000' END+')),''''),'''',
   td = '''','''','+CASE @nDec WHEN 1 THEN '
   td = '''','''',
   td = '''','''',' END+'
   td = '''',''''
FROM ReceiptDetail rd with (nolock)
JOIN SKU s with (nolock) ON s.StorerKey = rd.StorerKey AND s.Sku = rd.Sku
JOIN PACK p with (nolock) ON p.PackKey = s.PackKey AND rd.packkey=p.packkey
LEFT OUTER JOIN (
   SELECT ReceiptKey
      ,ReceiptLineNumber
      ,QtyDamaged   = CASE 
            when rd.uom = p.packuom1 then rd.QtyReceived/NULLIF(p.CASECNT,0)
            when rd.uom = p.packuom3 then rd.QtyReceived/NULLIF(p.qty,0)
            when rd.uom = p.packuom4 then rd.QtyReceived/NULLIF(p.pallet,0)
            end
   FROM ReceiptDetail rd with (nolock)
   JOIN SKU s with (nolock) ON s.StorerKey = rd.StorerKey AND s.Sku = rd.Sku
   JOIN PACK p with (nolock) ON p.PackKey = s.PackKey AND rd.packkey=p.packkey
   JOIN loc lo with (nolock) ON rd.toloc=lo.loc
   WHERE rd.StorerKey   = @cKey3
   AND lo.hostwhcode = ''damage'') dm ON rd.ReceiptKey  = dm.ReceiptKey
   AND rd.ReceiptLineNumber  = dm.ReceiptLineNumber
WHERE rd.receiptkey  = @cKey1
AND  NOT( rd.QtyReceived = 0 AND rd.QtyExpected = 0 )   
AND   rd.StorerKey   = @cKey3
GROUP BY rd.uom
For XML PATH(''tr'')'

         SET @cTotalOutput = N'SELECT @cTotalOutput=('+@cTotalOutput+')'
 
         SET @cExecAgmt    = N'@cKey3     nvarchar(20)
                              ,@cKey1     nvarchar(30)
                              ,@cTotalOutput   nvarchar(MAX) OUTPUT'

         IF @bDebug = 1
         BEGIN
            SELECT        @cTotalOutput
                         ,@cExecAgmt
                         ,@cKey3
                         ,@cKey1
                         ,@cTotalOutput
         END
         SET @dBegin = GETDATE()
         BEGIN TRY   --KH11
            EXEC sp_ExecuteSql @cTotalOutput
                            ,@cExecAgmt
                            ,@cKey3
                            ,@cKey1
                            ,@cTotalOutput OUTPUT
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
            VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@c_ErrMsg   ,@nErrSeverity,HOST_NAME(),@n_err,@dBegin    ,@cTotalOutput,@cKey3   ,@cTable ,@cKey1       ,@cExternReceiptKey)
         END
         IF @n_err <> 0
         BEGIN
            SET @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Error executing dynamic SQL for RCPT_Total ('+OBJECT_NAME(@@PROCID)+')'
         END
      END

      /*-------------------------------------(Total output (end))-------------------------------------*/

      SET @cBody = @cBody + @cOutput + @cTotalOutput +N'</table>'

      SET @cBody = @cBody + '<p class=a1><b>Best Regards,</b><br><b>Receiving Team<b/>'        

      IF @cUDF01     = 'st.Company+'' <RCPTCFM> ''+r.Facility+'' ''+r.externReceiptkey'                        --KH13
      BEGIN
         SET @cSubject = 'AutoEmail '+@cCompany + ' Receipt Confirmation '+@cFacility+' '+@cExternReceiptKey   --KH13
      END
      ELSE
      BEGIN
         SET @cSubject = 'AutoEmail Receipt Confirmation '+ @cExternReceiptKey ---------- Set Email Subject
      END

      /*-------------------------------------(Email Body Layout (end))-------------------------------------*/

      IF RTRIM(@cEmail1) <> ''   
      BEGIN
         SET @cRecip = @cEmail1 + CASE WHEN RIGHT(RTRIM(@cEmail1),1) = ';' THEN '' ELSE ';' END + @cTo
      END
      ELSE
      BEGIN
         SET @cRecip = @cTo
      END

      IF ( RTRIM(@cEmail2) <> ''   
            AND CHARINDEX(' ',LTRIM(RTRIM(@cEmail2))) = 0                                          --No embedded spaces
            AND  LEFT(LTRIM(@cEmail2),1) <> '@'                                                    --'@' can't be the first character of an email address
            AND  RIGHT(RTRIM(@cEmail2),1) <> '.'                                                   --'.' can't be the last character of an email address
            AND  CHARINDEX('.',@cEmail2 ,CHARINDEX('@',@cEmail2)) - CHARINDEX('@',@cEmail2 ) > 1   --There must be a '.' somewhere after '@'
            AND  LEN(LTRIM(RTRIM(@cEmail2 ))) - LEN(REPLACE(LTRIM(RTRIM(@cEmail2)),'@','')) >= 1   --at least a '@' sign is found
            AND  CHARINDEX('.',REVERSE(LTRIM(RTRIM(@cEmail2)))) >= 3                               --Domain name should end with at least 2 character extension
            AND  (CHARINDEX('.@',@cEmail2 ) = 0 AND CHARINDEX('..',@cEmail2 ) = 0)                 --can't have patterns like '.@' and '..'
         )     
      BEGIN
         SET @cRecipCc = @cEmail2 + CASE WHEN RIGHT(RTRIM(@cEmail2),1) = ';' THEN '' ELSE ';' END + @cCc
      END
      ELSE
      BEGIN
         SET @cRecipCc = @cCc
      END

      IF @n_err = 0
      BEGIN
         --(Jay04)
         EXEC msdb.dbo.sp_send_dbmail
               @recipients      = @cRecip,
               @copy_recipients = @cRecipCc,
               @subject         = @cSubject,
               @body            = @cBody,
               @body_format     = 'HTML'

         SELECT @n_err = @@ERROR
      END         


      /*********************************************/      
      /* Std - Update Transmitflag to '9' (Start)  */      
      /*********************************************/      
      BEGIN TRAN       
      IF @n_err <> 0
      BEGIN
         IF @bDebug = 1
         BEGIN
            SELECT 'updating 7'
         END
         UPDATE tf with (ROWLOCK)   SET transmitflag  = '7'
            FROM transmitlog3 AS tf 
            JOIN Receipt         AS r  WITH (nolock) on tf.key1         = r.ReceiptKey
            JOIN Receiptdetail   AS rd WITH (nolock) on r.Receiptkey    = rd.ReceiptKey
            JOIN storer          AS st WITH (nolock) on r.StorerKey     = st.StorerKey
            WHERE tf.tablename   = @cTable
            AND   tf.transmitflag= '1'
            AND   tf.key1        = @cKey1
            AND   tf.key3        = @cKey3
      END
      ELSE
      BEGIN
         IF @bDebug = 1
         BEGIN
            SELECT 'updating 9'
         END
         UPDATE tf with (ROWLOCK)   SET transmitflag  = '9'
            FROM transmitlog3 AS tf 
            JOIN Receipt         AS r  WITH (nolock) on tf.key1         = r.ReceiptKey
            JOIN Receiptdetail   AS rd WITH (nolock) on r.Receiptkey    = rd.ReceiptKey
            JOIN storer          AS st WITH (nolock) on r.StorerKey     = st.StorerKey
            WHERE tf.tablename   = @cTable
            AND   tf.transmitflag= '1'
            AND   tf.key1        = @cKey1
            AND   tf.key3        = @cKey3
      END
      COMMIT TRAN
      /*********************************************/      
      /* Std - Update Transmitflag to '9' (End)    */      
      /*********************************************/ 

      FETCH NEXT FROM GEN_Email INTO @cKey1, @cFacility, @cExternReceiptKey,
                             @cRecType, @cCarrierKey, @cCarrierName, @cReceiveDate,
                             @cEmail1, @cEmail2, @cReceiptGroup
                            ,@cContainerKey --KH11
                            ,@cCompany      --KH13
   END
   CLOSE GEN_Email
   DEALLOCATE GEN_Email   
END

GO