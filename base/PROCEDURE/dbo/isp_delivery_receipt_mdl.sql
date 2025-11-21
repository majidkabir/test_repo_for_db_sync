SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Delivery_Receipt_MDL                           */  
/* Creation Date: 19/02/2019                                            */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose: WMS-8031 - PH_New Delivery Receipt(DR)                      */
/*                     Document format for Mondelez                     */
/*          Copy from isp_Delivery_Receipt_MDL                          */  
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
  
CREATE PROC [dbo].[isp_Delivery_Receipt_MDL] (@cMBOLkey NVARCHAR(10) )  
AS  
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  
 DECLARE @cExternOrderKey  NVARCHAR(30)  
      ,  @cStorerkey       NVARCHAR(15)  
      ,  @cUserdefine10    NVARCHAR(10)  
      ,  @cDRCounterKey    NVARCHAR(10)  
      ,  @cCurrExternKey   NVARCHAR(30)  
      ,  @cPrevExternKey   NVARCHAR(30)  
      ,  @cCurrSKU         NVARCHAR(20)  
      ,  @cPrevSKU         NVARCHAR(20)  
      ,  @nSeqNum          int  
      ,  @nTotalOrderQty   int  
      ,  @cPrintFlag       NVARCHAR(1)  
      ,  @nRecCnt          int  
  
 DECLARE @n_err            int  
      ,  @n_continue       int  
      ,  @b_success        int  
      ,  @c_errmsg         NVARCHAR(255)  
      ,  @n_starttcnt      int  
      ,  @b_debug          int  
      ,  @n_ConvertToKg    INT                                 --(Wan01)            
      ,  @c_Storerkey_Prev NVARCHAR(15)                        --(Wan01)

 
  -- tlting01 - change Memory table to temp table
 CREATE TABLE #TempFlag (      
         ExternOrderkey    [NVARchar]  (30)  NULL,      
         PrintFlag         [char]      (1)   NULL,
         Storerkey         [NVARCHAR]  (15)  NULL,             --(Wan01)           
         ConverttoKG       [INT]             NULL DEFAULT (0)  --(Wan01)
         )  
  
  
  Create Clustered index [PK_tempFlag] on #TempFlag (ExternOrderkey)  -- tlting01

  DECLARE @TempData TABLE (  
         MBOLKey           [char] (10) NULL,  
         UserDefine10      [char] (10) NULL,  
         ExternOrderKey    [char] (30) NULL,  
         PrintFlag         [char] (1)  NULL,  
         Consigneekey      [char] (15) NULL,  
         C_Company         [char] (45) NULL,  
         C_Address1        [char] (45) NULL,  
         C_Address2        [char] (45) NULL,  
         C_Address3        [char] (45) NULL,  
         C_Address4        [char] (45) NULL,  
         C_City            [char] (45) NULL,  
         C_Country         [char] (30) NULL,  
         BuyerPO           [char] (20) NULL,  
         OrderDate         [datetime]  NULL,  
         DeliveryDate      [datetime]  NULL,  
         DepartureDate     [datetime]  NULL,  
         CarrierAgent      [char] (30) NULL,  
         VesselQualifier   [char] (10) NULL,  
         DriverName        [char] (30) NULL,  
         Vessel            [char] (30) NULL,  
         OtherReference    [char] (30) NULL,  
         SKU               [char] (20) NULL,  
         SkuDescr          [char] (60) NULL,  
         Company           [char] (45) NULL,  
         Lot02             [char] (18) NULL,  
         ShippedQty        [decimal] (12,2)  NULL,  
         DRDate            [datetime]  NULL,
         Lot01             [char] (18) NULL,
         Lot04             [datetime] NULL,
         Remark            [varchar] (250)   NULL,
         QtyEA             [int] NULL,
         QtyInner          [decimal] (12,2)  NULL,
         QtyCtn            [decimal] (12,2)  NULL,
         UOM               [Nvarchar] (10)   NULL, 
         KG                [decimal] (12,3)  NULL,       --(Wan01)
         ConvertToKg       [INT]             NULL,        --(Wan01)             
         STNotes1          [nvarchar] (250)  NULL,
         OrdNotes          [nvarchar] (250)  NULL,
         CubeEA            [decimal] (12,4)  NULL,
         CubeInner         [decimal] (12,4)  NULL,
         CubeCtn           [decimal] (12,4)  NULL                  
         )  
  
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_debug = 0, @n_err = 0  
   SET @cPrintFlag = ''  
   SET @c_Storerkey_Prev = ''                            --(Wan01) 

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
  
         IF @cUserDefine10 = ''  
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
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Setup for CodeLkUp.ListName = DR_NCOUNT. (isp_Delivery_Receipt_MDL)"  
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
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fail to Generate Userdefine10 . (isp_Delivery_Receipt_MDL)"  
               END  
               ELSE  
               BEGIN  
                  UPDATE ORDERS   
                  SET UserDefine10 = @cUserDefine10,  
                                  UserDefine07 = GetDate()   -- Update DR Print Date 'added by fklim 07032007  
                  WHERE MBOLKey = @cMBOLKey  
                  AND StorerKey = @cStorerKey  
                  AND  ExternOrderKey = @cExternOrderKey  
                    
                  SELECT @n_err = @@ERROR  
                  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 63501  -- should assign new error code  
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE ORDERS Failed. (isp_Delivery_Receipt_MDL)"  
                  END  
               END  
            END  -- @n_continue = 1 or @n_continue = 2  
         END  
         ELSE  
         BEGIN  
            SET @cPrintFlag = 'Y'  
         END      

         --(Wan01) - START
         IF @c_Storerkey_Prev <>  @cStorerkey 
         BEGIN         
            SET @n_ConvertToKg = 0
            SELECT @n_ConvertToKg = ISNULL(MAX(CASE WHEN CL.Code = 'ConvertToKg' THEN 1 ELSE 0 END),0)
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = 'ReportCfg'
            AND   CL.Storerkey = @cStorerkey
            AND   CL.Long = 'r_dw_delivery_receipt_kfp'
            AND   ISNULL(CL.Short,'') <> 'Y'     
 
         END
         --(Wan01) - END
         
         INSERT INTO #TempFlag(PrintFlag, ExternOrderKey, Storerkey, ConvertToKg)    -- tlting01      --(Wan01)
         VALUES(@cPrintFlag, @cExternOrderKey, @cStorerkey, @n_ConvertToKg)                           --(Wan01)  
         
         SET  @c_Storerkey_Prev =  @cStorerkey                                                        --(Wan01)
         FETCH NEXT FROM CurExternOrder INTO @cStorerkey, @cExternOrderKey, @cUserDefine10 --@cOrderKey, @cStorerkey, @cUserDefine10  
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
         SKU.Descr SkuDescr,  
         LTRIM(RTRIM(STORER.Company)),  
         LOTATTRIBUTE.Lottable02 Lot02,  
         -- SUM(Pickdetail.Qty) / PACK.CaseCnt As ShippedQty,  
         CONVERT(DECIMAL(12,2),SUM(Pickdetail.Qty) / (CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN PACK.CaseCnt   
                               WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN PACK.InnerPack  
                               ELSE 1 END)) As ShippedQty,  
         MBOL.EditDate,         
         LOTATTRIBUTE.Lottable01 AS Lot01,  
         LOTATTRIBUTE.Lottable04 AS Lot04,
         CL.Long AS Remark,
         CONVERT(DECIMAL(12,2),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN 0   
                                    WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN 0  
                                    ELSE SUM(Pickdetail.Qty) END) As QtyEA,  
         CONVERT(DECIMAL(12,2),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN 0   
                                    WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN SUM(Pickdetail.Qty) / PACK.InnerPack  
                                    ELSE 0 END) As QtyInner,  
         CONVERT(DECIMAL(12,2),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN SUM(Pickdetail.Qty) / PACK.CaseCnt   
                                    WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN 0  
                                    ELSE 0 END) As QtyCtn,  
         /*SUM(Pickdetail.Qty) AS QtyEA,
         CONVERT(DECIMAL(12,2), CASE WHEN PACK.Innerpack > 0 THEN SUM(Pickdetail.Qty) / PACK.Innerpack   
                                       ELSE 0 END) As QtyInner,  
         CONVERT(DECIMAL(12,2), CASE WHEN PACK.CaseCnt > 0 THEN SUM(Pickdetail.Qty) / PACK.CaseCnt   
                                       ELSE 0 END) As QtyCtn,*/  
         ORDERDETAIL.UOM  
        ,KG = CONVERT(DECIMAL(12,3), ISNULL(SUM(PICKDETAIL.QTY),0)/1000.00)         --(Wan01)--(Wan02)
        ,T.ConvertToKg                                                              --(Wan01)   
        ,ISNULL(ST2.Notes1,'') 
        ,ISNULL(ORDERS.NOTES,'')
        ,CONVERT(DECIMAL(12,4),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN 0   
                                    WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN 0  
                                    ELSE SKU.StdCube* SUM(Pickdetail.Qty) END) As CubeEA,  
         CONVERT(DECIMAL(12,4),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN 0   
                                    WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN SKU.StdCube*(SUM(Pickdetail.Qty))
                                    ELSE 0 END) As CubeInner,  
         CONVERT(DECIMAL(12,4),CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN SKU.StdCube*(SUM(Pickdetail.Qty))   
                                    WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN 0  
                                    ELSE 0 END) As CubeCtn                                                            
      FROM ORDERS (NOLOCK)  
      JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = OrderDetail.OrderKey  
      JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey  
      JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey  
	  LEFT JOIN STORER ST2 (NOLOCK) ON ORDERS.ConsigneeKey = ST2.Storerkey 
      JOIN SKU (NOLOCK) ON SKU.SKU = OrderDetail.SKU AND SKU.Storerkey = OrderDetail.Storerkey --NJOW03
      JOIN MBOL (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey   
      JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey   
               AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)   
      JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.lot = LOTATTRIBUTE.LOT  
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.PackKey     
      LEFT OUTER JOIN #TempFlag T ON T.ExternOrderkey = ORDERS.ExternOrderkey  -- tlting01
      LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON (ORDERS.Storerkey = CL.Short AND 'DR_'+ORDERS.Storerkey = CL.Code AND CL.Listname = 'DR_NCOUNT')
      WHERE ORDERS.MBOLKEY = @cMBOLKey  
      GROUP BY  
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
            SKU.Descr,  
            LTRIM(RTRIM(STORER.Company)),  
            LOTATTRIBUTE.Lottable02,  
            ORDERDETAIL.UOM,  
            PACK.PackUOM1,  
            PACK.PackUOM2,  
            PACK.CaseCnt,  
            PACK.InnerPack,  
            MBOL.EditDate,  
            LOTATTRIBUTE.Lottable01,  
            LOTATTRIBUTE.Lottable04,
            CL.Long  
          , T.ConvertToKg                                                                             --(Wan01) 
          , ISNULL(ST2.Notes1,'')
          , ISNULL(ORDERS.NOTES,'')
          , SKU.StdCube      
      ORDER BY   
            ORDERS.ExternOrderKey,   
            ORDERS.UserDefine10,   
            ORDERDETAIL.SKU,   
            LOTATTRIBUTE.Lottable02  
   END  
  
   IF @n_continue = 1 OR @n_continue = 2   
      SELECT * FROM @TempData  
        
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_Delivery_Receipt_MDL"  
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