SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Delivery_Receipt05                             */  
/* Creation Date: 28-Jan-2019                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-7782 - [PH] Alcon - DR Modification                     */  
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
/* Date         Author   Ver. Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Delivery_Receipt05] (@cMBOLkey NVARCHAR(10) )  
AS  
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  
 DECLARE  @cExternOrderKey NVARCHAR(30)  
         ,@cStorerkey      NVARCHAR(15)  
         ,@cUserdefine10   NVARCHAR(10)  
         ,@cDRCounterKey   NVARCHAR(10)  
         ,@cCurrExternKey  NVARCHAR(30)  
         ,@cPrevExternKey  NVARCHAR(30)  
         ,@cCurrSKU        NVARCHAR(20)  
         ,@cPrevSKU        NVARCHAR(20)  
         ,@nSeqNum         int  
         ,@nTotalOrderQty  int  
         ,@cPrintFlag      NVARCHAR(1)  
         ,@nRecCnt         int 
		 ,@cAllowZeroQTY   NVARCHAR(1) 
  
 DECLARE  @n_err           int  
         ,@n_continue      int  
         ,@b_success       int  
         ,@c_errmsg        NVARCHAR(255)  
         ,@n_starttcnt     int  
         ,@b_debug         int  
  
 CREATE TABLE #TempFlag (      
  ExternOrderkey [nvarchar] (30) NULL,      
  PrintFlag      [nchar] (1)  NULL )  
  
  
  Create Clustered index [PK_tempFlag] on #TempFlag (ExternOrderkey)  

 DECLARE @TempData TABLE (  
         MBOLKey         [nvarchar] (10) NULL,  
         UserDefine10    [nvarchar] (10) NULL,  
         ExternOrderKey  [nvarchar] (30) NULL,  
         PrintFlag       [nvarchar] (1)  NULL,  
         Consigneekey    [nvarchar] (15) NULL,  
         C_Company       [nvarchar] (45) NULL,  
         C_Address1      [nvarchar] (45) NULL,  
         C_Address2      [nvarchar] (45) NULL,  
         C_Address3      [nvarchar] (45) NULL,  
         C_Address4      [nvarchar] (45) NULL,  
         C_City          [nvarchar] (45) NULL,  
         C_Country       [nvarchar] (30) NULL,  
         BuyerPO         [nvarchar] (20) NULL,  
         OrderDate       [datetime]  NULL,  
         DeliveryDate    [datetime]  NULL,  
         DepartureDate   [datetime]  NULL,  
         CarrierAgent    [nvarchar] (30) NULL,  
         VesselQualifier [nvarchar] (10) NULL,  
         DriverName      [nvarchar] (30) NULL,  
         Vessel          [nvarchar] (30) NULL,  
         OtherReference  [nvarchar] (30) NULL,  
         SKU             [nvarchar] (20) NULL,  
         SkuDescr        [nvarchar] (60) NULL,  
         Company         [nvarchar] (45) NULL,  
         Lot02           [nvarchar] (18) NULL,  
         ShippedQty      [decimal] (12,2) NULL,  
         DRDate          [datetime]  NULL,
         Lot01           [nvarchar] (18) NULL,
         Lot04           [nvarchar] (50)  NULL,
         Remark          [nvarchar] (250) NULL,
         QtyEA           [int]       NULL,
         QtyInner        [decimal] (12,2) NULL,
         QtyCtn          [decimal] (12,2) NULL,
         UOM             [nvarchar] (10) NULL,
         Billtokey       [nvarchar] (15) NULL,
         b_Company       [nvarchar] (45) NULL,
         b_Address1      [nvarchar] (45) NULL,
         b_Address2      [nvarchar] (45) NULL,
         Shippedby       [nvarchar] (250) NULL,
		 Lot06           [nvarchar] (18) NULL,
		 AllowZeroQty    [nvarchar] (1) NULL,
		 TariffKey       [nvarchar] (20) NULL,
		 ExternPOKey     [nvarchar] (40) NULL,
		 OrdDetNotes     [nvarchar] (250) NULL,
		 AltSku          [nvarchar] (40) NULL)  
  
 SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_debug = 0, @n_err = 0  
 SET @cPrintFlag = ''  
 SET @cAllowZeroQTY = ''
  
   SELECT @nRecCnt = COUNT(1) FROM ORDERS (NOLOCK)   
   WHERE MBOLKey = @cMBOLkey  

 IF @nRecCnt <= 0  
 BEGIN  
  SELECT @n_continue = 4  
  IF @b_debug = 1  
   PRINT 'No Data Found'  
 END  
 ELSE  
  IF @b_debug = 1  
   PRINT 'Start Processing...  MBOLKey=' + @cMBOLkey  
  
 -- Assign DR Number (at externorderkey level) to all orders under this MBOLKey!   
 IF @n_continue = 1 OR @n_continue = 2  
 BEGIN  
  DECLARE CurExternOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT StorerKey, ExternOrderkey, UserDefine10  
  FROM ORDERS (NOLOCK)   
  WHERE MBOLKey = @cMBOLkey  
  GROUP BY StorerKey, ExternOrderkey, UserDefine10  
  ORDER BY ExternOrderkey  
    
      OPEN CurExternOrder   
      FETCH NEXT FROM CurExternOrder INTO @cStorerkey, @cExternOrderKey, @cUserDefine10  
  
      WHILE @@FETCH_STATUS <> -1 -- CurExternOrder Loop   
  BEGIN  
   IF @b_debug = 1  
    PRINT 'Storerkey=' + @cStorerkey +' ;ExternOrderKey=' + @cExternOrderKey  + ' ;UserDefine10' + @cUserDefine10  
  
     IF ISNULL(@cUserDefine10,'') = ''  
   BEGIN     
    SET @cPrintFlag = 'N'  
    SET @cDRCounterKey = ''  
  
    SELECT @cDRCounterKey = Code  
    FROM CodeLkUp (NOLOCK)  
      WHERE ListName = 'DR_NCOUNT'  
    AND SHORT = @cStorerkey  
  
    IF @cDRCounterKey = ''  
    BEGIN  
     SELECT @n_continue = 3  
     SELECT @n_err = 63500  -- should assign new error code  
     SELECT @c_errmsg="NSQL"+CONVERT(nvarchar(5),@n_err)+": No Setup for CodeLkUp.ListName = DR_NCOUNT. (isp_Delivery_Receipt05)"  
    END  

    IF @b_debug = 1  
     PRINT 'Check this: SELECT Code FROM CodeLkUp (NOLOCK) WHERE ListName = ''DR_NCOUNT'' AND SHORT =N''' + dbo.fnc_RTrim(@cStorerkey) + ''''  


  
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
     SELECT @b_success = 0  
     
     EXECUTE nspg_GetKey @cDRCounterKey, 10,   
       @cUserDefine10 OUTPUT,  
       @b_success    OUTPUT,  
       @n_err     OUTPUT,  
       @c_errmsg     OUTPUT  
     
     IF @b_debug = 1  
      PRINT ' GET UserDefine10 (DR)= ' + @cUserDefine10 + master.dbo.fnc_GetCharASCII(13)  
    
     IF @b_success <> 1  
     BEGIN  
      SELECT @n_continue = 3  
      SELECT @n_err = 63500  -- should assign new error code  
      SELECT @c_errmsg="NSQL"+CONVERT(nvarchar(5),@n_err)+": Fail to Generate Userdeine10 . (isp_Delivery_Receipt05)"  
     END  
     ELSE  
      BEGIN  
      UPDATE ORDERS   
      SET UserDefine10 = @cUserDefine10,  
                      UserDefine07 = GetDate()   
      WHERE MBOLKey = @cMBOLKey  
      AND StorerKey = @cStorerKey  
      AND  ExternOrderKey = @cExternOrderKey  
            
      SELECT @n_err = @@ERROR  
      
      IF @n_err <> 0   
      BEGIN  
       SELECT @n_continue = 3  
       SELECT @n_err = 63501  -- should assign new error code  
       SELECT @c_errmsg="NSQL"+CONVERT(nvarchar(5),@n_err)+": UPDATE ORDERS Failed. (isp_Delivery_Receipt05)"  
      END  
     END  
    END  -- @n_continue = 1 or @n_continue = 2  
   END  
   ELSE  
   BEGIN  
    SET @cPrintFlag = 'Y'  
   END      
  
   INSERT INTO #TempFlag(PrintFlag, ExternOrderKey)    
   VALUES(@cPrintFlag, @cExternOrderKey)  

   FETCH NEXT FROM CurExternOrder INTO @cStorerkey, @cExternOrderKey, @cUserDefine10 
  END  
    
  CLOSE CurExternOrder  
      DEALLOCATE CurExternOrder   
 END -- @nRecCnt > 0  
  
 IF @b_debug = 1 SELECT * FROM #TempFlag  
  
 -- Insert into @TempData table  
 IF @n_continue = 1 OR @n_continue = 2   
 BEGIN   
  INSERT INTO @TempData  
  SELECT   
   ORDERS.MBOLKey,  
   ORDERS.UserDefine10,  
   ORDERS.ExternOrderKey,  
   T.PrintFlag,  
   ORDERS.Consigneekey,  
   ORDERS.C_Company,  
   ISNULL(ORDERS.C_Address1,''),   
   ISNULL(ORDERS.C_Address2,''),   
   ISNULL(ORDERS.C_Address3,''),  
   ISNULL(ORDERS.C_Address4,''),  
   ISNULL(ORDERS.C_City,''),  
   ISNULL(ORDERS.C_Country,''),  
   ORDERS.BuyerPO,  
   ORDERS.OrderDate,  
   ORDERS.DeliveryDate,  
   MBOL.DepartureDate,  
   MBOL.CarrierAgent,  
   MBOL.VesselQualifier,  
   MBOL.DriverName,  
   MBOL.Vessel,  
   MBOL.OtherReference,  
   ORDERDETAIL.SKU,  
   SKU.Descr AS SkuDescr,  
   STORER.Company,  
   LOTATTRIBUTE.Lottable02 AS Lot02,  
   CONVERT(DECIMAL(12,2),SUM(Pickdetail.Qty) / (CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN PACK.CaseCnt   
                               WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN PACK.InnerPack  
                               ELSE 1 END)) As ShippedQty,  
         MBOL.EditDate,         
   '' AS Lot01,
   CONVERT(NVARCHAR, LOTATTRIBUTE.LOTTABLE04,104) AS Lot04,
   Orders.Notes AS Remark,
   CONVERT(DECIMAL(12,2),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN 0   
                              WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN 0  
                              ELSE SUM(Pickdetail.Qty) END) As QtyEA,  
   CONVERT(DECIMAL(12,2),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN 0   
                              WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN SUM(Pickdetail.Qty) / PACK.InnerPack  
                              ELSE 0 END) As QtyInner,  
   CONVERT(DECIMAL(12,2),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN SUM(Pickdetail.Qty) / PACK.CaseCnt   
                              WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN 0  
                              ELSE 0 END) As QtyCtn,  
   ORDERDETAIL.UOM,
   ISNULL(ORDERS.Billtokey,''),  
   ISNULL(ORDERS.b_Company,''),  
   ISNULL(ORDERS.b_Address1,''),   
   ISNULL(ORDERS.b_Address2,''),
   LEFT(ISNULL(CL2.Notes,''), 250),
   LOTATTRIBUTE.Lottable06 AS Lot06,
   ISNULL(CL3.SHORT,'') AS AllowZeroQty,
   ORDERDETAIL.TariffKey,
   ORDERS.ExternPOKey,
   ORDERDETAIL.Notes,
   ORDERDETAIL.AltSku
  FROM ORDERS (NOLOCK)  
  JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = OrderDetail.OrderKey  
  JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey  
  JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey  
  JOIN SKU (NOLOCK) ON SKU.SKU = OrderDetail.SKU AND SKU.Storerkey = OrderDetail.Storerkey --NJOW03
  JOIN MBOL (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey   
  JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey   
           AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)   
  JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.lot = LOTATTRIBUTE.LOT  
  JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.PackKey     
  LEFT OUTER JOIN #TempFlag T ON T.ExternOrderkey = ORDERS.ExternOrderkey  -- tlting01
  LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON (ORDERS.Storerkey = CL.Short AND 'DR_'+ORDERS.Storerkey = CL.Code AND CL.Listname = 'DR_NCOUNT')
  LEFT OUTER JOIN CODELKUP CL2 (NOLOCK) ON (ORDERS.Storerkey = CL2.Code AND CL2.Listname = 'Storer')
  LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (ORDERS.Storerkey = CL3.Storerkey AND CL3.Listname = 'REPORTCFG' AND CL3.LONG = 'r_dw_delivery_receipt05' 
                                            AND CL3.CODE = 'AllowZeroQty' AND CL3.SHORT IN ('Y','N') )
  WHERE ORDERS.MBOLKEY = @cMBOLKey  AND ORDERDETAIL.SHIPPEDQTY <> 0
  AND ORDERS.Status >= '5'
  GROUP BY ORDERS.MBOLKey,  
           ORDERS.UserDefine10,  
           ORDERS.ExternOrderKey,  
           T.PrintFlag,  
           ORDERS.Consigneekey,  
           ORDERS.C_Company,  
           ISNULL(ORDERS.C_Address1,''),   
           ISNULL(ORDERS.C_Address2,''),   
           ISNULL(ORDERS.C_Address3,''),  
           ISNULL(ORDERS.C_Address4,''),  
           ISNULL(ORDERS.C_City,''),  
           ISNULL(ORDERS.C_Country,''),  
           ORDERS.BuyerPO,  
           ORDERS.OrderDate,  
           ORDERS.DeliveryDate,  
           MBOL.DepartureDate,  
           MBOL.CarrierAgent,  
           MBOL.VesselQualifier,  
           MBOL.DriverName,  
           MBOL.Vessel,  
           MBOL.OtherReference,  
           ORDERDETAIL.SKU,  
           SKU.Descr,  
           STORER.Company,  
           LOTATTRIBUTE.Lottable02,  
           ORDERDETAIL.UOM,  
           PACK.PackUOM1,  
           PACK.PackUOM2,  
           PACK.CaseCnt,  
           PACK.InnerPack,  
           MBOL.EditDate,  
           LOTATTRIBUTE.Lottable04,
           Orders.Notes,
           ISNULL(ORDERS.Billtokey,''),  
           ISNULL(ORDERS.b_Company,''),  
           ISNULL(ORDERS.b_Address1,''),   
           ISNULL(ORDERS.b_Address2,''),
           LEFT(ISNULL(CL2.Notes,''), 250),
		   LOTATTRIBUTE.Lottable06,  
		   ISNULL(CL3.SHORT,''),
		   ORDERDETAIL.TariffKey,
		   ORDERS.ExternPOKey,
		   ORDERDETAIL.Notes,
		   ORDERDETAIL.AltSku
	UNION ALL 
	SELECT   
		   ORDERS.MBOLKey,  
		   ORDERS.UserDefine10,  
		   ORDERS.ExternOrderKey,  
		   T.PrintFlag,  
		   ORDERS.Consigneekey,  
		   ORDERS.C_Company,  
		   ISNULL(ORDERS.C_Address1,''),   
		   ISNULL(ORDERS.C_Address2,''),   
		   ISNULL(ORDERS.C_Address3,''),  
		   ISNULL(ORDERS.C_Address4,''),  
		   ISNULL(ORDERS.C_City,''),  
		   ISNULL(ORDERS.C_Country,''),  
		   ORDERS.BuyerPO,  
		   ORDERS.OrderDate,  
		   ORDERS.DeliveryDate,  
		   MBOL.DepartureDate,  
		   MBOL.CarrierAgent,  
		   MBOL.VesselQualifier,  
		   MBOL.DriverName,  
		   MBOL.Vessel,  
		   MBOL.OtherReference,  
		   ORDERDETAIL.SKU,  
		   SKU.Descr AS SkuDescr,   
		   STORER.Company,  
		   '' AS Lot02,  
		   0 As ShippedQty,  
		   MBOL.EditDate,         
		   '' AS Lot01,
		   '00.00.0000' AS Lot04,
		   Orders.Notes AS Remark,
		   0 As QtyEA,  
		   0 As QtyInner,  
		   0 As QtyCtn,  
		   ORDERDETAIL.UOM,
		   ISNULL(ORDERS.Billtokey,''),  
		   ISNULL(ORDERS.b_Company,''),  
		   ISNULL(ORDERS.b_Address1,''),   
		   ISNULL(ORDERS.b_Address2,''),
		   LEFT(ISNULL(CL2.Notes,''), 250),
		   '' AS Lot06,
		   ISNULL(CL3.SHORT,'') AS AllowZeroQty,
		   ORDERDETAIL.TariffKey,
		   ORDERS.ExternPOKey,
		   ORDERDETAIL.Notes,
		   ORDERDETAIL.AltSku
		  FROM ORDERS (NOLOCK)  
		  JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = OrderDetail.OrderKey  
		  JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey  
		  JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey  
		  JOIN SKU (NOLOCK) ON SKU.SKU = OrderDetail.SKU AND SKU.Storerkey = OrderDetail.Storerkey --NJOW03
		  JOIN MBOL (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey   
		  --JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey   
			--	   AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)   
		  --JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.lot = LOTATTRIBUTE.LOT  
		  JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.PackKey     
		  LEFT OUTER JOIN #TempFlag T ON T.ExternOrderkey = ORDERS.ExternOrderkey  -- tlting01
		  LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON (ORDERS.Storerkey = CL.Short AND 'DR_'+ORDERS.Storerkey = CL.Code AND CL.Listname = 'DR_NCOUNT')
		  LEFT OUTER JOIN CODELKUP CL2 (NOLOCK) ON (ORDERS.Storerkey = CL2.Code AND CL2.Listname = 'Storer')
		  LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (ORDERS.Storerkey = CL3.Storerkey AND CL3.Listname = 'REPORTCFG' AND CL3.LONG = 'r_dw_delivery_receipt05' 
													AND CL3.CODE = 'AllowZeroQty' AND CL3.SHORT IN ('Y','N') )
		  WHERE ORDERS.MBOLKEY = @cMBOLKey  AND ORDERDETAIL.SHIPPEDQTY = 0
		  AND ORDERS.Status >= '5'
		  GROUP BY ORDERS.MBOLKey,  
				   ORDERS.UserDefine10,  
				   ORDERS.ExternOrderKey,  
				   T.PrintFlag,  
				   ORDERS.Consigneekey,  
				   ORDERS.C_Company,  
				   ISNULL(ORDERS.C_Address1,''),   
				   ISNULL(ORDERS.C_Address2,''),   
				   ISNULL(ORDERS.C_Address3,''),  
				   ISNULL(ORDERS.C_Address4,''),  
				   ISNULL(ORDERS.C_City,''),  
				   ISNULL(ORDERS.C_Country,''),  
				   ORDERS.BuyerPO,  
				   ORDERS.OrderDate,  
				   ORDERS.DeliveryDate,  
				   MBOL.DepartureDate,  
				   MBOL.CarrierAgent,  
				   MBOL.VesselQualifier,  
				   MBOL.DriverName,  
				   MBOL.Vessel,  
				   MBOL.OtherReference,  
				   ORDERDETAIL.SKU,  
				   SKU.Descr,  
				   STORER.Company,  
				   ORDERDETAIL.UOM,  
				   PACK.PackUOM1,  
				   PACK.PackUOM2,  
				   PACK.CaseCnt,  
				   PACK.InnerPack,  
				   MBOL.EditDate,  
				   Orders.Notes,
				   ISNULL(ORDERS.Billtokey,''),  
				   ISNULL(ORDERS.b_Company,''),  
				   ISNULL(ORDERS.b_Address1,''),   
				   ISNULL(ORDERS.b_Address2,''),
				   LEFT(ISNULL(CL2.Notes,''), 250), 
				   ISNULL(CL3.SHORT,''),
				   ORDERDETAIL.TariffKey,
				   ORDERS.ExternPOKey,
				   ORDERDETAIL.Notes,
				   ORDERDETAIL.AltSku                              
		   ORDER BY ORDERS.ExternOrderKey,   
					ORDERS.UserDefine10,   
					ORDERDETAIL.SKU,   
					LOTATTRIBUTE.Lottable02  
 END  

 --Get Codelkup.Short value from TempData
 SELECT TOP 1 @cAllowZeroQTY = AllowZeroQty
 FROM @TempData
  
 IF ( (@n_continue = 1 OR @n_continue = 2) AND (ISNULL(@cAllowZeroQTY,'') <> '' AND ISNULL(@cAllowZeroQTY,'') = 'N') )
 BEGIN
  SELECT * FROM @TempData WHERE ShippedQty > 0  
  --SELECT 'N'
 END

 IF ( (@n_continue = 1 OR @n_continue = 2) AND (ISNULL(@cAllowZeroQTY,'') <> '' AND ISNULL(@cAllowZeroQTY,'') = 'Y') )
 BEGIN
  SELECT * FROM @TempData WHERE ShippedQty >= 0 
  --SELECT 'Y'
 END

 IF ( (@n_continue = 1 OR @n_continue = 2) AND (ISNULL(@cAllowZeroQTY,'') = '' AND ISNULL(@cAllowZeroQTY,'') NOT IN ('Y','N')) )
 BEGIN
  SELECT * FROM @TempData
  --SELECT 'NO SETUP'
 END
  -- SELECT * FROM @TempData

 IF @n_continue=3  -- Error Occured - Process And Return  
 BEGIN  
  EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_Delivery_Receipt05"  
  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  RETURN  
 END  
 ELSE  
 BEGIN  
  SELECT @b_success = 1  
  WHILE @@TRANCOUNT > @n_starttcnt  
  BEGIN  
   COMMIT TRAN  
  END  
  RETURN  
 END  
  
END /* main procedure */  


GO