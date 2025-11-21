SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_MHD_AutoAllocation                                */
/* Creation Date: 04-APR-2022                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-19251 - SG MHD - Auto allocation                           */
/*                                                                         */
/* Called By: SQL Backend Job run hourly                                   */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04-APR-2022  NJOW01  1.0   DEVOPS Combine Script                        */          
/* 27-JUL-2022  NJOW02  1.1   WMS-20340 auto-allocate based on delivery    */
/*                            date                                         */
/* 09-SEP-2022  CHONGCS 1.2   WMS-20585 add auto print (CS01)              */ 
/* 22-MAR-2023  NJOW03  1.3   WMS-22052 specific consignee must allocate   */
/*                            min qty by innerpack                         */
/***************************************************************************/
CREATE   PROC [dbo].[isp_MHD_AutoAllocation]
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success             INT,
           @n_Err                 INT,
           @c_ErrMsg              NVARCHAR(255),
           @n_Continue            INT,
           @n_StartTranCount      INT

   DECLARE  @c_Storerkey          NVARCHAR(15) 
           ,@c_Facility           NVARCHAR(5)
           ,@c_BatchNo            NVARCHAR(10)
           ,@c_Loadkey            NVARCHAR(10)
           ,@c_Orderkey           NVARCHAR(10)
           ,@d_OrderDate          DATETIME
           ,@d_Delivery_Date      DATETIME
           ,@c_OrderType          NVARCHAR(10)
           ,@c_Door               NVARCHAR(10)
           ,@c_Route              NVARCHAR(10)
           ,@c_DeliveryPlace      NVARCHAR(30)
           ,@c_OrderStatus        NVARCHAR(10)
           ,@c_Priority           NVARCHAR(10)
           ,@n_TotWeight          FLOAT
           ,@n_TotCube            FLOAT
           ,@n_TotOrdLine         INT
           ,@c_C_Company          NVARCHAR(45)
           ,@c_ExternOrderKey     NVARCHAR(50)  
           ,@c_ConsigneeKey       NVARCHAR(15)
           ,@c_pickslip_DW        NVARCHAR(50)
           ,@c_AllocateFull_DW    NVARCHAR(50)
           ,@c_AllocatePartial_DW NVARCHAR(50)
           ,@c_UserName           NVARCHAR(128)
           ,@d_MaxDelivery_Date   DATETIME  --NJOW02
           ,@n_NoOfDeliveryDay    INT = 0--NJOW02
           ,@n_DayCnt             INT = 0 --NJOW02
           ,@c_DELNOTE_DW         NVARCHAR(50)    --CS01
           ,@c_DNPRNUserName      NVARCHAR(128)   --CS01           
           ,@c_OrderLineNumber    NVARCHAR(5) --NJOW03
           ,@n_LooseQty           INT --NJOW03

   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT
   
   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN
  
   IF @n_continue IN(1,2)  --NJOW02
   BEGIN
       IF EXISTS(SELECT 1 
                 FROM HOLIDAYHEADER H (NOLOCK)
                 JOIN HOLIDAYDETAIL HD (NOLOCK) ON H.Holidaykey = HD.Holidaykey
                 WHERE H.Userdefine01 = 'MHD_AUTOALLOCATE'
                 AND DATEDIFF(Day, HD.HolidayDate, GetDate()) = 0) 
          --OR DATEPART(WEEKDAY, GETDATE()) IN (1,7)                     
       BEGIN
          GOTO QUIT_SP
       END                
       
     SELECT TOP 1 @n_NoOfDeliveryDay = CASE WHEN ISNUMERIC(H.Userdefine02) = 1 THEN CAST(H.Userdefine02 AS INT) ELSE 0 END
       FROM HOLIDAYHEADER H (NOLOCK)
       WHERE H.Userdefine01 = 'MHD_AUTOALLOCATE'
       ORDER BY H.Holidaykey
       
       IF ISNULL(@n_NoOfDeliveryDay,0) = 0
          SET @n_NoOfDeliveryDay = 2             
   END
  
   IF @n_continue IN(1,2)
   BEGIN    
      SET @c_Storerkey = 'MHD'
      SET @c_UserName = 'MHDALPRN'
      SET @c_AllocateFull_DW = 'r_dw_autoalloc_full'
      SET @c_AllocatePartial_DW = 'r_dw_autoalloc_partial'
      
      SELECT TOP 1 @c_pickslip_DW = PB_Datawindow
      FROM RCMREPORT (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND ReportType = 'PLISTN'
      ORDER BY EditDate DESC
      
      IF ISNULL(@c_pickslip_DW,'') = ''
         SET @c_pickslip_DW = 'r_dw_print_pickorder111'
                         
      CREATE TABLE #TMP_ORD (Rowid INT IDENTITY(1,1), 
                             Orderkey NVARCHAR(10),
                             Status NVARCHAR(10)
                             )      
                             
      --NJOW02
      WHILE @n_NoOfDeliveryDay > 0
      BEGIN
         IF DATEPART(WEEKDAY, GETDATE() + @n_DayCnt) IN (2,3,4,5,6) AND 
            NOT EXISTS (SELECT 1 
                          FROM HOLIDAYHEADER H (NOLOCK)
                          JOIN HOLIDAYDETAIL HD (NOLOCK) ON H.Holidaykey = HD.Holidaykey
                          WHERE H.Userdefine01 = 'MHD_AUTOALLOCATE'
                          AND DATEDIFF(Day, HD.HolidayDate, GetDate() + @n_DayCnt) = 0)  --workday
           BEGIN
              SET @d_MaxDelivery_Date = GETDATE() + @n_DayCnt
              SET @n_NoOfDeliveryDay =  @n_NoOfDeliveryDay - 1
           END                
         
         SET @n_DayCnt = @n_DayCnt + 1
      END                                         
      
      INSERT INTO #TMP_ORD (Orderkey, Status)
      SELECT O.Orderkey, '0'
      FROM ORDERS O (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND O.Status = '0'
      AND (O.Userdefine01 = '' OR O.Userdefine01 IS NULL)
      AND DATEDIFF(Day, O.DeliveryDate, @d_MaxDelivery_Date) >= 0 --NJOW02
      AND DATEPART(WEEKDAY, O.DeliveryDate) IN (2,3,4,5,6) --Must be weekday NJOW02
      AND NOT EXISTS (SELECT 1 
                        FROM HOLIDAYHEADER H (NOLOCK)
                        JOIN HOLIDAYDETAIL HD (NOLOCK) ON H.Holidaykey = HD.Holidaykey
                        WHERE H.Userdefine01 = 'MHD_AUTOALLOCATE'
                        AND DATEDIFF(Day, HD.HolidayDate, O.DeliveryDate) = 0) --Exclude public holiday NJOW02
      ORDER BY O.Priority, O.Orderkey   
      
      IF (SELECT COUNT(1) FROM #TMP_ORD) > 0
      BEGIN
         SET @c_BatchNo = ''
         EXEC dbo.nspg_GetKey                
             @KeyName = 'MHDALBTH'    
            ,@fieldlength = 10    
            ,@keystring = @c_BatchNo OUTPUT    
            ,@b_Success = @b_success OUTPUT    
            ,@n_err = @n_err OUTPUT    
            ,@c_errmsg = @c_errmsg OUTPUT
            ,@b_resultset = 0    
            ,@n_batch     = 1    
            
         IF @b_Success <> 1
            SET @n_continue = 3                       
      END   
   END   
   
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT TM.Orderkey, O.Facility, O.Loadkey, O.Consigneekey
        FROM #TMP_ORD TM
        JOIN ORDERS O (NOLOCK) ON TM.Orderkey = O.Orderkey
        ORDER BY TM.RowID
      
      OPEN CUR_ORD
      
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Facility, @c_Loadkey, @c_Consigneekey
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN        
      	 --NJOW03 S         	
      	 IF @c_Consigneekey = '0003205382'
      	 BEGIN
      	 	  DECLARE CUR_LOOSE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      	 	     SELECT OD.OrderLineNumber, OD.OpenQty % CAST(PACK.InnerPack AS INT) AS LooseQty
      	 	     FROM ORDERDETAIL OD (NOLOCK)
      	 	     JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      	 	     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      	 	     WHERE OD.Orderkey = @c_Orderkey
      	 	     AND OD.OpenQty % CAST(PACK.InnerPack AS INT) > 0
      	 	     AND OD.QtyAllocated + OD.QtyPicked = 0
      	 	     AND FLOOR(PACK.InnerPack) > 0
      	 	     ORDER BY OD.OrderLineNumber

            OPEN CUR_LOOSE
      
            FETCH NEXT FROM CUR_LOOSE INTO @c_OrderLineNumber, @n_LooseQty

            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
            BEGIN            
            	 UPDATE ORDERDETAIL WITH (ROWLOCK)
            	 SET OpenQty = OpenQty - @n_LooseQty,
            	     Userdefine10 = CAST(@n_LooseQty AS NVARCHAR),
            	     Userdefine09 = 'LOOSE'
            	 WHERE Orderkey = @c_Orderkey
            	 AND OrderLineNumber = @c_OrderLineNumber    

               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63200
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Orderdetail Table Failed! (isp_MHD_AutoAllocation)' + ' ( '
                                 + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END            
            	 
               FETCH NEXT FROM CUR_LOOSE INTO @c_OrderLineNumber, @n_LooseQty            	     	
            END     
            CLOSE CUR_LOOSE
            DEALLOCATE CUR_LOOSE 	 	           	 	     
      	 END
      	 --NJOW03 E
      	        	       	
         --update batch no to order                   
         UPDATE ORDERS WITH (ROWLOCK)
         SET Userdefine01 = @c_BatchNo,
             Trafficcop = NULL
         WHERE Orderkey = @c_Orderkey
         
         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63210
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Order Table Failed! (isp_MHD_AutoAllocation)' + ' ( '
                           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END            
               
         EXEC nsp_orderprocessing_wrapper
            @c_OrderKey = @c_Orderkey,
            @c_oskey = '',
            @c_docarton = 'N',
            @c_doroute = 'N',
            @c_tblprefix= '',
            @c_Extendparms = '',
            @c_StrategykeyParm = ''

      	 --NJOW03 S         	
      	 IF @c_Consigneekey = '0003205382'
      	 BEGIN
      	 	  DECLARE CUR_LOOSE2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      	 	     SELECT OD.OrderLineNumber, CAST(OD.Userdefine10 AS INT)
      	 	     FROM ORDERDETAIL OD (NOLOCK)
      	 	     WHERE OD.Orderkey = @c_Orderkey
      	 	     AND OD.Userdefine09 = 'LOOSE'
      	 	     AND ISNUMERIC(OD.Userdefine10) = 1
      	 	     ORDER BY OD.OrderLineNumber

            OPEN CUR_LOOSE2
      
            FETCH NEXT FROM CUR_LOOSE2 INTO @c_OrderLineNumber, @n_LooseQty

            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
            BEGIN            
            	 UPDATE ORDERDETAIL WITH (ROWLOCK)
            	 SET OpenQty = OpenQty + @n_LooseQty,
            	     Userdefine10 = '',
            	     Userdefine09 = ''
            	 WHERE Orderkey = @c_Orderkey
            	 AND OrderLineNumber = @c_OrderLineNumber    

               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63220
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Orderdetail Table Failed! (isp_MHD_AutoAllocation)' + ' ( '
                                 + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END            
            	 
               FETCH NEXT FROM CUR_LOOSE2 INTO @c_OrderLineNumber, @n_LooseQty            	     	
            END     
            CLOSE CUR_LOOSE2
            DEALLOCATE CUR_LOOSE2 	 	           	 	     
      	 END
      	 --NJOW03 E            
             
         SET @c_OrderStatus = '0'
         SELECT @c_OrderStatus = Status
         FROM ORDERS(NOLOCK)
         WHERE Orderkey = @c_Orderkey
         
         UPDATE #TMP_ORD 
         SET Status = @c_OrderStatus 
         WHERE Orderkey = @c_Orderkey
         
         --create load plan per order
         IF ISNULL(@c_Loadkey,'') = '' -- AND @c_OrderStatus = '2'
         BEGIN     
            EXEC dbo.nspg_GetKey                
                 @KeyName = 'LOADKEY'    
                ,@fieldlength = 10    
                ,@keystring = @c_Loadkey OUTPUT    
                ,@b_Success = @b_success OUTPUT    
                ,@n_err = @n_err OUTPUT    
                ,@c_errmsg = @c_errmsg OUTPUT
                ,@b_resultset = 0    
                ,@n_batch     = 1          
            
            IF @b_Success <> 1
               SET @n_continue = 3    
            
              INSERT INTO LoadPlan(LoadKey, Facility, UserDefine10)
               VALUES(@c_LoadKey, @c_Facility, @c_BatchNo)
            
              IF @n_err <> 0
              BEGIN
                 SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63230
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert LoadPlan Table Failed! (isp_MHD_AutoAllocation)' + ' ( '
                              + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END            
                       
            SELECT @d_OrderDate = O.OrderDate,
                   @d_Delivery_Date = O.DeliveryDate,
                   @c_OrderType = O.Type,
                   @c_Door = O.Door,
                   @c_Route = O.Route,
                   @c_DeliveryPlace = O.DeliveryPlace,
                   @c_OrderStatus = O.Status,
                   @c_priority = O.Priority,
                   @n_totweight = SUM(OD.OpenQty * SKU.StdGrossWgt),
                   @n_totcube = SUM(OD.OpenQty * SKU.StdCube),
                   @n_TotOrdLine = COUNT(DISTINCT OD.OrderLineNumber),
                   @c_C_Company = O.C_Company,
                   @c_ExternOrderkey = O.ExternOrderkey,
                   @c_Consigneekey = O.Consigneekey
            FROM Orders O WITH (NOLOCK)
            JOIN Orderdetail OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
            JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)
            WHERE O.OrderKey = @c_OrderKey
            GROUP BY O.OrderDate,
                     O.DeliveryDate,
                     O.Type,
                     O.Door,
                     O.Route,
                     O.DeliveryPlace,
                     O.Status,
                     O.Priority,
                     O.C_Company,
                     O.ExternOrderkey,
                     O.Consigneekey
            
            EXEC isp_InsertLoadplanDetail
                 @cLoadKey          = @c_LoadKey,
                 @cFacility         = @c_Facility,
                 @cOrderKey         = @c_OrderKey,
                 @cConsigneeKey     = @c_Consigneekey,
                 @cPrioriry         = @c_Priority,
                 @dOrderDate        = @d_OrderDate,
                 @dDelivery_Date    = @d_Delivery_Date,
                 @cOrderType        = @c_OrderType,
                 @cDoor             = @c_Door,
                 @cRoute            = @c_Route,
                 @cDeliveryPlace    = @c_DeliveryPlace,
                 @nStdGrossWgt      = @n_totweight,
                 @nStdCube          = @n_totcube,
                 @cExternOrderKey   = @c_ExternOrderKey,
                 @cCustomerName     = @c_C_Company,
                 @nTotOrderLines    = @n_TotOrdLine,
                 @nNoOfCartons      = 0,
                 @cOrderStatus      = @c_OrderStatus,
                 @b_Success         = @b_Success OUTPUT,
                 @n_err             = @n_err     OUTPUT,
                 @c_errmsg          = @c_errmsg  OUTPUT
                 
            IF @b_Success <> 1
               SET @n_continue = 3        
         END
                     
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Facility, @c_Loadkey, @c_Consigneekey
      END         
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END
   
   --Print fully allocate report
   IF EXISTS(SELECT 1 FROM #TMP_ORD WHERE Status = '2')
   BEGIN
      EXEC isp_PrintToRDTSpooler 
           @c_ReportType     = 'AUTOALRPT',
           @c_Storerkey      = @c_Storerkey,
           @b_success        = @b_Success OUTPUT,
           @n_err            = @n_err OUTPUT,
           @c_errmsg         = @c_errmsg OUTPUT,
           @n_Noofparam      = 2,
           @c_Param01        = @c_Storerkey,        
           @c_Param02        = @c_BatchNo,        
           @c_UserName       = @c_UserName,
           @c_Facility       = @c_Facility,
           @c_PrinterID      = '',
           @c_Datawindow     = @c_AllocateFull_DW,
           @c_IsPaperPrinter = 'Y', 
           @c_JobType        = 'TCPSPOOLER',
           @n_Function_ID    = 999
   END

   IF EXISTS(SELECT 1 FROM #TMP_ORD WHERE Status < '2')
   BEGIN
      EXEC isp_PrintToRDTSpooler 
           @c_ReportType     = 'AUTOALRPT',
           @c_Storerkey      = @c_Storerkey,
           @b_success        = @b_Success OUTPUT,
           @n_err            = @n_err OUTPUT,
           @c_errmsg         = @c_errmsg OUTPUT,
           @n_Noofparam      = 2,
           @c_Param01        = @c_Storerkey,        
           @c_Param02        = @c_BatchNo,        
           @c_UserName       = @c_UserName,
           @c_Facility       = @c_Facility,
           @c_PrinterID      = '',
           @c_Datawindow     = @c_AllocatePartial_DW,
           @c_IsPaperPrinter = 'Y', 
           @c_JobType        = 'TCPSPOOLER',
           @n_Function_ID    = 999
   END
   
   --Print pickslip   
   DECLARE CUR_PICKSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT O.Loadkey, O.Facility
      FROM #TMP_ORD TM
      JOIN ORDERS O (NOLOCK) ON TM.Orderkey = O.Orderkey
      AND O.Status = '2'
      ORDER BY O.Loadkey
   
    OPEN CUR_PICKSLIP                                                                       
                                                                                       
    FETCH NEXT FROM CUR_PICKSLIP INTO @c_Loadkey, @c_Facility
                                                                                       
    WHILE @@FETCH_STATUS <> -1                                
    BEGIN                            
        EXEC isp_PrintToRDTSpooler 
           @c_ReportType     = 'PLISTN',
           @c_Storerkey      = @c_Storerkey,
           @b_success        = @b_Success OUTPUT,
           @n_err            = @n_err OUTPUT,
           @c_errmsg         = @c_errmsg OUTPUT,
           @n_Noofparam      = 1,
           @c_Param01        = @c_Loadkey,        
           @c_UserName       = @c_UserName,
           @c_Facility       = @c_Facility,
           @c_PrinterID      = '',
           @c_Datawindow     = @c_Pickslip_DW,
           @c_IsPaperPrinter = 'Y', 
           @c_JobType        = 'TCPSPOOLER',
           @n_Function_ID    = 999
          
       FETCH NEXT FROM CUR_PICKSLIP INTO @c_Loadkey, @c_Facility                                                                                 
    END
    CLOSE CUR_PICKSLIP
    DEALLOCATE CUR_PICKSLIP    

    --CS01 S
   --Print delivery note   

    SET @c_DNPRNUserName = 'MHDDNPRN'

    SELECT TOP 1 @c_DELNOTE_DW = PB_Datawindow
      FROM RCMREPORT (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND ReportType = 'DELNOTECTN'
      ORDER BY EditDate DESC
      
      IF ISNULL(@c_DELNOTE_DW,'') = ''
         SET @c_DELNOTE_DW = 'r_dw_delivery_note60'

   DECLARE CUR_DN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT O.OrderKey, O.Facility
      FROM #TMP_ORD TM
      JOIN ORDERS O (NOLOCK) ON TM.Orderkey = O.Orderkey
      AND O.Status = '2'
      ORDER BY O.OrderKey
   
    OPEN CUR_DN                                                                       
                                                                                       
    FETCH NEXT FROM CUR_DN INTO @c_Orderkey, @c_Facility
                                                                                       
    WHILE @@FETCH_STATUS <> -1                                
    BEGIN                            
        EXEC isp_PrintToRDTSpooler 
           @c_ReportType     = 'DELNOTECTN',
           @c_Storerkey      = @c_Storerkey,
           @b_success        = @b_Success OUTPUT,
           @n_err            = @n_err OUTPUT,
           @c_errmsg         = @c_errmsg OUTPUT,
           @n_Noofparam      = 1,
           @c_Param01        = @c_Orderkey,        
           @c_UserName       = @c_DNPRNUserName,
           @c_Facility       = @c_Facility,
           @c_PrinterID      = '',
           @c_Datawindow     = @c_DELNOTE_DW,
           @c_IsPaperPrinter = 'Y', 
           @c_JobType        = 'TCPSPOOLER',
           @n_Function_ID    = 999
          
       FETCH NEXT FROM CUR_DN INTO @c_Orderkey, @c_Facility                                                                                   
    END
    CLOSE CUR_DN
    DEALLOCATE CUR_DN  

    --CS01 E
      
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_MHD_AutoAllocation'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO