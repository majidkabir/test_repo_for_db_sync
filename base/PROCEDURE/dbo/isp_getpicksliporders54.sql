SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Proc : isp_GetPickSlipOrders54                                   */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:  309322 - SG Pickslip (modified from nsp_GetPickSlipOrders08)  */  
/*                                                                         */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: r_dw_print_pickorder54                                       */  
/*                                                                         */  
/* PVCS Version: 1.4                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author      Ver   Purposes                                  */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/***************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipOrders54] (@c_loadkey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @c_pickheaderkey      NVARCHAR(10),  
        @n_continue           INT,  
        @c_errmsg             NVARCHAR(255),  
        @b_success            INT,  
        @n_err                INT,  
        @c_sku                NVARCHAR(20),  
        @n_qty                INT,  
        @c_loc                NVARCHAR(10),  
        @n_cases              INT,  
        @n_perpallet          INT,  
        @c_storer             NVARCHAR(15),  
        @c_orderkey           NVARCHAR(10),  
        @c_ConsigneeKey       NVARCHAR(15),  
        @c_Company            NVARCHAR(45),  
        @c_Addr1              NVARCHAR(45),  
        @c_Addr2              NVARCHAR(45),  
        @c_Addr3              NVARCHAR(45),  
        @c_PostCode           NVARCHAR(15),  
        @c_Route              NVARCHAR(10),  
        @c_Route_Desc         NVARCHAR(60), -- RouteMaster.Desc  
        @c_TrfRoom            NVARCHAR(5),  -- LoadPlan.TrfRoom  
        @c_Notes1             NVARCHAR(60),  
        @c_Notes2             NVARCHAR(60),  
        @c_SkuDesc            NVARCHAR(60),  
        @n_CaseCnt            INT,  
        @n_PalletCnt          INT,  
        @c_ReceiptTm          NVARCHAR(20),  
        @c_PrintedFlag        NVARCHAR(1),  
        @c_UOM                NVARCHAR(10),  
        @n_UOM3               INT,  
        @c_Lot                NVARCHAR(10),  
        @c_StorerKey          NVARCHAR(15),  
        @c_Zone               NVARCHAR(1),  
        @n_PgGroup            INT,  
        @n_TotCases           INT,  
        @n_RowNo              INT,  
        @c_PrevSKU            NVARCHAR(20),  
        @n_SKUCount           INT,  
        @c_Carrierkey         NVARCHAR(60),  
        @c_VehicleNo          NVARCHAR(10),  
        @c_firstorderkey      NVARCHAR(10),  
        @c_superorderflag     NVARCHAR(1),  
        @c_firsttime         NVARCHAR(1),  
        @c_logicalloc         NVARCHAR(18),  
        @c_Lottable01         NVARCHAR(18),   
        @c_Lottable02         NVARCHAR(18), -- SOS14561  
        @c_Lottable03         NVARCHAR(18),   
        @d_Lottable04         DATETIME,  
        @n_packpallet         INT,  
        @n_packcasecnt        INT,  
        @c_externorderkey     NVARCHAR(50),   --tlting_ext  
        @n_pickslips_required INT,  
        @c_areakey            NVARCHAR(10),  
        @c_skugroup           NVARCHAR(10) -- SOS144415  
  
DECLARE @c_PrevOrderKey NVARCHAR(10),  
        @n_Pallets      INT,  
        @n_Cartons      INT,  
        @n_Eaches       INT,  
        @n_UOMQty       INT  
  
DECLARE @n_starttcnt INT  
SELECT  @n_starttcnt = @@TRANCOUNT  
  
WHILE @@TRANCOUNT > 0  
BEGIN  
   COMMIT TRAN  
END  
  
SET @n_pickslips_required = 0 -- (Leong01)  
  
BEGIN TRAN  
  
   CREATE TABLE #TEMP_PICK  
       ( PickSlipNo       NVARCHAR(10) NULL,  
         LoadKey          NVARCHAR(10),  
         OrderKey         NVARCHAR(10),  
         ConsigneeKey     NVARCHAR(15),  
         Company          NVARCHAR(45),  
         Addr1            NVARCHAR(45) NULL,  
         Addr2            NVARCHAR(45) NULL,  
         Addr3            NVARCHAR(45) NULL,  
         PostCode         NVARCHAR(15) NULL,  
         Route            NVARCHAR(10) NULL,  
         Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc  
         TrfRoom          NVARCHAR(5) NULL,  -- LoadPlan.TrfRoom  
         Notes1           NVARCHAR(60) NULL,  
         Notes2           NVARCHAR(60) NULL,  
         LOC              NVARCHAR(10) NULL,  
         ID               NVARCHAR(18) NULL,    -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
         SKU              NVARCHAR(20),  
         SkuDesc          NVARCHAR(60),  
         Qty              INT,  
         TempQty1         INT,  
         TempQty2         INT,  
         PrintedFlag      NVARCHAR(1) NULL,  
         Zone             NVARCHAR(1),  
         PgGroup          INT,  
         RowNum           INT,  
         Lot              NVARCHAR(10),  
         Carrierkey       NVARCHAR(60) NULL,  
         VehicleNo        NVARCHAR(10) NULL,  
         Lottable01       NVARCHAR(18) NULL,  
         Lottable02       NVARCHAR(18) NULL, -- SOS14561  
         Lottable03       NVARCHAR(18) NULL,  
         Lottable04       DATETIME NULL,  
         packpallet       INT,  
         packcasecnt      INT,  
         packinner        INT,     -- sos 7545 wally 27.aug.2002  
         packeaches       INT,       -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
         externorderkey   NVARCHAR(50) NULL,  
         LogicalLoc       NVARCHAR(18) NULL,  
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen ON 05-Mar-2002 (Ticket # 3377)  
         UOM              NVARCHAR(10),          -- Added By YokeBeen ON 18-Mar-2002 (Ticket # 2539)  
         Pallet_cal       INT,  
         Cartons_cal      INT,  
         inner_cal        INT,     -- sos 7545 wally 27.aug.2002  
         Each_cal         INT,  
         Total_cal        INT,       -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
         DeliveryDate     DATETIME NULL,  
         RetailSku        NVARCHAR(20) NULL,  -- Added by MaryVong ON 22Sept04 (SOS27518)  
         BuyerPO          NVARCHAR(20) NULL,  -- Added by MaryVong ON 23Sept04 (SOS27518)  
         InvoiceNo        NVARCHAR(10) NULL,  -- Added by MaryVong ON 23Sept04 (SOS27518)  
         OrderDate        DATETIME NULL,  -- Added by MaryVong ON 23Sept04 (SOS27518)  
         Susr4            NVARCHAR(18) NULL,  -- sos 26373 wally 18.oct.2004  
         vat              NVARCHAR(18) NULL,  
         OVAS             NVARCHAR(30) NULL,  -- SOS41046  
         SKUGROUP         NVARCHAR(10) NULL -- SOS144415  
         )  
   INSERT INTO #TEMP_PICK  
        (PickSlipNo,    LoadKey,          OrderKey,     ConsigneeKey,  
         Company,       Addr1,            Addr2,        PgGroup,  
         Addr3,         PostCode,     Route,  
         Route_Desc,    TrfRoom,          Notes1,       RowNum,  
         Notes2,        LOC,              ID,           SKU,  
         SkuDesc,       Qty,              TempQty1,  
         TempQty2,      PrintedFlag,      Zone,  
         Lot,           CarrierKey,       VehicleNo,    Lottable01, Lottable02, Lottable03,   
         Lottable04,    packpallet,       packcasecnt,  packinner,  
         packeaches,    externorderkey,   LogicalLoc,   Areakey,    UOM,  
         Pallet_cal,    Cartons_cal,      inner_cal,    Each_cal,   Total_cal,  
         DeliveryDate,  RetailSku,        BuyerPO,      InvoiceNo,  OrderDate,  
         Susr4,         Vat,              OVAS,         SKUGROUP) -- SOS144415  
   SELECT  
         (SELECT PICKHEADERKEY FROM PICKHEADER  
          WHERE ExternOrderKey = @c_LoadKey  
          AND OrderKey = PickDetail.OrderKey  
          AND ZONE = '3'),  
         @c_LoadKey AS LoadKey,  
         PickDetail.OrderKey,  
         -- Changed by YokeBeen ON 08-Aug-2002 (Ticket # 6692) - FROM BillToKey to ConsigneeKey.  
         ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,  
         ISNULL(ORDERS.c_Company, '')  AS Company,  
         ISNULL(ORDERS.C_Address1,'') AS Addr1,  
         ISNULL(ORDERS.C_Address2,'')  AS Addr2,  
         0 AS PgGroup,  
         ISNULL(ORDERS.C_Address3,'') AS Addr3,  
         ISNULL(ORDERS.C_Zip,'') AS PostCode,  
         ISNULL(ORDERS.Route,'') AS Route,  
         ISNULL(RouteMaster.Descr, '') Route_Desc,  
         ORDERS.Door AS TrfRoom,  
         CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')) Notes1,  
         0 AS RowNo,  
         CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,  
         PickDetail.loc,  
         PickDetail.id,    -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
         PickDetail.sku,  
         ISNULL(Sku.Descr,'') SkuDescr,  
         SUM(PickDetail.qty) AS Qty,  
         --CASE PickDetail.UOM  
         --     WHEN '1' THEN PACK.Pallet  
         --     WHEN '2' THEN PACK.CaseCnt  
         --     WHEN '3' THEN PACK.InnerPack  
         --     ELSE 1  END AS UOMQty,  
         1 AS UOMQTY, --NJOW01  
         0 AS TempQty2,  
         ISNULL((SELECT DISTINCT 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,  
         '3' Zone,  
         Pickdetail.Lot,  
        '' CarrierKey,  
        '' AS VehicleNo,  
        LotAttribute.Lottable01,  
        LotAttribute.Lottable02, -- SOS14561  
        LotAttribute.Lottable03,   
        ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,  
        PACK.Pallet,  
        PACK.CaseCnt,  
        pack.innerpack, -- sos 7545 wally 27.aug.2002  
        PACK.Qty,     -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
        ORDERS.ExternOrderKey AS ExternOrderKey,  
        ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,  
        ISNULL(AreaDetail.AreaKey, '00') AS Areakey,     -- Added By YokeBeen ON 05-Mar-2002 (Ticket # 3377)  
        ISNULL(OrderDetail.UOM, '') AS UOM,            -- Added By YokeBeen ON 18-Mar-2002 (Ticket # 2539)  
        /* Added By YokeBeen ON 20-Mar-2002 (Ticket # 2539 / 3377) - Start */  
        Pallet_cal = CASE Pack.Pallet WHEN 0 THEN 0  
         ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
        END,  
        Cartons_cal = 0,  
        inner_cal = 0,  
        Each_cal = 0,  
        Total_cal = sum(pickdetail.qty),  
        ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,  
        /* Added By YokeBeen ON 20-Mar-2002 (Ticket # 2539 / 3377) - END */  
        ISNULL(Sku.RetailSku,'') RetailSku,        -- Added by MaryVong ON 22Sept04 (SOS27518)  
        ISNULL(ORDERS.BuyerPO,'') BuyerPO,        -- Added by MaryVong ON 23Sept04 (SOS27518)  
        ISNULL(ORDERS.InvoiceNo,'') InvoiceNo,       -- Added by MaryVong ON 23Sept04 (SOS27518)  
        ISNULL(ORDERS.OrderDate, '19000101') OrderDate,   -- Added by MaryVong ON 23Sept04 (SOS27518)  
        SKU.Susr4,               -- sos 26373 wally 18.oct.2004  
        ST.vat,  
        SKU.OVAS, -- SOS41046  
        SKU.SKUGROUP -- SOS#144415  
   FROM pickdetail (NOLOCK)  
   JOIN orders (NOLOCK)  
   ON pickdetail.orderkey = orders.orderkey  
   JOIN lotattribute (NOLOCK)  
   ON pickdetail.lot = lotattribute.lot  
   JOIN loadplandetail (NOLOCK)  
   ON pickdetail.orderkey = loadplandetail.orderkey  
   JOIN orderdetail (NOLOCK)  
   ON pickdetail.orderkey = orderdetail.orderkey AND pickdetail.orderlinenumber = orderdetail.orderlinenumber  
   JOIN storer (NOLOCK)  
   ON pickdetail.storerkey = storer.storerkey  
   JOIN sku (NOLOCK)  
   ON pickdetail.sku = sku.sku AND pickdetail.storerkey = sku.storerkey  
   JOIN pack (NOLOCK)  
   ON pickdetail.packkey = pack.packkey  
   JOIN loc (NOLOCK)  
   ON pickdetail.loc = loc.loc  
   LEFT OUTER JOIN routemaster (NOLOCK)  
   ON orders.route = routemaster.route  
   LEFT OUTER JOIN areadetail (NOLOCK)  
   ON loc.putawayzone = areadetail.putawayzone  
   LEFT OUTER JOIN storer st (NOLOCK)  
   ON orders.consigneekey = st.storerkey  
   WHERE PickDetail.Status < '5'  
   AND LoadPlanDetail.LoadKey = @c_LoadKey  
   GROUP BY PickDetail.OrderKey,  
   -- Changed by YokeBeen ON 08-Aug-2002 (Ticket # 6692) - FROM BillToKey to ConsigneeKey.  
   ISNULL(ORDERS.ConsigneeKey, ''),  
   ISNULL(ORDERS.c_Company, ''),  
   ISNULL(ORDERS.C_Address1,''),  
   ISNULL(ORDERS.C_Address2,''),  
   ISNULL(ORDERS.C_Address3,''),  
   ISNULL(ORDERS.C_Zip,''),  
   ISNULL(ORDERS.Route,''),  
   ISNULL(RouteMaster.Descr, ''),  
   ORDERS.Door,  
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')),  
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),  
   PickDetail.loc,  
   PickDetail.id,    -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
   PickDetail.sku,  
   ISNULL(Sku.Descr,''),  
   --CASE PickDetail.UOM  
   --     WHEN '1' THEN PACK.Pallet  
   --     WHEN '2' THEN PACK.CaseCnt  
   --     WHEN '3' THEN PACK.InnerPack  
   --     ELSE 1  END,  
   Pickdetail.Lot,  
   LotAttribute.Lottable01,   
   LotAttribute.Lottable02,  -- SOS14561  
   LotAttribute.Lottable03,    
   ISNULL(LotAttribute.Lottable04, '19000101'),  
   PACK.Pallet,  
   PACK.CaseCnt,  
   pack.innerpack,  -- sos 7545 wally 27.aug.2002  
   PACK.Qty,     -- Added by YokeBeen ON 05-Aug-2002 (Ticket # 6692, 4657)  
   ORDERS.ExternOrderKey,  
   ISNULL(LOC.LogicalLocation, ''),  
   ISNULL(AreaDetail.AreaKey, '00'),     -- Added By YokeBeen ON 05-Mar-2002 (Ticket # 3377)  
   ISNULL(OrderDetail.UOM, ''),          -- Added By YokeBeen ON 18-Mar-2002 (Ticket # 2539)  
   ISNULL(ORDERS.DeliveryDate, '19000101'),  
   ISNULL(Sku.RetailSku,''),        -- Added by MaryVong ON 22Sept04 (SOS27518)  
   ISNULL(ORDERS.BuyerPO,''),        -- Added by MaryVong ON 23Sept04 (SOS27518)  
   ISNULL(ORDERS.InvoiceNo,''),       -- Added by MaryVong ON 23Sept04 (SOS27518)  
   ISNULL(ORDERS.OrderDate, '19000101'),      -- Added by MaryVong ON 23Sept04 (SOS27518)  
   SKU.Susr4,            -- sos 26373 wally 18.oct.2004  
   ST.vat,  
   SKU.OVAS, -- SOS41046  
   SKU.SKUGROUP -- SOS#144415  
  
   -- SOS 7236  
   -- wally 16.aug.2002  
   -- commented the cursor below AND instead UPDATE directly the temp table  
   -- UPDATE CASE qty  
   UPDATE #temp_pick  
      SET cartons_cal = CASE packcasecnt  
                           WHEN 0 THEN 0  
                           --ELSE FLOOR(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)  
                           ELSE FLOOR(total_cal/packcasecnt)  --NJOW01  
                        END  
  
   -- UPDATE inner qty  
   UPDATE #temp_pick  
      SET inner_cal = CASE packinner  
                        WHEN 0 THEN 0  
                        --ELSE FLOOR(total_cal/packinner) -  
                        --  ((packpallet*pallet_cal)/packinner) - ((packcasecnt*cartons_cal)/packinner)  
                        ELSE FLOOR(total_cal/packinner) - ((packcasecnt*cartons_cal)/packinner) --NJOW01  
                      END  
  
   -- UPDATE each qty  
   UPDATE #temp_pick  
   --SET each_cal = total_cal - (packpallet*pallet_cal) - (packcasecnt*cartons_cal) - (packinner*inner_cal)  
   SET each_cal = total_cal - (packcasecnt*cartons_cal) - (packinner*inner_cal) --NJOW01  
  
   BEGIN TRAN  
   -- Uses PickType AS a Printed Flag  
   UPDATE PickHeader WITH (ROWLOCK)    -- tlting01  
      SET PickType = '1', TrafficCop = NULL  
   WHERE ExternOrderKey = @c_LoadKey  
   AND Zone = '3'  
  
   SELECT @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SELECT @n_continue = 3  
      IF @@TRANCOUNT >= 1  
      BEGIN  
         ROLLBACK TRAN  
      END  
   END  
   ELSE  
   BEGIN  
      IF @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
      ELSE  
      BEGIN  
         SELECT @n_continue = 3  
         ROLLBACK TRAN  
      END  
   END  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)  
   FROM #TEMP_PICK  
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)  
  
   IF @@ERROR <> 0  
   BEGIN  
      GOTO FAILURE  
   END  
   ELSE IF @n_pickslips_required > 0  
   BEGIN  
      BEGIN TRAN  
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
      COMMIT TRAN  
 --             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +  
 --             dbo.fnc_LTrim( dbo.fnc_RTrim(  
 --                STR(  
 --                   CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)  
 --                                                     FROM #TEMP_PICK AS Rank  
 --                                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )  
 --                    ) -- str  
 --                    )) -- dbo.fnc_RTrim  
 --                 , 9)  
 --              , OrderKey, LoadKey, '0', '8', ''  
 --             FROM #TEMP_PICK WHERE PickSlipNo IS NULL  
 --             GROUP By LoadKey, OrderKey  
  
      BEGIN TRAN  
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +  
                           dbo.fnc_LTrim( dbo.fnc_RTrim(  
                           STR(  
                              CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)  
                                                                FROM #TEMP_PICK AS Rank  
                                                                WHERE Rank.OrderKey < #TEMP_PICK.OrderKey  
                                                                  AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- (Leong01)  
                              ) -- str  
                         )) -- dbo.fnc_RTrim  
                         , 9)  
      , OrderKey, LoadKey, '0', '3', ''  
      FROM #TEMP_PICK WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)  
      GROUP By LoadKey, OrderKey  
  
      UPDATE #TEMP_PICK  
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM PICKHEADER (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' -- (Leong01)  
  
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   GOTO SUCCESS  
  
FAILURE:  
   DELETE FROM #TEMP_PICK  
  
SUCCESS:  
   SELECT * FROM #TEMP_PICK  
   DROP Table #TEMP_PICK  
  
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  

GO