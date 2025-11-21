SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_NikeDO                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  NIKE DO - Despatch Manifest Detail Report                  */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage: dw - _dw_dmanifest_detail_nike                                */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1   (Unicode)                                        */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 06-Mar-2003  RickyYee      To include the buyerpo and Invoice#       */
/* 15-Jan-2004  MaryVong      Add Orders.Notes (SOS19161)               */
/* 22-Jun-2004  Shong         NSC SKU Code Format Changed               */
/* 01-Jul-2004  Shong         Add new column MarkFor                    */
/* 01-Jul-2004  YTWan         Display Orders Door (SOS24796)            */
/* 26-Jul-2005  MaryVong      Modified PO# and OrderGroup (SOS25508)    */
/* 28-Jun-2005  June          SOS37483 - replace 1st 2 chars in SKU with*/
/*                                    1st six char from SUSR4           */
/* 08-Aug-2005  June          SOS39115 - bug fixed incorrect total shipped*/
/* 17-Sep-2013  YTWan    1.1  FBR288717- Default Remark on Manifest Rpt */
/*                            (Wan01)                                   */
/* 02-Jun-2015  CSCHONG   1.2 SOS343199 (CS01)                          */
/* 28-Jan-2019  TLTING_ext 1.3 enlarge externorderkey field length      */  																			
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_NikeDO] (@c_input  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  @c_Consigneekey NVARCHAR(15),
   @c_company   NVARCHAR(45),
   @c_address1  NVARCHAR(45),
   @c_address2  NVARCHAR(45),
   @c_address3  NVARCHAR(45),
   @c_OrderGroup NVARCHAR(20),
   @c_OrderType NVARCHAR(25),
   @c_route       NVARCHAR(10),
   @c_MbolKey   NVARCHAR(10),
   @c_LoadKey   NVARCHAR(10),
  -- @c_ExternOrderKey NVARCHAR(30),
   @c_ExternOrderKey NVARCHAR(50),  --tlting_ext  
   @d_OrderDate      datetime,
   @d_DeliveryDate   datetime,
   @d_DepartureDate  datetime,
   @c_OrderKey       NVARCHAR(10),
   @c_skugroup       NVARCHAR(15),
   @c_Sku            NVARCHAR(20),
   @c_Descr          NVARCHAR(60),
   @c_Uom            NVARCHAR(10),
   @c_SkuSize        NVARCHAR(5),
   @n_qty            int,
   @n_unitprice      decimal(10,2),
   @n_ttlctn         int,
   @n_ttlwgt         decimal(10,2),
   @n_ttlcub         decimal(10,2),
   @c_salesman       NVARCHAR(30),
   @c_BuyerPO        NVARCHAR(20),
   @c_InvoiceNo      NVARCHAR(20),
   @c_temporderkey NVARCHAR(10),
   @c_tempskugroup NVARCHAR(15),
   @c_tempsize       NVARCHAR(5),
   @n_counter        int,
   @c_Notes          NVARCHAR(250) -- Added by MaryVong on 14-Jan-2004 (FBR#19161)


   CREATE TABLE #TempDO (
   Consigneekey NVARCHAR(15) NULL,
   C_company NVARCHAR(45) NULL,
   C_address1 NVARCHAR(45) NULL,
   C_address2 NVARCHAR(45) NULL,
   C_address3 NVARCHAR(45) NULL,
   OrderGroup NVARCHAR(20) NULL,
   OrderType NVARCHAR(25) NULL,
   Route       NVARCHAR(10) NULL,
   MbolKey   NVARCHAR(10) NULL,
   LoadKey   NVARCHAR(10) NULL,
  -- ExternOrderKey NVARCHAR(30) NULL,
   ExternOrderKey NVARCHAR(50) NULL,   --tlting_ext  
   OrderDate      datetime NULL,
   DeliveryDate   datetime NULL,
   DepartureDate  datetime NULL,
   OrderKey       NVARCHAR(10) NULL,
   SkuGroup       NVARCHAR(15) NULL,
   Sku            NVARCHAR(22) NULL,
   Descr          NVARCHAR(60) NULL,
   Uom            NVARCHAR(10) NULL,
   SkuSize1       NVARCHAR(5)  NULL,
   SkuSize2       NVARCHAR(5)  NULL,
   SkuSize3       NVARCHAR(5)  NULL,
   SkuSize4       NVARCHAR(5)  NULL,
   SkuSize5       NVARCHAR(5)  NULL,
   SkuSize6       NVARCHAR(5)  NULL,
   SkuSize7       NVARCHAR(5)  NULL,
   SkuSize8       NVARCHAR(5)  NULL,
   SkuSize9       NVARCHAR(5)  NULL,
   SkuSize10      NVARCHAR(5)  NULL,
   SkuSize11      NVARCHAR(5)  NULL,
   SkuSize12      NVARCHAR(5)  NULL,
   SkuSize13      NVARCHAR(5)  NULL,
   SkuSize14      NVARCHAR(5)  NULL,
   SkuSize15      NVARCHAR(5)  NULL,
   SkuSize16      NVARCHAR(5)  NULL,
   SkuSize17      NVARCHAR(5)  NULL,
   SkuSize18      NVARCHAR(5)  NULL,
   SkuSize19      NVARCHAR(5)  NULL,
   SkuSize20      NVARCHAR(5)  NULL,
   SkuSize21      NVARCHAR(5)  NULL,
   SkuSize22      NVARCHAR(5)  NULL,
   SkuSize23      NVARCHAR(5)  NULL,
   Sku_qty1       int NULL,
   Sku_qty2       int NULL,
   Sku_qty3       int NULL,
   Sku_qty4       int NULL,
   Sku_qty5       int NULL,
   Sku_qty6       int NULL,
   Sku_qty7       int NULL,
   Sku_qty8       int NULL,
   Sku_qty9       int NULL,
   Sku_qty10      int NULL,
   Sku_qty11      int NULL,
   Sku_qty12      int NULL,
   Sku_qty13      int NULL,
   Sku_qty14      int NULL,
   Sku_qty15      int NULL,
   Sku_qty16      int NULL,
   Sku_qty17      int NULL,
   Sku_qty18      int NULL,
   Sku_qty19      int NULL,
   Sku_qty20      int NULL,
   Sku_qty21      int NULL,
   Sku_qty22      int NULL,
   Sku_qty23      int NULL,
   Unitprice      decimal(10,2) Null,
   TTLctn         int Null,
   TTLwgt         decimal(10,2) Null,
   TTLcub         decimal(10,2) Null,
   Salesman       NVARCHAR(30) Null,
   BuyerPO        NVARCHAR(20) NULL,
   InvoiceNo      NVARCHAR(20) Null,
   Notes          NVARCHAR(250) Null ) -- Added by MaryVong on 14-Jan-2004 (FBR#19161)

   select @c_temporderkey = '', @c_tempskugroup = '', @c_tempsize = ''
   select oh.consigneekey
   , oh.c_company
   , oh.c_address1
   , oh.c_address2
   , oh.c_address3
   --, oh.orderGroup  -- SOS25508
   , OrderGroup = MAX(od.UserDefine04)
   , ttypedesc = (select cast(description as NVARCHAR(25)) from codelkup (nolock) where listname = 'ordertype' and code = oh.type)
   , oh.route
   , oh.mbolkey
   , oh.loadkey
   , oh.externorderkey
   , oh.orderdate
   , oh.deliverydate
   , mb.departuredate
   , oh.orderkey
   , tskugroup = left(od.sku,9)
   -- Start : SOS37483
   -- , tgpc = (dbo.fnc_RTrim(isnull(susr4,'00'))+ od.sku)
   , tgpc = (isnull(left(s.susr4,6), '000000')+'-'+substring(RTrim(od.sku), 1, 6)+'-'+substring(od.sku, 7,3))
   -- End : SOS37483
   , s.descr
   , od.uom
   , tsize = dbo.fnc_LTrim(substring(od.sku,10,5))
   , tqty = isnull((qtypicked + shippedqty), 0)
   , tprice = cast(od.UnitPrice as decimal(10,2))
   , ttlctn = (select totalcartons from mboldetail md (nolock)
   where md.mbolkey = mb.mbolkey and md.orderkey = oh.orderkey)
   , ttlwgt = (qtypicked + shippedqty) * s.STDGROSSWGT
   , ttlcub = (qtypicked + shippedqty) * s.STDCUBE
   , oh.salesman
   --, oh.BuyerPO  -- SOS25508
   , BuyerPO = CASE 
                  WHEN oh.BuyerPO IS NULL THEN oh.ExternPOKey
                  ELSE oh.BuyerPO
               END
   , oh.InvoiceNo
   --(Wan01) - START
   --, notes = CONVERT(NVARCHAR(250), oh.Notes)   -- Added by MaryVong on 14-Jan-2004 (FBR#19161)
   ,NOTES  = CASE WHEN SC.SVALUE = '1' AND ISNULL(RTRIM(CONVERT(NVARCHAR(250), CS.Notes1)), '') <> '' 
                  THEN CONVERT(NVARCHAR(250), CS.Notes1) ELSE CONVERT(NVARCHAR(250), OH.Notes)  END 

   --(Wan01) - END
   into #tt
   from  orders oh  WITH (nolock)
   --(Wan01) - START
   JOIN  orderdetail od WITH (nolock) ON (oh.orderkey = od.orderkey)
   JOIN  sku  s         WITH (nolock) ON (od.storerkey = s.storerkey) AND (od.sku = s.sku)
   JOIN  mbol mb        WITH (nolock) ON (oh.mbolkey = mb.mbolkey)

   LEFT JOIN STORER CS       WITH (NOLOCK) ON (OH.ConsigneeKey = CS.Storerkey)
   LEFT JOIN STORERCONFIG SC WITH (NOLOCK) ON (OH.Storerkey = SC.Storerkey)
                                          AND (SC.Configkey= 'CONSIGNEEREMARK')
   --(Wan01) - END
   --(CS01) Start
   LEFT JOIN CODELKUP CP (NOLOCK) ON (CP.Listname='REPORTCFG' 
                                  AND CP.long='r_dw_dmanifest_detail_nike' 
                                  AND CP.Storerkey = oh.StorerKey 
                                  AND CP.short='Y')
   --(CS01) END
   where oh.storerkey = 'niketh'
   and oh.mbolkey = @c_input
   and (od.qtypicked + od.shippedqty) <> 0
   --(CS01) Start
   AND (1 = CASE  
       WHEN CP.short = 'Y' AND (mb.status<'9') THEN '0'
       WHEN  CP.short = 'Y' AND  (mb.status ='9') THEN '1'
     ELSE '1'
   END)
   --(CS01) END
   group by oh.consigneekey   --SOS25508
   , oh.c_company
   , oh.c_address1
   , oh.c_address2
   , oh.c_address3
   , oh.type
   , oh.route
   , oh.mbolkey
   , oh.loadkey
   , oh.externorderkey
   , oh.orderdate
   , oh.deliverydate
   , mb.departuredate
   , oh.orderkey
   , left(od.sku,9)
   -- Start : SOS37483
   -- , (dbo.fnc_RTrim(isnull(susr4,'00'))+ od.sku)
   , s.susr4 -- SOS37483
   -- End : SOS37483
   , od.sku
   , s.descr
   , od.uom
   , dbo.fnc_LTrim(substring(od.sku,10,5))
   , qtypicked
   , shippedqty
   , cast(od.UnitPrice as decimal(10,2))
   , mb.mbolkey 
   , s.STDGROSSWGT
   , s.STDCUBE
   , oh.salesman
   , oh.BuyerPO
   , oh.ExternPOKey  
   , oh.InvoiceNo
   --(Wan01) - START
   --, CONVERT(NVARCHAR(250), oh.Notes)
   ,CASE WHEN SC.SVALUE = '1' AND ISNULL(RTRIM(CONVERT(NVARCHAR(250), CS.Notes1)), '') <> '' 
         THEN CONVERT(NVARCHAR(250), CS.Notes1) ELSE CONVERT(NVARCHAR(250), OH.Notes)  END 

   --(Wan01) - END
   , s.BUSR6
   order by oh.orderkey, left(od.sku,9), s.BUSR6
   --order by oh.orderkey, s.SUSR3


   declare sku_cur cursor for
   select * from #tt
    order by orderkey, tskugroup -- SOS39115
    
   OPEN sku_cur

   FETCH NEXT FROM sku_cur INTO  @c_Consigneekey, @c_company, @c_address1, @c_address2, @c_address3
   , @c_OrderGroup, @c_OrderType, @c_route, @c_mbolkey, @c_loadkey
   , @c_ExternOrderKey, @d_OrderDate, @d_DeliveryDate, @d_DepartureDate
   , @c_orderkey, @c_skugroup, @c_Sku, @c_Descr, @c_Uom, @c_SkuSize, @n_qty, @n_unitprice
   , @n_ttlctn, @n_ttlwgt, @n_ttlcub, @c_salesman,    @c_BuyerPO, @c_InvoiceNo, @c_Notes  -- Added by MaryVong on 14-Jan-2004 (FBR#19161)

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @c_temporderkey <> @c_orderkey or @c_tempskugroup <> @c_skugroup
      BEGIN
         SELECT @c_temporderkey = @c_orderkey, @c_tempskugroup = @c_skugroup
         SELECT @n_counter = 1
         INSERT INTO #TempDo (
         Consigneekey,
         C_company,
         C_address1,
         C_address2,
         C_address3,
         OrderGroup,
         OrderType,
         Route,
         MbolKey,
         LoadKey,
         ExternOrderKey,
         OrderDate,
         DeliveryDate,
         DepartureDate,
         OrderKey,
         SkuGroup,
         Sku,
         Descr,
         UOM,
         SkuSize1,
         Sku_qty1,
         UnitPrice,
         TTLctn,
         TTLwgt,
         TTLcub,
         Salesman,
         BuyerPO,
         InvoiceNo,
         Notes )  -- Added by MaryVong on 14-Jan-2004 (FBR#19161)
         VALUES (
         @c_Consigneekey,
         @c_company,
         @c_address1,
         @c_address2,
         @c_address3,
         @c_OrderGroup,
         @c_OrderType,
         @c_Route,
         @c_MbolKey,
         @c_LoadKey,
         @c_ExternOrderKey,
         @d_OrderDate,
         @d_DeliveryDate,
         @d_DepartureDate,
         @c_orderkey,
         @c_skugroup,
         -- Start : SOS37483
         --(left(@c_Sku,6)+'-'+substring(@c_sku,3,6)+'-'+substring(@c_sku,9,3)),
         @c_sku, 
         -- End : SOS37483
         @c_descr,
         @c_uom,
         @c_SkuSize,
         @n_qty,
         @n_unitprice,
         @n_ttlctn,
         @n_ttlwgt,
         @n_ttlcub,
         @c_salesman,
         @c_BuyerPO,
         @c_InvoiceNo,
         @c_Notes )  -- Added by MaryVong on 14-Jan-2004 (FBR#19161)
      END
      ELSE
      BEGIN
         SELECT @n_counter = @n_counter + 1
         IF @n_counter = 2
         BEGIN
            UPDATE #tempdo
            SET SkuSize2 = @c_SkuSize, Sku_qty2 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
            WHERE Orderkey = @c_orderkey
            AND   Skugroup = @c_skugroup
         END
         ELSE IF @n_counter = 3
         BEGIN
            UPDATE #tempdo
            SET SkuSize3 = @c_SkuSize, Sku_qty3 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
            WHERE Orderkey = @c_orderkey
            AND   Skugroup = @c_skugroup
         END
         ELSE IF @n_counter = 4
         BEGIN
            UPDATE #tempdo
            SET SkuSize4 = @c_SkuSize, Sku_qty4 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
            WHERE Orderkey = @c_orderkey
            AND   Skugroup = @c_skugroup
         END
      ELSE IF @n_counter = 5
      BEGIN
         UPDATE #tempdo
         SET SkuSize5 = @c_SkuSize, Sku_qty5 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 6
      BEGIN
         UPDATE #tempdo
         SET SkuSize6 = @c_SkuSize, Sku_qty6 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 7
      BEGIN
         UPDATE #tempdo
         SET SkuSize7 = @c_SkuSize, Sku_qty7 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 8
      BEGIN
         UPDATE #tempdo
         SET SkuSize8 = @c_SkuSize, Sku_qty8 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 9
      BEGIN
         UPDATE #tempdo
         SET SkuSize9 = @c_SkuSize, Sku_qty9 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 10
      BEGIN
         UPDATE #tempdo
         SET SkuSize10 = @c_SkuSize, Sku_qty10 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 11
      BEGIN
         UPDATE #tempdo
         SET SkuSize11 = @c_SkuSize, Sku_qty11 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 12
      BEGIN
         UPDATE #tempdo
         SET SkuSize12 = @c_SkuSize, Sku_qty12 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 13
      BEGIN
         UPDATE #tempdo
         SET SkuSize13 = @c_SkuSize, Sku_qty13 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 14
      BEGIN
         UPDATE #tempdo
         SET SkuSize14 = @c_SkuSize, Sku_qty14 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 15
      BEGIN
         UPDATE #tempdo
         SET SkuSize15 = @c_SkuSize, Sku_qty15 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 16
      BEGIN
         UPDATE #tempdo
         SET SkuSize16 = @c_SkuSize, Sku_qty16 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 17
      BEGIN
         UPDATE #tempdo
         SET SkuSize17 = @c_SkuSize, Sku_qty17 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 18
      BEGIN
         UPDATE #tempdo
         SET SkuSize18 = @c_SkuSize, Sku_qty18 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 19
      BEGIN
         UPDATE #tempdo
         SET SkuSize19 = @c_SkuSize, Sku_qty19 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 20
      BEGIN
         UPDATE #tempdo
         SET SkuSize20 = @c_SkuSize, Sku_qty20 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 21
      BEGIN
         UPDATE #tempdo
         SET SkuSize21 = @c_SkuSize, Sku_qty21 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 22
      BEGIN
         UPDATE #tempdo
         SET SkuSize22 = @c_SkuSize, Sku_qty22 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
      ELSE IF @n_counter = 23
      BEGIN
         UPDATE #tempdo
         SET SkuSize23 = @c_SkuSize, Sku_qty23 = @n_qty, TTLwgt = @n_ttlwgt, TTLcub = @n_ttlcub
         WHERE Orderkey = @c_orderkey
         AND   Skugroup = @c_skugroup
      END
   END
   FETCH NEXT FROM sku_cur INTO  @c_Consigneekey, @c_company, @c_address1, @c_address2, @c_address3
   , @c_OrderGroup, @c_OrderType, @c_route, @c_mbolkey, @c_loadkey
   , @c_ExternOrderKey, @d_OrderDate, @d_DeliveryDate, @d_DepartureDate
   , @c_orderkey, @c_skugroup, @c_Sku, @c_Descr, @c_Uom, @c_SkuSize, @n_qty, @n_unitprice
   , @n_ttlctn, @n_ttlwgt, @n_ttlcub, @c_salesman, @c_BuyerPO, @c_InvoiceNo, @c_Notes  -- Added by MaryVong on 14-Jan-2004 (FBR#19161)
END

CLOSE sku_cur
DEALLOCATE sku_cur

DROP TABLE #tt

SELECT #tempdo.*, 
ISNULL(RTrim(ORDERS.B_Company), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_Address1), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_Address2), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_Address3), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_Address4), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_City), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_Zip), '') + ', ' + 
ISNULL(RTrim(ORDERS.B_Country), '')  as MarkFor,
ORDERS.Door                -- Added by YTWan on 1-July-2004 (SOS#:24796)
FROM #tempdo, ORDERS (NOLOCK)
WHERE #tempdo.OrderKey = ORDERS.OrderKey    

DROP TABLE #tempdo
END

GO