SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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
/* 03-Aug-2015  Barnett Modified for TAETH Thailand                     */
/* 13-Oct-2015  Barnett Remove Truck type from Email (BL001)            */
/************************************************************************/            
            
CREATE PROC [dbo].[isp_send_dbmail_TAETH]        
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
            @cReceiptDetailBody nvarchar(max),
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
        
   DECLARE  @c_ExternReceiptKey     NVARCHAR(20),
            @c_RefReceiptKey        NVARCHAR(10),
            @c_CarrierKey           NVARCHAR(15),
            @c_PlaceofDelivery      NVARCHAR(250),
            @c_Wave                 NVARCHAR(250),
            @c_TruckType            NVARCHAR(250),
            @c_DeliveryType         NVARCHAR(250),
            @c_PCCDeliveryDate      DATETIME,
            @c_DCDeliveryDate       DATETIME,
            @c_SKU                  NVARCHAR(40),
            @n_QtyExpectedQty       INT,
            @c_Temperature          NVARCHAR(250),
            @c_ReceiptLineNumber    NVARCHAR(10)
            

      
   SET @cImpt = 'Normal'      
   SET @dUTC = GETUTCDATE()      
   SET @cListTo = ''      
   SET @cListCc = ''
   SET @cReceiptDetailBody =N''

   --Get The refReceiptKey first
--   SELECT @c_RefReceiptKey = ReceiptKey
--   FROM EC_Receipt ECR WITH (NOLOCk)    
--   WHERE ECR.RefReceiptKey = @cText
   SET @c_RefReceiptKey = @cText
   
   --Get All The Email Body information
   SELECT @c_ExternReceiptKey = rc.ExternReceiptKey,
          @c_CarrierKey = CarrierKey,
          @c_PlaceofDelivery = CLP1.Description,
          @c_Wave = CLP2.Description,
          @c_TruckType = CLP3.Description,
          @c_DeliveryType = CLP4.Description,
          @c_PCCDeliveryDate = rc.UserDefine07,
          @c_DCDeliveryDate  = UserDefine06                    
   FROM Receipt RC WITH (NOLOCK)
   LEFT OUTER JOIN Codelkup CLP1 WITH (NOLOCK) ON CLP1.Listname = 'ASNPlcDel'  and CLP1.Code = rc.PlaceofDelivery
   LEFT OUTER JOIN Codelkup CLP2 WITH (NOLOCK) ON CLP2.Listname = 'ASNCarrRef' and CLP2.Code = rc.CarrierReference
   LEFT OUTER JOIN Codelkup CLP3 WITH (NOLOCK) ON CLP3.Listname = 'TrkLoadDur' and CLP3.Code = rc.ContainerType
   LEFT OUTER JOIN Codelkup CLP4 WITH (NOLOCK) ON CLP4.Listname = 'ASNRcptGrp'  and CLP4.Code = rc.ReceiptGroup      
   WHERE RC.ReceiptKey = @c_RefReceiptKey
 
   



      
   IF @cType = 'ReceiptSubmited'      
   BEGIN      
      SET @cSubject = N'PCC ANS Comfirmation (PO:' + @c_ExternReceiptKey  + '/ASN:' + @c_RefReceiptKey + ')'       
                 
      -- EXEC ESECURE.dbo.aspnet_Membership_GetUserByName '/', @cUser, @dUTC      
      SELECT TOP 1 @cListTo = m.Email
      FROM   ESECURE.dbo.aspnet_Users u, ESECURE.dbo.aspnet_Membership m    
      WHERE  LOWER(@cUser) = u.LoweredUserName AND u.UserId = m.UserId   

      --Construct Receipt Detail Body record
      DECLARE ReceiptDetail_cursor CURSOR
      FOR
            SELECT RD.ReceiptLineNumber, RD.QtyExpected, RD.SKU, Description 'Temperature' 
            FROM ReceiptDetail RD WITH (NOLOCK)
            LEFT OUTER JOIN Codelkup CLP WITH (NOLOCK) ON CLP.Listname = 'ASNHUDF01'  and CLP.Code = RD.UserDefine01      
            WHERE RD.ReceiptKey = @c_RefReceiptKey 

      OPEN ReceiptDetail_cursor
      FETCH NEXT FROM ReceiptDetail_cursor
      INTO @c_ReceiptLineNumber, @n_QtyExpectedQty, @c_SKU, @c_Temperature                

      WHILE @@FETCH_STATUS = 0
      BEGIN

         
          SELECT @cReceiptDetailBody = @cReceiptDetailBody
                                       +N'<tr><td>'+ @c_ReceiptLineNumber +'</td> <td>' + @c_SKU + '</td> <td align="Center">'+ @c_Temperature+ '</td> <td align="Center">' + Cast(@n_QtyExpectedQty as varchar(19)) + '</td></tr>'
                                       

     
                                 
      FETCH NEXT FROM ReceiptDetail_cursor
      INTO @c_ReceiptLineNumber, @n_QtyExpectedQty, @c_SKU, @c_Temperature
      END

      CLOSE ReceiptDetail_cursor
      DEALLOCATE ReceiptDetail_cursor



          
      --ELSE    
      --BEGIN    
      --   SELECT TOP 1 @cListCc = m.Email    
      --   FROM   ESECURE.dbo.aspnet_Users u, ESECURE.dbo.aspnet_Membership m    
      --   WHERE  LOWER(@cUser) = u.LoweredUserName AND u.UserId = m.UserId    
      --END
      --SET @cListCc = @cListCc + ';kahhweelim@lifung.com.my;LimTzeKeong@LFLogistics.com'          
      --SET @cListCc = @cListCc + ';LimTzeKeong@LFLogistics.com'          
      
      SET @cBody = N'<style type="text/css">       
         p.a1  {  font-family: CordiaUPC; font-size: 14px;  }      
         table {  font-family: CordiaUPC; table-layout: auto; margin-left: 3em; }      
         table, td, th { padding:3px; font-size: 14px; }      
         </style>' + CHAR(13)      

