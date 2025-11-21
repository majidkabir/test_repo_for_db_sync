SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**********************************************************************************************/    
/* Stored Procedure: isp_MailQBuildCalcGrandTotal                                             */    
/* Creation Date: 2019-04-15                                                                  */    
/* Copyright: IDS                                                                             */    
/* Written by: kelvinongcy																				          */    
/*                                                                                            */    
/* Purpose: Generate Grand Total for Delivery Automail Email Alert Report                     */
/*                                                                                            */    
/* Called By:  dbo.isp_Transmit_MailStdGroup                                                  */    
/*                                                                                            */    
/* PVCS Version:                                                                              */    
/*                                                                                            */    
/* Version:                                                                                   */    
/*                                                                                            */    
/* Data Modifications:                                                                        */    
/*                                                                                            */    
/* Updates:                                                                                   */    
/* Date         Author  ver  Purposes                                                         */       
/* 2019-04-15   kocy    1.1 Count sum for Carton(s) https://jira.lfapps.net/browse/WMS-8555   */    
/**********************************************************************************************/    
CREATE PROC  [dbo].[isp_MailQBuildCalcGrandTotal]        
   @Qid   int         
  ,@Debug   bit   = 0        
AS        
BEGIN        
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;        
   SET ANSI_NULLS OFF   ;   SET ANSI_WARNINGS OFF  ;        
        
   DECLARE  @MailQDetXML NVARCHAR(MAX), @Body NVARCHAR(MAX), @SQL NVARCHAR(MAX)  , @SQLAgg NVARCHAR(MAX) ,  @MailQDetAggXML NVARCHAR(MAX)    
   ,@sysMail_id INT        
   ,@SendTo      varchar(4000)         
   ,@Cc          varchar(4000)         
   ,@Bcc         varchar(4000)         
   ,@Subject     nvarchar(255)         
   ,@Header      nvarchar(2000)        
   ,@Footer      nvarchar(2000)        
   ,@THColor     char(6)        
   ,@R01Name     nvarchar(128)         
   ,@R01         nvarchar(1000)        
   ,@R02Name     nvarchar(128)         
   ,@R02         nvarchar(1000)        
   ,@R03Name     nvarchar(128)         
   ,@R03         nvarchar(1000)        
   ,@R04Name     nvarchar(128)         
   ,@R04         nvarchar(1000)        
   ,@R05Name     nvarchar(128)         
   ,@R05         nvarchar(1000)        
   ,@R06Name     nvarchar(128)         
   ,@R06         nvarchar(1000)        
   ,@R07Name     nvarchar(128)         
   ,@R07         nvarchar(1000)        
   ,@R08Name     nvarchar(128)         
   ,@R08         nvarchar(1000)        
   ,@R09Name     nvarchar(128)         
   ,@R09         nvarchar(1000)        
   ,@R10Name     nvarchar(128)         
   ,@R10         nvarchar(1000)        
   ,@R11Name     nvarchar(128)         
   ,@R11         nvarchar(1000)        
   ,@R12Name     nvarchar(128)         
   ,@R12         nvarchar(1000)        
   ,@R13Name     nvarchar(128)         
   ,@R13         nvarchar(1000)        
   ,@R14Name     nvarchar(128)   
   ,@R14         nvarchar(1000)        
   ,@R15Name     nvarchar(128)         
   ,@R15         nvarchar(1000)        
   ,@C01Align    char(1)          
   ,@C01Name     nvarchar(128)        
   ,@C02Align    char(1)              
   ,@C02Name     nvarchar(128)        
   ,@C03Align    char(1)              
   ,@C03Name     nvarchar(128)        
   ,@C04Align    char(1)              
   ,@C04Name     nvarchar(128)        
   ,@C05Align    char(1)              
   ,@C05Name     nvarchar(128)        
   ,@C06Align    char(1)              
   ,@C06Name     nvarchar(128)        
   ,@C07Align    char(1)              
   ,@C07Name     nvarchar(128)        
   ,@C08Align    char(1)              
   ,@C08Name     nvarchar(128)        
   ,@C09Align    char(1)              
   ,@C09Name     nvarchar(128)        
   ,@C10Align    char(1)              
   ,@C10Name     nvarchar(128)        
   ,@C11Align    char(1)              
   ,@C11Name     nvarchar(128)        
   ,@C12Align    char(1)              
   ,@C12Name     nvarchar(128)        
   ,@C13Align    char(1)              
   ,@C13Name     nvarchar(128)        
   ,@C14Align    char(1)              
   ,@C14Name     nvarchar(128)        
   ,@C15Align    char(1)              
   ,@C15Name     nvarchar(128)        
   ,@ColSpan     varchar(3)        
   ,@C01Agg      nvarchar (25)         --kocy01             
   ,@C02Agg      nvarchar (25)             
   ,@C03Agg      nvarchar (25)             
   ,@C04Agg      nvarchar (25)             
   ,@C05Agg      nvarchar (25)             
   ,@C06Agg      nvarchar (25)             
   ,@C07Agg      nvarchar (25)             
   ,@C08Agg      nvarchar (25)             
   ,@C09Agg      nvarchar (25)             
   ,@C10Agg      nvarchar (25)             
   ,@C11Agg      nvarchar (25)             
   ,@C12Agg      nvarchar (25)             
   ,@C13Agg      nvarchar (25)             
   ,@C14Agg      nvarchar (25)             
   ,@C15Agg      nvarchar (25)             
   ,@TotalCol    INT                       
   ,@C01AggLabel nvarchar (25)  = ''       
   ,@C02AggLabel nvarchar (25)  = ''       
   ,@C03AggLabel nvarchar (25)  = ''       
   ,@C04AggLabel nvarchar (25)  = ''       
   ,@C05AggLabel nvarchar (25)  = ''       
   ,@C06AggLabel nvarchar (25)  = ''       
   ,@C07AggLabel nvarchar (25)  = ''       
   ,@C08AggLabel nvarchar (25)  = ''       
   ,@C09AggLabel nvarchar (25)  = ''       
   ,@C10AggLabel nvarchar (25)  = ''       
   ,@C11AggLabel nvarchar (25)  = ''       
   ,@C12AggLabel nvarchar (25)  = ''       
   ,@C13AggLabel nvarchar (25)  = ''       
   ,@C14AggLabel nvarchar (25)  = ''       
   ,@C15AggLabel nvarchar (25)  = ''       
     
     
                                
   SELECT         
    @SendTo =SendTo         
   ,@Cc     =Cc             
   ,@Bcc    =Bcc            
   ,@Subject=[Subject]        
   ,@Header =Header         
   ,@Footer =Footer         
   ,@THColor=THColor        
   ,@R01Name=R01Name        
   ,@R01    =R01            
   ,@R02Name=R02Name        
   ,@R02    =R02            
   ,@R03Name=R03Name        
   ,@R03    =R03            
   ,@R04Name=R04Name        
   ,@R04    =R04            
   ,@R05Name=R05Name        
   ,@R05    =R05            
   ,@R06Name=R06Name        
   ,@R06    =R06            
   ,@R07Name=R07Name        
   ,@R07    =R07            
   ,@R08Name=R08Name        
   ,@R08    =R08            
   ,@R09Name=R09Name        
   ,@R09    =R09            
   ,@R10Name=R10Name        
   ,@R10    =R10            
   ,@R11Name=R11Name        
   ,@R11    =R11            
   ,@R12Name=R12Name        
   ,@R12    =R12            
   ,@R13Name=R13Name        
   ,@R13    =R13            
   ,@R14Name=R14Name        
   ,@R14    =R14            
   ,@R15Name=R15Name        
   ,@R15    =R15            
   ,@C01Align=C01Align        
   ,@C01Name =C01Name         
   ,@C02Align=C02Align        
   ,@C02Name =C02Name         
   ,@C03Align=C03Align        
   ,@C03Name =C03Name         
   ,@C04Align=C04Align        
   ,@C04Name =C04Name         
   ,@C05Align=C05Align        
   ,@C05Name =C05Name         
   ,@C06Align=C06Align        
   ,@C06Name =C06Name         
   ,@C07Align=C07Align        
   ,@C07Name =C07Name         
   ,@C08Align=C08Align        
   ,@C08Name =C08Name         
   ,@C09Align=C09Align        
   ,@C09Name =C09Name         
   ,@C10Align=C10Align        
   ,@C10Name =C10Name         
   ,@C11Align=C11Align        
   ,@C11Name =C11Name         
   ,@C12Align=C12Align        
   ,@C12Name =C12Name         
   ,@C13Align=C13Align        
   ,@C13Name =C13Name         
   ,@C14Align=C14Align        
   ,@C14Name =C14Name         
   ,@C15Align=C15Align        
   ,@C15Name =C15Name        
   ,@C01Agg  = C01Agg   --kocy01     
   ,@C02Agg  = C02Agg       
   ,@C03Agg  = C03Agg       
   ,@C04Agg  = C04Agg       
   ,@C05Agg  = C05Agg       
   ,@C06Agg  = C06Agg       
   ,@C07Agg  = C07Agg       
   ,@C08Agg  = C08Agg       
   ,@C09Agg  = C09Agg       
   ,@C10Agg  = C10Agg       
   ,@C11Agg  = C11Agg       
   ,@C12Agg  = C12Agg       
   ,@C13Agg  = C13Agg       
   ,@C14Agg  = C14Agg       
   ,@C15Agg  = C15Agg       
    FROM dbo.MailQ WITH (NOLOCK)         
    WHERE Qid = @Qid AND mailitem_id = 0        
   
   
   SELECT @@ROWCOUNT 'No.rowcount in isp_MailQBuild'      
   IF @@ROWCOUNT>0        
   BEGIN        
      SET @Body = N'<style type="text/css">         
         p.a1  { font-family: Arial; font-size: 12px; }        
         table { font-family: Arial; border:1px; border-collapse:collapse; }        
         th    { font-size: 12px; font-family: Arial; }             
         .n    { text-align: left; background-color: #'+@thColor+';  }        
         .v    { text-align: left;  }        
         td    { font-size: 11px; }        
         .L    { text-align: left; }        
         .C    { text-align: centre; }        
         .R    { text-align: right; }        
         </style>'        
        
   IF      @C02Name=''  SET @ColSpan= '0'        
   ELSE IF @C03Name=''  SET @ColSpan= '1'        
   ELSE IF @C04Name=''  SET @ColSpan= '2'        
   ELSE IF @C05Name=''  SET @ColSpan= '3'        
   ELSE IF @C06Name=''  SET @ColSpan= '4'        
   ELSE IF @C07Name=''  SET @ColSpan= '5'        
   ELSE IF @C08Name=''  SET @ColSpan= '6'        
   ELSE IF @C09Name=''  SET @ColSpan= '7'        
   ELSE IF @C10Name=''  SET @ColSpan= '8'        
   ELSE IF @C11Name=''  SET @ColSpan= '9'        
   ELSE IF @C12Name=''  SET @ColSpan='10'        
   ELSE IF @C13Name=''  SET @ColSpan='11'        
   ELSE IF @C14Name=''  SET @ColSpan='12'        
   ELSE IF @C15Name=''  SET @ColSpan='13'    
       
   IF      @C15Name<>''  SET @TotalCol= 15    --kocy01    
   ELSE IF @C14Name<>''  SET @TotalCol= 14       
   ELSE IF @C13Name<>''  SET @TotalCol= 13       
   ELSE IF @C12Name<>''  SET @TotalCol= 12       
   ELSE IF @C11Name<>''  SET @TotalCol= 11       
   ELSE IF @C10Name<>''  SET @TotalCol= 10       
   ELSE IF @C09Name<>''  SET @TotalCol= 9       
   ELSE IF @C08Name<>''  SET @TotalCol= 8       
   ELSE IF @C07Name<>''  SET @TotalCol= 7       
   ELSE IF @C06Name<>''  SET @TotalCol= 6       
   ELSE IF @C05Name<>''  SET @TotalCol= 5       
   ELSE IF @C04Name<>''  SET @TotalCol= 4       
   ELSE IF @C03Name<>''  SET @TotalCol= 3       
   ELSE IF @C02Name<>''  SET @TotalCol= 2     
      
       
      SET @Body = @Body + '<table border="0" cellpadding="0" cellspacing="0" height="100%" width="100%">        
      <tr><td align="center" valign="top"><table><tr><td><p class=a1>' + @Header + '</p>' +        
            '<table border="1" cellspacing="0" cellpadding="4" width="700">'+        
      CASE WHEN @R01Name<>'' THEN '<tr><th class=n>'+@R01Name+'</th><th class=v colspan='+@ColSpan+'>'+@R01+'</th></tr>' ELSE '' END+        
      CASE WHEN @R02Name<>'' THEN '<tr><th class=n>'+@R02Name+'</th><th class=v colspan='+@ColSpan+'>'+@R02+'</th></tr>' ELSE '' END+        
      CASE WHEN @R03Name<>'' THEN '<tr><th class=n>'+@R03Name+'</th><th class=v colspan='+@ColSpan+'>'+@R03+'</th></tr>' ELSE '' END+        
      CASE WHEN @R04Name<>'' THEN '<tr><th class=n>'+@R04Name+'</th><th class=v colspan='+@ColSpan+'>'+@R04+'</th></tr>' ELSE '' END+        
      CASE WHEN @R05Name<>'' THEN '<tr><th class=n>'+@R05Name+'</th><th class=v colspan='+@ColSpan+'>'+@R05+'</th></tr>' ELSE '' END+        
      CASE WHEN @R06Name<>'' THEN '<tr><th class=n>'+@R06Name+'</th><th class=v colspan='+@ColSpan+'>'+@R06+'</th></tr>' ELSE '' END+        
      CASE WHEN @R07Name<>'' THEN '<tr><th class=n>'+@R07Name+'</th><th class=v colspan='+@ColSpan+'>'+@R07+'</th></tr>' ELSE '' END+        
      CASE WHEN @R08Name<>'' THEN '<tr><th class=n>'+@R08Name+'</th><th class=v colspan='+@ColSpan+'>'+@R08+'</th></tr>' ELSE '' END+        
      CASE WHEN @R09Name<>'' THEN '<tr><th class=n>'+@R09Name+'</th><th class=v colspan='+@ColSpan+'>'+@R09+'</th></tr>' ELSE '' END+        
      CASE WHEN @R10Name<>'' THEN '<tr><th class=n>'+@R10Name+'</th><th class=v colspan='+@ColSpan+'>'+@R10+'</th></tr>' ELSE '' END+        
      CASE WHEN @R11Name<>'' THEN '<tr><th class=n>'+@R11Name+'</th><th class=v colspan='+@ColSpan+'>'+@R11+'</th></tr>' ELSE '' END+        
	  CASE WHEN @R12Name<>'' THEN '<tr><th class=n>'+@R12Name+'</th><th class=v colspan='+@ColSpan+'>'+@R12+'</th></tr>' ELSE '' END+        
      CASE WHEN @R13Name<>'' THEN '<tr><th class=n>'+@R13Name+'</th><th class=v colspan='+@ColSpan+'>'+@R13+'</th></tr>' ELSE '' END+        
      CASE WHEN @R14Name<>'' THEN '<tr><th class=n>'+@R14Name+'</th><th class=v colspan='+@ColSpan+'>'+@R14+'</th></tr>' ELSE '' END+        
      CASE WHEN @R15Name<>'' THEN '<tr><th class=n>'+@R15Name+'</th><th class=v colspan='+@ColSpan+'>'+@R15+'</th></tr>' ELSE '' END      
      
       
      SET @Body = @Body +        
      '<tr> ' +         
         CASE WHEN @C01Name<> '' THEN '<th class=n>'+@C01Name+'</th>' ELSE '' END+        
         CASE WHEN @C02Name<> '' THEN '<th class=n>'+@C02Name+'</th>' ELSE '' END+        
         CASE WHEN @C03Name<> '' THEN '<th class=n>'+@C03Name+'</th>' ELSE '' END+        
         CASE WHEN @C04Name<> '' THEN '<th class=n>'+@C04Name+'</th>' ELSE '' END+        
         CASE WHEN @C05Name<> '' THEN '<th class=n>'+@C05Name+'</th>' ELSE '' END+        
         CASE WHEN @C06Name<> '' THEN '<th class=n>'+@C06Name+'</th>' ELSE '' END+        
         CASE WHEN @C07Name<> '' THEN '<th class=n>'+@C07Name+'</th>' ELSE '' END+        
         CASE WHEN @C08Name<> '' THEN '<th class=n>'+@C08Name+'</th>' ELSE '' END+        
         CASE WHEN @C09Name<> '' THEN '<th class=n>'+@C09Name+'</th>' ELSE '' END+        
         CASE WHEN @C10Name<> '' THEN '<th class=n>'+@C10Name+'</th>' ELSE '' END+        
         CASE WHEN @C11Name<> '' THEN '<th class=n>'+@C11Name+'</th>' ELSE '' END+        
         CASE WHEN @C12Name<> '' THEN '<th class=n>'+@C12Name+'</th>' ELSE '' END+        
         CASE WHEN @C13Name<> '' THEN '<th class=n>'+@C13Name+'</th>' ELSE '' END+        
         CASE WHEN @C14Name<> '' THEN '<th class=n>'+@C14Name+'</th>' ELSE '' END+        
         CASE WHEN @C15Name<> '' THEN '<th class=n>'+@C15Name+'</th>' ELSE '' END+          
      '</tr>'        
         
            SET @SQL = N'SELECT @MailQDetXML = CAST ( ( SELECT ' +         
         CASE WHEN @C01Name<> '' THEN '   '''',''td/@class'' = '''+@C01Align+''', td = C01' ELSE '' END +        
         CASE WHEN @C02Name<> '' THEN ' , '''',''td/@class'' = '''+@C02Align+''', td = C02' ELSE '' END +        
         CASE WHEN @C03Name<> '' THEN ' , '''',''td/@class'' = '''+@C03Align+''', td = C03' ELSE '' END +        
         CASE WHEN @C04Name<> '' THEN ' , '''',''td/@class'' = '''+@C04Align+''', td = C04' ELSE '' END +        
         CASE WHEN @C05Name<> '' THEN ' , '''',''td/@class'' = '''+@C05Align+''', td = C05' ELSE '' END +        
         CASE WHEN @C06Name<> '' THEN ' , '''',''td/@class'' = '''+@C06Align+''', td = C06' ELSE '' END +        
         CASE WHEN @C07Name<> '' THEN ' , '''',''td/@class'' = '''+@C07Align+''', td = C07' ELSE '' END +        
         CASE WHEN @C08Name<> '' THEN ' , '''',''td/@class'' = '''+@C08Align+''', td = C08' ELSE '' END +        
         CASE WHEN @C09Name<> '' THEN ' , '''',''td/@class'' = '''+@C09Align+''', td = C09' ELSE '' END +        
         CASE WHEN @C10Name<> '' THEN ' , '''',''td/@class'' = '''+@C10Align+''', td = C10' ELSE '' END +        
         CASE WHEN @C11Name<> '' THEN ' , '''',''td/@class'' = '''+@C11Align+''', td = C11' ELSE '' END +        
         CASE WHEN @C12Name<> '' THEN ' , '''',''td/@class'' = '''+@C12Align+''', td = C12' ELSE '' END +        
         CASE WHEN @C13Name<> '' THEN ' , '''',''td/@class'' = '''+@C13Align+''', td = C13' ELSE '' END +        
         CASE WHEN @C14Name<> '' THEN ' , '''',''td/@class'' = '''+@C14Align+''', td = C14' ELSE '' END +        
         CASE WHEN @C15Name<> '' THEN ' , '''',''td/@class'' = '''+@C15Align+''', td = C15' ELSE '' END       
    
       IF @debug = 1        
       BEGIN         
         PRINT @SQL      
       END        
                   
      -- Remove Last ","          
      SET @SQL = @SQL + ' FROM MailQDet WHERE Qid='+CAST(@Qid AS varchar(10))+' FOR XML PATH(''tr''), TYPE) AS NVARCHAR(MAX) )'      
      
      EXEC sp_executesql @SQL, N'@MailQDetXML NVARCHAR(MAX) OUTPUT', @MailQDetXML OUTPUT      
                     
      SET @Body = @Body + @MailQDetXML     
    
   -- kocy01    
   -- Start: count total     
    IF  @C01Agg<>'' OR  @C02Agg<>'' OR  @C03Agg<>'' OR @C04Agg<>'' OR  @C05Agg<>'' OR @C06Agg<>'' OR @C07Agg<>'' OR @C08Agg<>''         
         OR @C09Agg <> '' OR @C10Agg <> '' OR @C11Agg <> '' OR @C12Agg <> '' OR @C13Agg <> '' OR  @C14Agg <> '' OR @C15Agg <> ''    
    BEGIN    
    
      IF       @C02Agg<> ''  SET @C01AggLabel = 'Grand Total'    
      ELSE IF  @C03Agg<> ''  SET @C02AggLabel = 'Grand Total'    
      ELSE IF  @C04Agg<> ''  SET @C03AggLabel = 'Grand Total'    
      ELSE IF  @C05Agg<> ''  SET @C04AggLabel = 'Grand Total'    
      ELSE IF  @C06Agg<> ''  SET @C05AggLabel = 'Grand Total'    
      ELSE IF  @C07Agg<> ''  SET @C06AggLabel = 'Grand Total'    
      ELSE IF  @C08Agg<> ''  SET @C07AggLabel = 'Grand Total'    
      ELSE IF  @C09Agg<> ''  SET @C08AggLabel = 'Grand Total'    
      ELSE IF  @C10Agg<> ''  SET @C09AggLabel = 'Grand Total'    
      ELSE IF  @C11Agg<> ''  SET @C10AggLabel = 'Grand Total'    
      ELSE IF  @C12Agg<> ''  SET @C11AggLabel = 'Grand Total'    
      ELSE IF  @C13Agg<> ''  SET @C12AggLabel = 'Grand Total'    
      ELSE IF  @C14Agg<> ''  SET @C13AggLabel = 'Grand Total'    
      ELSE IF  @C15Agg<> ''  SET @C14AggLabel = 'Grand Total'    
    
      SET @SQLAgg = N'SELECT @MailQDetAggXML = CAST ( ( SELECT ' +      
      CASE WHEN @C01Agg<> '' THEN ', '''',''td/@class'' = '''+@C01Align+''', td = '+@c01Agg+'(TRY_CAST(C01 AS INT)) ' ELSE ', '''',''td/@class'' = '''+@C01Align+''',td = '''+@C01AggLabel+''' ' END +        
      CASE WHEN @C02Agg<> '' THEN ', '''',''td/@class'' = '''+@C02Align+''', td = '+@c02Agg+'(TRY_CAST(C02 AS INT)) ' ELSE ', '''',''td/@class'' = '''+@C02Align+''',td = '''+@C02AggLabel+''' ' END +        
      CASE WHEN @C03Agg<> '' THEN ', '''',''td/@class'' = '''+@C03Align+''', td = '+@c03Agg+'(TRY_CAST(C03 AS INT)) ' ELSE ', '''',td = '''+@C03AggLabel+''' ' END +        
      CASE WHEN @C04Agg<> '' THEN ', '''',''td/@class'' = '''+@C04Align+''', td = '+@c04Agg+'(TRY_CAST(C04 AS INT)) ' ELSE ', '''',td = '''+@C04AggLabel+''' ' END +        
      CASE WHEN @C05Agg<> '' THEN ', '''',''td/@class'' = '''+@C05Align+''', td = '+@c05Agg+'(TRY_CAST(C05 AS INT)) ' ELSE ', '''',td = '''+@C05AggLabel+''' ' END +        
      CASE WHEN @C06Agg<> '' THEN ', '''',''td/@class'' = '''+@C06Align+''', td = '+@c06Agg+'(TRY_CAST(C06 AS INT)) ' ELSE ', '''',td = '''+@C06AggLabel+''' ' END +        
      CASE WHEN @C07Agg<> '' THEN ', '''',''td/@class'' = '''+@C07Align+''', td = '+@c07Agg+'(TRY_CAST(C07 AS INT)) ' ELSE ', '''',td = '''+@C07AggLabel+''' ' END +        
      CASE WHEN @C08Agg<> '' THEN ', '''',''td/@class'' = '''+@C08Align+''', td = '+@c08Agg+'(TRY_CAST(C08 AS INT)) ' ELSE ', '''',td = '''+@C08AggLabel+''' ' END +        
      CASE WHEN @C09Agg<> '' THEN ', '''',''td/@class'' = '''+@C09Align+''', td = '+@c09Agg+'(TRY_CAST(C09 AS INT)) ' ELSE ', '''',td = '''+@C09AggLabel+''' ' END +        
      CASE WHEN @C10Agg<> '' THEN ', '''',''td/@class'' = '''+@C10Align+''', td = '+@c10Agg+'(TRY_CAST(C10 AS INT)) ' ELSE ', '''',td = '''+@C10AggLabel+''' ' END +        
      CASE WHEN @C11Agg<> '' THEN ', '''',''td/@class'' = '''+@C11Align+''', td = '+@c11Agg+'(TRY_CAST(C11 AS INT)) ' ELSE ', '''',td = '''+@C11AggLabel+''' ' END +        
      CASE WHEN @C12Agg<> '' THEN ', '''',''td/@class'' = '''+@C12Align+''', td = '+@c12Agg+'(TRY_CAST(C12 AS INT)) ' ELSE ', '''',td = '''+@C12AggLabel+''' ' END +        
      CASE WHEN @C13Agg<> '' THEN ', '''',''td/@class'' = '''+@C13Align+''', td = '+@c13Agg+'(TRY_CAST(C13 AS INT)) ' ELSE ', '''',td = '''+@C13AggLabel+''' ' END +        
      CASE WHEN @C14Agg<> '' THEN ', '''',''td/@class'' = '''+@C14Align+''', td = '+@c14Agg+'(TRY_CAST(C14 AS INT)) ' ELSE ', '''',td = '''+@C14AggLabel+''' ' END +        
      CASE WHEN @C15Agg<> '' THEN ', '''',''td/@class'' = '''+@C15Align+''', td = '+@c15Agg+'(TRY_CAST(C15 AS INT)) ' ELSE ', '''',td = '''+@C15AggLabel+''' ' END      
      
            
      SET @SQLAgg = replace(@SQLAgg,'SELECT ,','SELECT ') + ' FROM MailQDet WHERE Qid='+CAST(@Qid AS varchar(10))+' FOR XML PATH(''tr''), TYPE) AS NVARCHAR(MAX) )'      
      PRINT @SQLAgg     
             
      EXEC sp_executesql @SQLAgg, N'@MailQDetAggXML NVARCHAR(MAX) OUTPUT', @MailQDetAggXML OUTPUT      
    
      IF       @TotalCol = 14 SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/></tr>', '</tr>')    
      ELSE IF  @TotalCol = 13 SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 12 SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 11 SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 10 SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 9  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 8  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 7  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 6  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 5  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 4  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 3  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
      ELSE IF  @TotalCol = 2  SET @MailQDetAggXML = REPLACE(@MailQDetAggXML, '<td/><td/><td/><td/><td/><td/><td/><td/><td/><td/><td/><td/><td/></tr>','</tr>')    
          
      IF @debug = 1        
      BEGIN         
        PRINT @MailQDetAggXML    
      END       
    
      SET @Body = @Body + @MailQDetAggXML     
   END   -- kocy01    
    
      SET @Body = @Body + '</table>'       
                                       
      SET @Body = @Body  + '<p class=a1>'+@Footer +'</p></td></tr></table></td></tr></table>'      
        
      SET @Body = REPLACE(REPLACE(@Body,'&lt;','<'),'&gt;','>')        
          
             
        
      EXEC msdb.dbo.sp_send_dbmail        
         @recipients      = @SendTo,        
         @copy_recipients = @Cc,        
         @blind_copy_recipients= @Bcc,        
         @subject         = @Subject,        
         @body            = @Body,        
         @body_format     = 'HTML',        
         @mailitem_id     = @sysMail_id OUTPUT;        
       
      UPDATE MailQ SET mailitem_id=@sysMail_id WHERE Qid = @Qid        
   END        
END /* main procedure */        
        

GO