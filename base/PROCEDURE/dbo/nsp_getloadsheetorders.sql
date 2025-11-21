SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_GetLoadSheetOrders                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: IDS                                                      */
/*                                                                      */
/* Purpose: RG BLP STORER Import                                        */
/*                                                                      */
/* Input Parameters:  @c_LoadKey                                        */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Called By: d_dw_print_loadsheet                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author      Ver   Purposes                            */
/* 14-May-2010    Audrey      1.1   SOS# 173200- add filter by storerkey*/
/* 15-Aug-2011    YTWan       1.2   SOS#222245 - return Storerkey for   */
/*                                  logo retrieval at PB report.(Wan01) */
/* 28-Jan-2019    TLTING_ext  1.3   enlarge externorderkey field length */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetLoadSheetOrders] (@c_LoadKey NVARCHAR(10))
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 -- Modified by MaryVong on 06-May-2004 (SOS22824)
 -- Display UOM1 and UOM3 in the report; get qty in cartons and eaches; add Address4;
 -- Modified by MaryVong on 10-May-2004
 -- Change PACK.Casecnt, not based on PickDetail.UOM
 -- Modified by YTWan 07-Jul-2004 (SOS#24811)
   DECLARE @c_PickHeaderKey      NVARCHAR(10),
            @n_continue          int,
            @c_errmsg            NVARCHAR(255),
            @b_success           int,
            @n_err               int,
            @c_Sku               NVARCHAR(20),
            --@n_Qty             int,
            @n_TotalQty          int,       -- SOS22824 Total Qty in eaches
            @c_Loc               NVARCHAR(10),
            --@n_cases           int,
            @n_perpallet         int,
            @c_Storer            NVARCHAR(15),
            @c_OrderKey          NVARCHAR(10),
            @c_ExternOrderKey    NVARCHAR(50),  --tlting_ext   -- (SOS#24811) Expand ExternOrderkey to 30
            @c_ConsigneeKey      NVARCHAR(15),
            @c_Company           NVARCHAR(45),
            @c_Addr1             NVARCHAR(45),
            @c_Addr2             NVARCHAR(45),
            @c_Addr3             NVARCHAR(45),
            @c_Addr4             NVARCHAR(45),  -- SOS22824
            @c_PostCode          NVARCHAR(15),
            @c_Route             NVARCHAR(10),
            @c_DeliveryMode      NVARCHAR(10), -- SOS20546
            @c_Route_Desc        NVARCHAR(60), -- RouteMaster.Desc
            @c_TrfRoom           NVARCHAR(5),  -- LoadPlan.TrfRoom
            @c_Notes1            NVARCHAR(60),
            @c_Notes2            NVARCHAR(60),
            @c_SkuDesc           NVARCHAR(60),
            @n_CaseCnt           int,
            @n_PalletCnt         int,
            @c_ReceiptTm         NVARCHAR(20),
            @c_PrintedFlag       NVARCHAR(1),
            --@c_LowestUOM       NVARCHAR(10),  -- SOS22824
            @c_uUOM              NVARCHAR(10),  -- SOS22824
            @c_UOM1              NVARCHAR(10),  -- SOS22824
            @c_UOM3              NVARCHAR(10),  -- SOS22824
            --@n_UOM3            int,    -- SOS22824
            @c_Lot               NVARCHAR(10),
            @c_StorerKey         NVARCHAR(15),
            @c_Zone              NVARCHAR(1),
            @n_PgGroup           int,
            @n_TotCases          int,
            @n_RowNo             int,
            @c_PrevSKU           NVARCHAR(20),
            @n_SKUCount          int,
            @c_Carrierkey        NVARCHAR(60),
            @c_VehicleNo         NVARCHAR(10),
            @c_firstorderkey     NVARCHAR(10),
            @c_SuperOrderFlag    NVARCHAR(1),
            @c_FirstTime         NVARCHAR(1),
            @c_LogicalLoc        NVARCHAR(18),
            @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),  -- SOS14561
            @d_Lottable04        datetime,
            @n_PackPallet        int,
            @n_PackCasecnt       int,
            @c_OrderLinenumber   NVARCHAR(5),
            @c_SerialNo          NVARCHAR(18),
            @d_OrderDate         datetime,
            @d_DeliveryDate      datetime,
            @c_InvoiceNo         NVARCHAR(18),  -- SOS20546
            @c_Stop              NVARCHAR(10),  -- SOS20546
            @n_QtyCartons        int,    -- SOS22824
            @n_QtyEaches         int    -- SOS22824

   DECLARE @c_PrevOrderKey   NVARCHAR(10),
            @n_Pallets        int,
            @n_Cartons        int,
            @n_Eaches         int,
            @n_UOMQty         int

   SET @c_Storerkey = ''                                                                           --(Wan01)
CREATE TABLE #temp_pick
(  PickSlipNo     NVARCHAR(10),
LoadKey           NVARCHAR(10),
OrderKey          NVARCHAR(10),
ExternOrderKey    NVARCHAR(50),  --tlting_ext  -- (SOS#24811) Expand ExternOrderkey to 30
ConsigneeKey      NVARCHAR(15),
Company           NVARCHAR(45),
Addr1             NVARCHAR(45),
Addr2             NVARCHAR(45),
Addr3             NVARCHAR(45),
Addr4             NVARCHAR(45),  -- SOS22824
PostCode          NVARCHAR(15),
Route             NVARCHAR(10),
Route_Desc        NVARCHAR(60), -- RouteMaster.Desc
TrfRoom           NVARCHAR(5),  -- LoadPlan.TrfRoom
Notes1            NVARCHAR(60),
Notes2            NVARCHAR(60),
--LowestUOM       NVARCHAR(10), -- SOS22824
UOM1              NVARCHAR(10), -- SOS22824
UOM3              NVARCHAR(10), -- SOS22824
SKU               NVARCHAR(20),
SkuDesc           NVARCHAR(60),
TotalQty          int,
TempQty1          int,
TempQty2          int,
PrintedFlag       NVARCHAR(1),
Zone              NVARCHAR(1),
PgGroup           int,
RowNum            int,
Lot               NVARCHAR(10),
Carrierkey        NVARCHAR(60),
VehicleNo         NVARCHAR(10),
Lottable01        NVARCHAR(18),
Lottable02        NVARCHAR(18),
Lottable03        NVARCHAR(18), -- SOS14561
Lottable04        datetime NULL,
PackPallet        int,
PackCasecnt       int,
SerialNo          NVARCHAR(18),
OrderDate         datetime,
DeliveryDate      datetime,
InvoiceNo         NVARCHAR(18), -- SOS20546, Add by June 17.Mar.2004
Stop              NVARCHAR(10), -- SOS20546
DeliveryMode      NVARCHAR(10), -- SOS20546
QtyCartons        int,   -- SOS22824
QtyEaches         int,   -- SOS22824
Storerkey         NVARCHAR(15))                                                                     --(Wan01)

 SELECT @n_continue = 1
 SELECT @n_RowNo = 0
 SELECT @c_FirstOrderKey = 'N'

 DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
 SELECT PickDetail.sku,     PickDetail.loc,
      SUM(PickDetail.qty),  --PACK.Qty,
      PickDetail.storerkey, PickDetail.OrderKey,
      PickDetail.UOM,       LOC.LogicalLocation,
      Pickdetail.Lot,   Pickdetail.OrderLineNumber
 FROM PickDetail (NOLOCK),  LoadPlanDetail (NOLOCK),
      PACK (NOLOCK),        LOC (NOLOCK)
 WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
 AND    PickDetail.Status < '5'
 AND    PickDetail.Packkey = PACK.Packkey
 AND    LOC.Loc = PICKDETAIL.Loc
 AND    LoadPlanDetail.LoadKey = @c_LoadKey
 GROUP BY PickDetail.sku,     PickDetail.loc,      PACK.Qty,
        PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
      LOC.LogicalLocation,  Pickdetail.Lot, Pickdetail.OrderLineNumber
 ORDER BY PICKDETAIL.ORDERKEY
 OPEN pick_cur

 SELECT @c_PrevOrderKey = ""
 FETCH NEXT FROM pick_cur INTO @c_Sku, @c_Loc, @n_TotalQty, @c_StorerKey, --@n_UOM3,
        @c_OrderKey,  @c_uUOM, @c_LogicalLoc, @c_Lot, @c_OrderLinenumber
 WHILE (@@FETCH_STATUS <> -1)
 BEGIN
  SELECT @c_PickHeaderKey = PickHeaderKey FROM PickHeader (NOLOCK)
  WHERE ExternOrderKey = @c_LoadKey
  AND   Zone = "7"
  -- AND   OrderKey = @c_OrderKey
  IF @c_OrderKey = ""
  BEGIN
  SELECT @c_ConsigneeKey = "",
         @c_Company = "",
         @c_Addr1 = "",
         @c_Addr2 = "",
         @c_Addr3 = "",
         @c_Addr4 = "",    -- SOS22824
         @c_PostCode = "",
         @c_Route = "",
         @c_Route_Desc = "",
         @c_Notes1 = "",
         @c_Notes2 = "",
         @c_InvoiceNo = "",  -- SOS20546
         @c_Stop = "",    -- SOS20546
         @c_DeliveryMode = ""  -- SOS20546
  END
  ELSE
  BEGIN
   SELECT @c_ExternOrderKey = ORDERS.ExternOrderKey,
            @c_ConsigneeKey = Orders.BillToKey,
            @c_Company      = ORDERS.c_Company,
            @c_Addr1        = ORDERS.C_Address1,
            @c_Addr2        = ORDERS.C_Address2,
            @c_Addr3        = ORDERS.C_Address3,
            @c_Addr4        = ORDERS.C_Address4,     -- SOS22824
            @c_PostCode     = ORDERS.C_Zip,
            @c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes),
            @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),
            @c_InvoiceNo    = ORDERS.InvoiceNo,    -- SOS20546
            @c_Stop         = ORDERS.Stop,      -- SOS20546,
            @c_DeliveryMode = IsNULL(ORDERS.Route, "")  -- SOS20546
   FROM   ORDERS (NOLOCK)
   WHERE  ORDERS.OrderKey = @c_OrderKey
   END -- IF @c_OrderKey = ""

   SELECT @c_TrfRoom      = IsNULL(LoadPlan.TrfRoom, ""),
            @c_Route      = IsNULL(LoadPlan.Route, ""),
            @c_VehicleNo  = IsNULL(LoadPlan.TruckSize, ""),
            @c_Carrierkey = IsNULL(LoadPlan.CarrierKey,"")
   FROM   LoadPlan (NOLOCK)
   WHERE  Loadkey = @c_LoadKey

   SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, "")
   FROM   RouteMaster (NOLOCK)
   WHERE  Route = @c_Route

   SELECT @c_SkuDesc = IsNULL(Descr,"")
   FROM   SKU  (NOLOCK)
   WHERE  SKU = @c_Sku
   AND    STORERKEY = @c_StorerKey -- SOS# 173200

   SELECT @c_Lottable01 = Lottable01,
          @c_Lottable02 = Lottable02,
          @c_Lottable03 = Lottable03, -- SOS14561
          @d_Lottable04 = Lottable04
   FROM   LOTATTRIBUTE (NOLOCK)
   WHERE  LOT = @c_Lot

   IF @c_Lottable01    IS NULL SELECT @c_Lottable01 = ""
   IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ""
   IF @c_Lottable03    IS NULL SELECT @c_Lottable03 = "" -- SOS14561
   --         IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = "01/01/1900"
   IF @c_Notes1        IS NULL SELECT @c_Notes1 = ""
   IF @c_Notes2        IS NULL SELECT @c_Notes2 = ""
   IF @c_ExternOrderKey IS NULL SELECT @c_ExternOrderKey = ""
   IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ""
   IF @c_Company       IS NULL SELECT @c_Company = ""
   IF @c_Addr1         IS NULL SELECT @c_Addr1 = ""
   IF @c_Addr2         IS NULL SELECT @c_Addr2 = ""
   IF @c_Addr3         IS NULL SELECT @c_Addr3 = ""
   IF @c_Addr4         IS NULL SELECT @c_Addr4 = ""    -- SOS22824
   IF @c_PostCode      IS NULL SELECT @c_PostCode = ""
   IF @c_Route         IS NULL SELECT @c_Route = ""
   IF @c_DeliveryMode  IS NULL SELECT @c_DeliveryMode = ""
   IF @c_CarrierKey    IS NULL SELECT @c_Carrierkey = ""
   IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ""
   IF @c_SerialNo      IS NULL SELECT @c_SerialNo = ""
   IF @c_superorderflag = "Y" SELECT @c_OrderKey = ""
   IF @c_InvoiceNo     IS NULL SELECT @c_InvoiceNo = ""  -- SOS20546
   IF @c_Stop          IS NULL SELECT @c_Stop = ""   -- SOS20546

   SELECT @n_RowNo = @n_RowNo + 1
   SELECT @n_Pallets = 0,
      @n_Cartons = 0,
      @n_Eaches  = 0
   SELECT @n_UOMQty = 0,
      @n_QtyCartons = 0,  -- SOS22824
      @n_QtyEaches = 0    -- SOS22824

   --Remarked by MaryVong on 10-May-2004
   --SELECT @n_UOMQty = CASE @c_uUOM
   --            WHEN "1" THEN PACK.Pallet
   --            WHEN "2" THEN PACK.CaseCnt
   --                WHEN "3" THEN PACK.InnerPack
   --                ELSE 1
   --            END,
   SELECT @n_UOMQty = PACK.CaseCnt,
         @n_PackPallet=PACK.Pallet,
         @n_PackCasecnt=PACK.CaseCnt,
         --@c_LowestUOM = PACK.PackUOM3  -- SOS22824
         @c_UOM1 = PACK.PackUOM1,        -- SOS22824
         @c_UOM3 = PACK.PackUOM3         -- SOS22824
   FROM  PACK(NOLOCK), SKU(NOLOCK)
   WHERE SKU.SKU = @c_Sku
   AND SKU.StorerKey = @c_StorerKey    -- SOS22824
   AND   PACK.PackKey = SKU.PackKey

   -- SOS22824
   IF @n_UOMQty <> 0
   BEGIN
    SELECT @n_QtyCartons = @n_TotalQty / @n_UOMQty
    SELECT @n_QtyEaches = @n_TotalQty % @n_UOMQty
   END
   ELSE
   BEGIN
    SELECT @n_QtyEaches = @n_TotalQty
   END

   SELECT @c_SerialNo = SerialNo
   FROM   SERIALNO(NOLOCK)
   WHERE  OrderKey = @c_OrderKey
   AND    Sku = @c_Sku
   AND    OrderLinenumber = @c_OrderLinenumber

   SELECT @d_OrderDate = OrderDate,
          @d_DeliveryDate = DeliveryDate
   FROM   ORDERS(NOLOCK)
   WHERE  OrderKey = @c_OrderKey

          INSERT INTO #Temp_Pick
            (  PickSlipNo,          LoadKey,          OrderKey,         ExternOrderKey,  ConsigneeKey,
               Company,             Addr1,            Addr2,            PgGroup,
               Addr3,               Addr4,     PostCode,         Route,
               Route_Desc,          TrfRoom,          Notes1,           RowNum,
               Notes2,              UOM1,          UOM3,      SKU,
               SkuDesc,             TotalQty,       TempQty1,
               TempQty2,        PrintedFlag,      Zone,
               Lot,      CarrierKey,       VehicleNo,      Lottable01,  Lottable02,  Lottable03,
               Lottable04,      PackPallet,       PackCasecnt, SerialNo,  OrderDate, DeliveryDate,
               InvoiceNo,    Stop,      DeliveryMode, QtyCartons, QtyEaches  -- SOS20546, SOS22824
            ,  Storerkey   )                                                                       --(Wan01)
          VALUES
               (@c_PickHeaderKey,   @c_LoadKey,       @c_OrderKey,     @c_ExternOrderKey, @c_ConsigneeKey,
               @c_Company,         @c_Addr1,         @c_Addr2,        0,
               @c_Addr3,           @c_Addr4,   @c_PostCode,      @c_Route,
               @c_Route_Desc,      @c_TrfRoom,       @c_Notes1,       @n_RowNo,
               @c_Notes2,          @c_UOM1,       @c_UOM3,     @c_Sku,
               @c_SkuDesc,         @n_TotalQty,    CAST(@c_uUOM as int),
               @n_UOMQty,      'N',       '8',
               @c_Lot,   @c_Carrierkey,   @c_VehicleNo,     @c_Lottable01, @c_Lottable02, @c_Lottable03,
               @d_Lottable04,    @n_PackPallet,    @n_PackCasecnt, @c_SerialNo, @d_OrderDate, @d_DeliveryDate,
               @c_InvoiceNo,   @c_Stop,    @c_DeliveryMode, @n_QtyCartons, @n_QtyEaches   -- SOS20546, SOS22824
            ,  @c_Storerkey)                                                                       --(Wan01)

          SELECT @c_PrevOrderKey = @c_OrderKey
          FETCH NEXT FROM pick_cur INTO @c_Sku, @c_Loc, @n_TotalQty, @c_StorerKey, --@n_Uom3,
             @c_OrderKey, @c_uUOM, @c_LogicalLoc, @c_Lot, @c_OrderLinenumber
       END
       CLOSE pick_cur
       DEALLOCATE pick_cur
       SELECT * FROM #temp_pick

 END
 DROP Table #temp_pick

GO