--      ENGlish version
--      SET @cBody = @cBody + N'<p class=a1>Dear '+@cUser+' <br /><br />' + CHAR(13)                 
--               + 'Confirmed ASN has been created as below:' + CHAR(13)  
--               + '<br></br>'
--               + '<table>'  
--               + '<tr><td>ASN #</td>                           <td>:'+ @c_RefReceiptKey      + '</td><td>'+'</td></tr>'  
--               + '<tr><td>Vendor Code</td>                     <td>:'+ @c_CarrierKey         + '</td><td>'+'</td></tr>'  
--               + '<tr><td>PO #</td>                            <td>:'+ @c_ExternReceiptKey   + '</td><td>'+'</td></tr>' 
--               + '<tr><td>DC </td>                             <td>:'+ @c_PlaceofDelivery    + '</td><td>'+'</td></tr>'  
--               + '<tr><td>Wave</td>                            <td>:'+ @c_Wave               + '</td><td>'+'</td></tr>'                 
--               + '<tr><td>Truck Type</td>                      <td>:'+ @c_TruckType          + '</td><td>'+'</td></tr>'  
--               + '<tr><td>Delivery Type</td>                   <td>:'+ @c_DeliveryType       + '</td><td>'+'</td></tr>'  --TK001
--               + '<tr><td>PCC Delivery Date & Time</td>        <td>:'+ Convert(varchar(20), @c_PCCDeliveryDate, 100) + '</td><td>'+'</td></tr>'                 --TK001
--               + '<tr><td>DC Delivery Date</td>                <td>:'+ Convert(varchar(12), @c_DCDeliveryDate, 100)  + '</td><td>'+'</td></tr>'                  --TK001
--               + '</Table>'
--               + '<br>'
--               + '<br>'
--               + '<table border=1 ' 
--               + +'<tr><td><b>Receipt Line</b></td> <td><b>SKU</b></td> <td><b>Temperature</b></td> <td><b>Quantity</b></td></tr>'
--               + @cReceiptDetailBody
--               + '</table>'
--               + '<br></br>'               
--               + 'Best Regards,<br />  
--                  TAE Team <br />                    
--                  HotLine: 02-832-6973, 081-938-9256  </p>'  

     --Thai Version
     SET @cBody = @cBody + N'<p class=a1>เรียน '+@cUser+' <br /><br />' + CHAR(13)                 
               + N'ยืนยันการสร้าง ASN ของท่านสำเร็จ รายละเอียดดังนี้:' + CHAR(13)  
               + N'<br></br>'
               + N'<table>'  
               + N'<tr><td>ASN #</td>                          <td>:'+ @c_RefReceiptKey      + '</td><td>'+'</td></tr>'  
               + N'<tr><td>รหัสผู้ขาย</td>                         <td>:'+ @c_CarrierKey         + '</td><td>'+'</td></tr>'  
               + N'<tr><td>เลขที่ใบสั่งซื้อ #</td>                     <td>:'+ @c_ExternReceiptKey   + '</td><td>'+'</td></tr>' 
               + N'<tr><td>ศูนย์กระจายเลขที่</td>                    <td>:'+ @c_PlaceofDelivery    + '</td><td>'+'</td></tr>'  
               + N'<tr><td>รอบ</td>                             <td>:'+ @c_Wave               + '</td><td>'+'</td></tr>'                 
               --+ N'<tr><td>ประเภทรถ</td>                         <td>:'+ @c_TruckType          + '</td><td>'+'</td></tr>'  -- BL001
               + N'<tr><td>ประเภทการจัดส่ง</td>                     <td>:'+ @c_DeliveryType       + '</td><td>'+'</td></tr>'  --TK001
               + N'<tr><td>วันและเวลาถึง PCC</td>                   <td>:'+ Convert(varchar(20), @c_PCCDeliveryDate, 100) + '</td><td>'+'</td></tr>'                 --TK001
               + N'<tr><td>วันถึงศนย์กระจาย</td>                <td>:'+ Convert(varchar(12), @c_DCDeliveryDate, 100)  + '</td><td>'+'</td></tr>'                  --TK001
               + N'</Table>'
               + N'<br>'
               + N'<br>'
               + N'<table border=1 ' 
               + N'<tr><td><b>Receipt Line</b></td> <td><b>SKU</b></td> <td><b>Temperature</b></td> <td><b>Quantity</b></td></tr>'
               + @cReceiptDetailBody
               + N'</table>'
               + N'<br></br>'               
               + N'Best Regards,<br />  
                  TAE Team <br />                    
                  HotLine: 02-832-6973, 081-938-9256  </p>'  


      
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