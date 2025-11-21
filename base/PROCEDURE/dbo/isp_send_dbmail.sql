SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/            
/* Stored Procedure: isp_send_dbmail                                    */            
/* Creation Date: 15-Aug-2012                                           */            
/* Copyright: IDS                                                       */            
/* Written by: KHLim                                                    */            
/*                                                                      */            
/* Purpose: - For eWMS Warehouse Door Booking Module                    */      
/*          - To send email notification when booking schedules or      */            
/*            when feedback form is submitted                           */            
/*                                                                      */            
/* Called By:                                                           */            
/*                                                                      */            
/* PVCS Version: 1.0                                                    */            
/*                                                                      */            
/* Version: 5.4                                                         */            
/*                                                                      */            
/* Data Modifications:                                                  */            
/*                                                                      */            
/* Updates:                                                             */            
/* Date         Author  Purposes                                        */            
/* 26-Sep-2012  TKLIM   Change Expected time in out (TK001)             */            
/************************************************************************/            
            
CREATE PROC [dbo].[isp_send_dbmail]        
(      
   @cText   nvarchar(800),      
   @cType   nvarchar(100),      
   @cUser   nvarchar(256)  = ''      
)      
AS          
BEGIN          
          
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF          
             
   DECLARE  @cBody      nvarchar(MAX),        
            @cSubject   nvarchar(MAX),      
            @cImpt      varchar(6),      
            @cListTo    varchar(max),      
            @cListCc    varchar(max),      
            @dUTC       datetime,      
            @cSName     nvarchar(45),      
            @cExPO      nvarchar(20),      
            @dBook      datetime,      
            @dEnd       datetime,      
            @cDesc      nvarchar(250),      
            @cNotes     nvarchar(MAX),        
            @cSpHand    nvarchar(250),    
            @cMsgID     nvarchar(10)    
                
   DECLARE  @b_success  int,    
            @n_err      int,    
            @c_errmsg   char(250)    
                
                
      
   SET @cImpt = 'Normal'      
   SET @dUTC = GETUTCDATE()      
   SET @cListTo = ''      
   SET @cListCc = ''      
      
   IF @cType = 'Booking Confirm'      
   BEGIN      
      SET @cSubject = N'E-WMS ' + @cType  + ': #' + @cText        
      
      SELECT       
            @cSName  = (CASE WHEN ISNULL(RTRIM(SC.SValue),0) = 1 THEN PO.SellersReference ELSE PO.SellerName END),      
            @cExPO   = PO.ExternPOKey,        
            @dBook   = BI.BookingDate,        
            @dEnd    = BI.EndTime,      
            @cDesc   = CL.Description,      
            @cNotes  = PO.Notes,         
            @cSpHand = CH.Description  --BI.SpecialHandling        
      FROM Booking_In BI WITH (NOLOCK)         
      LEFT OUTER JOIN PO WITH (NOLOCK)        
         ON BI.POKey = PO.POKey        
      LEFT OUTER JOIN StorerConfig SC (NOLOCK)         
         ON PO.StorerKey = SC.StorerKey         
         AND SC.ConfigKey = 'POSellerInRefField'          
      LEFT OUTER JOIN CODELKUP CL (NOLOCK)             
        ON BI.Type = CL.Code             
         AND CL.LISTNAME = 'TrkLoadDur'          
      LEFT OUTER JOIN CODELKUP CH WITH (NOLOCK)            
         ON BI.SpecialHandling = CH.Code             
         AND CH.LISTNAME = 'TrkHandDur'          
      WHERE BI.BookingNo = @cText      
      
      -- EXEC ESECURE.dbo.aspnet_Membership_GetUserByName '/', @cUser, @dUTC      
      IF @cSName <> ''           
      BEGIN    
         SELECT TOP 1 @cListTo = ISNULL(m.Email,'')    
         FROM   ESECURE.dbo.aspnet_Users u, ESECURE.dbo.aspnet_Membership m    
         WHERE  LOWER(@cSName) = u.LoweredUserName AND u.UserId = m.UserId    
      END    
          
      IF @cListTo = ''      
      BEGIN      
         SELECT TOP 1 @cListTo = m.Email    
         FROM   ESECURE.dbo.aspnet_Users u, ESECURE.dbo.aspnet_Membership m    
         WHERE  LOWER(@cUser) = u.LoweredUserName AND u.UserId = m.UserId    
      END    
      --ELSE    
      --BEGIN    
      --   SELECT TOP 1 @cListCc = m.Email    
      --   FROM   ESECURE.dbo.aspnet_Users u, ESECURE.dbo.aspnet_Membership m    
      --   WHERE  LOWER(@cUser) = u.LoweredUserName AND u.UserId = m.UserId    
      --END
      --SET @cListCc = @cListCc + ';kahhweelim@lifung.com.my;LimTzeKeong@LFLogistics.com'          
      --SET @cListCc = @cListCc + ';LimTzeKeong@LFLogistics.com'          
      
      SET @cBody = N'<style type="text/css">       
         p.a1  {  font-family: Arial; font-size: 12px;  }      
         table {  font-family: Arial; table-layout: fixed; margin-left: 3em; }      
         table, td, th { padding:3px; font-size: 12px; }      
         </style>' + CHAR(13)      
      
      SET @cBody = @cBody + N'<p class=a1>Hi '+@cSName+'!<br /><br />' + CHAR(13)  
               + 'Confirmed schedule summary:' + CHAR(13)  
               + '<table>'  
               + '<tr><td>Appointment #</td>                   <td>:</td><td>'+@cText+'</td></tr>'  
               + '<tr><td>Supplier</td>                        <td>:</td><td>'+@cSName+'</td></tr>'  
               + '<tr><td>PO #</td>                            <td>:</td><td>'+@cExPO+'</td></tr>'  
               + '<tr><td>Delivery Date</td>                   <td>:</td><td>'+CONVERT(CHAR(11),@dBook,0)+'</td></tr>'  
               + '<tr><td>Truck to be Used</td>                <td>:</td><td>'+@cDesc+'</td></tr>'  
               + '<tr><td>Special Handling Needed</td>         <td>:</td><td>'+@cSpHand+'</td></tr>'  
               + '<tr><td>Expected Arrival Time</td>           <td>:</td><td>'+CONVERT(CHAR(5),DATEADD(n,-30,@dBook),14)+'</td></tr>'  --TK001
               + '<tr><td>Expected Unloading Start Time</td>   <td>:</td><td>'+CONVERT(CHAR(5),@dBook,14)+'</td></tr>'                 --TK001
               + '<tr><td>Expected Unloading End Time</td>     <td>:</td><td>'+CONVERT(CHAR(5),@dEnd,14)+'</td></tr>'                  --TK001
               + '<tr><td>Expected Departure Time</td>         <td>:</td><td>'+CONVERT(CHAR(5),DATEADD(n,30,@dEnd),14)+'</td></tr>'    --TK001
               + '<tr><td>Remarks</td>                         <td>:</td><td>'+@cNotes+'</td></tr></table>' + CHAR(13)  
               + 'Please note that for Deliveries that will be undergoing Quality Inspection  
                  should arrive 2-3 hours prior to the expected arrival time.<br />  
                  <br />  
                  Thanks,<br />  
                  Scheduler Team<br />  
                  JWS Logistics Distribution Center<br />  
                  Bicutan, Paranaque City</p>'  
      
   END      
   ELSE      
   BEGIN    
       
      SET @cMsgID = '0'    
          
      EXECUTE nspg_getkey    
        'eBookingFeedbackKey'    
       , 10    
       , @cMsgID OUTPUT    
       , @b_success OUTPUT    
       , @n_err OUTPUT    
       , @c_errmsg OUTPUT    
       
      SET @cSubject = N'Booking Scheduler Supplier Comments and Suggestions: '    
      SET @cListTo = 'MelanieLeyritana@lifung.com.ph'      
      SET @cListCc = 'LimTzeKeong@lifung.com.my'    
          
      SET @cBody = N'<style type="text/css">       
         p.a1  {  font-family: Arial; font-size: 12px;  }      
         table {  font-family: Arial; table-layout: fixed; margin-left: 3em; }      
         table, td, th { padding:3px; font-size: 12px; }      
         </style>' + CHAR(13)      
    
      SET @cBody = @cBody + N'<table>'        
               + '<tr><td>Supplier ID #</td>             <td>:</td><td>'+ @cUser +'</td></tr>'          
               + '<tr><td>Comments & Suggestion #</td>   <td>:</td><td>'+ @cMsgID +'</td></tr>'          
               + '<tr><td>Message</td>          <td>:</td><td>'+ @cText +'</td></tr></table>' + CHAR(13)    
      
   END      
      
   EXEC msdb.dbo.sp_send_dbmail       
      @recipients      = @cListTo,      
      @copy_recipients = @cListCc,      
      @subject         = @cSubject,      
      @importance      = @cImpt,      
      @body            = @cBody,      
      @body_format     = 'HTML' ;      
      
END /* main procedure */

GO