SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Proc : isp_FOM_Orders_AlertNotification                         	*/
/* Creation Date:  01-Sep-2015                                             */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: Carter FOM Orders vs WMS Orders Checking - Email Alert         */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Back-end job                                 	               */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 10-Dec-2015 SHONG       1.1   Exclude ShippingStatus = 10               */
/***************************************************************************/
CREATE PROC [dbo].[isp_FOM_Orders_AlertNotification] 
  @cRecipientList NVARCHAR(MAX) 
AS
BEGIN 
   SET NOCOUNT ON 

   IF OBJECT_ID('tempdb..#Codelkup') IS NOT NULL 
      DROP TABLE #Codelkup
      
   CREATE TABLE #Codelkup (ListName VARCHAR(20), Code VARCHAR(10), Descr NVARCHAR(60))

   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('1', 'OrderStatus',N'未确认')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('2', 'OrderStatus',N'已确认')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('3', 'OrderStatus',N'已取消')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('4', 'OrderStatus',N'无效')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('5', 'OrderStatus',N'退货')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('6', 'OrderStatus',N'已分单')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('7', 'OrderStatus',N'部分分单')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('18','OrderStatus',N'换货流程中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('19','OrderStatus',N'换货完成')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('20','OrderStatus',N'退货流程中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('21','OrderStatus',N'退货完成')   
   
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('15','PayStatus',N'未付款')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('16','PayStatus',N'付款中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('17','PayStatus',N'已付款')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('24','PayStatus',N'退款中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('25','PayStatus',N'已退款')
   
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('8', 'ShippingStatus',N'未发货')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('9', 'ShippingStatus',N'已发货')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('10','ShippingStatus',N'已收货')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('11','ShippingStatus',N'拣货中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('12','ShippingStatus',N'发货中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('13','ShippingStatus',N'发货中(处理分单)')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('14','ShippingStatus',N'已发货(部分商品)')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('22','ShippingStatus',N'退货中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('23','ShippingStatus',N'已退货')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('26','ShippingStatus',N'申请换货中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('27','ShippingStatus',N'申请退货中')
   INSERT INTO #CODELKUP (Code, ListName, Descr) VALUES ('28','ShippingStatus',N'等待退货')

   DECLARE @tableHTML  NVARCHAR(MAX) ;
   DECLARE @cExternOrderKey NVARCHAR(20)
   
   -- Remove Duplicate Orders
   DECLARE @cOrderID VARCHAR(20), 
           @cOrderSn VARCHAR(50) 
   WHILE 1=1
   BEGIN
      SET @cOrderID=''
      SET @cOrderSn=''
      
      SELECT TOP 1
         @cOrderSn=tfo.OrderSn, @cOrderID=Max(tfo.OrderId)
      FROM Temp_FOM_Orders AS tfo (NOLOCK) 
      GROUP BY tfo.OrderSn
      HAVING COUNT(*) > 1    
      IF @@ROWCOUNT = 0 
         BREAK 
         
      DELETE Temp_FOM_Orders
      WHERE OrderId = @cOrderID AND OrderSn = @cOrderSn
   END
   
   
   CREATE TABLE #MissingOrder( ExternOrderKey NVARCHAR(20) )
   INSERT INTO #MissingOrder
   SELECT RTRIM(LTRIM(tfo.OrderSn)) 
   FROM Temp_FOM_Orders AS tfo (NOLOCK) 
   LEFT OUTER JOIN ORDERS OH (NOLOCK) ON OH.StorerKey= 'CARTER' AND OH.ExternOrderKey = RTRIM(LTRIM(tfo.OrderSn)) 
   LEFT OUTER JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey
   WHERE tfo.OrderStatus NOT IN ('3', '4','20') 
   AND   tfo.ShippingStatus NOT IN ('10') 
   GROUP BY RTRIM(LTRIM(tfo.OrderSn)), tfo.OriginalQty
   HAVING tfo.OriginalQty <> ISNULL(SUM(OD.EnteredQTY),0)

   DECLARE  CUR_ExtOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ExternOrderKey 
   FROM #MissingOrder AS mo
   
   OPEN CUR_ExtOrder
   
   FETCH NEXT FROM CUR_ExtOrder INTO @cExternOrderKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK)
                WHERE StorerKey = 'CARTER' 
                AND   ExternOrderKey Like @cExternOrderKey + '_%'
                AND   M_Company = @cExternOrderKey)
      BEGIN
         DELETE FROM #MissingOrder
         WHERE ExternOrderKey = @cExternOrderKey
      END
      FETCH NEXT FROM CUR_ExtOrder INTO @cExternOrderKey
   END
   
                            
   IF EXISTS(SELECT 1 FROM #MissingOrder)
   BEGIN
      SET @tableHTML = 
          N'<H1>Missing CARTER eCOM Orders</H1>' +
          N'<table border="1">' +
          N'<tr><th>Order No</th><th>Shipping Status</th>' +
          N'<th>Order Status</th><th>Original Qty</th>' +
          N'<th>WMS Qty</th>' +
          N'<th>WMS Status</th>' +          
          N'<th>Add Date</th></tr>' +
          CAST ( (SELECT 
          td = RTRIM(LTRIM(tfo.OrderSn)), '', 
          td = ShippingStatus.Descr, '',
          td = OrderStatus.Descr, '', 
          td = tfo.OriginalQty, '',
          td = ISNULL(SUM(OD.EnteredQTY),0), '', 
          td = ISNULL(OH.Status, 'Not Exists'), '', 
          td = SUBSTRING(tfo.AddDate, 1, 4) + '-' + SUBSTRING(tfo.AddDate, 5, 2) +  '-' + SUBSTRING(tfo.AddDate, 7, 2) + ' ' 
             + SUBSTRING(tfo.AddDate, 9, 2) + ':' + SUBSTRING(tfo.AddDate, 11, 2) + ':' + SUBSTRING(tfo.AddDate, 13, 2) 
      FROM Temp_FOM_Orders AS tfo (NOLOCK) 
      JOIN #MissingOrder MO (NOLOCK) ON MO.ExternOrderKey = RTRIM(LTRIM(tfo.OrderSn)) 
      LEFT JOIN #Codelkup AS OrderStatus ON (tfo.OrderStatus = OrderStatus.Code AND OrderStatus.ListName = 'OrderStatus')
      LEFT JOIN #Codelkup AS ShippingStatus ON (tfo.ShippingStatus = ShippingStatus.Code AND ShippingStatus.ListName = 'ShippingStatus')
      LEFT JOIN #Codelkup AS PayStatus ON (tfo.OrderStatus = PayStatus.Code AND PayStatus.ListName = 'PayStatus')  
      LEFT OUTER JOIN ORDERS OH (NOLOCK) ON OH.StorerKey= 'CARTER' AND OH.ExternOrderKey = RTRIM(LTRIM(tfo.OrderSn)) 
      LEFT OUTER JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey 
      WHERE tfo.OrderStatus NOT IN ('3', '4','20') 
      AND   tfo.ShippingStatus NOT IN ('10') 
      GROUP BY RTRIM(LTRIM(tfo.OrderSn)), 
             ShippingStatus.Descr, OrderStatus.Descr, tfo.OriginalQty, ISNULL(OH.Status, 'Not Exists'), 
             SUBSTRING(tfo.AddDate, 1, 4) + '-' + SUBSTRING(tfo.AddDate, 5, 2) +  '-' + SUBSTRING(tfo..AddDate, 7, 2) + ' ' 
             + SUBSTRING(tfo.AddDate, 9, 2) + ':' + SUBSTRING(tfo.AddDate, 11, 2) + ':' + SUBSTRING(tfo.AddDate, 13, 2)
      HAVING ISNULL(SUM(OD.EnteredQTY),0) = 0  
      --HAVING tfo.OriginalQty <> ISNULL(SUM(OD.EnteredQTY),0) 
      FOR XML PATH('tr'), TYPE 
                ) AS NVARCHAR(MAX) ) +
                N'</table>' ;     

      EXEC msdb.dbo.sp_send_dbmail @recipients=@cRecipientList,
          @subject = 'Missing CARTER eCOM Orders Alert Notification',
          @body = @tableHTML,
          @body_format = 'HTML' ;
   
   END

END -- Records Exists
       

GO