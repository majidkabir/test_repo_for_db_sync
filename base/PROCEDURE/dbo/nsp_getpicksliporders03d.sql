SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : nsp_GetPickSlipOrders03d                                  */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: NJOW                                                        */
/*                                                                         */
/* Purpose: Pick Slip for SG Healthcare (SOS#138851)                       */
/*          (Modified from nsp_GetPickSlipOrders03)                        */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_print_pickorder03d                                      */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 2014-01-13  TLTING      1.1   Commit transaction                        */
/* 2014-02-12  Leong       1.2   Prevent Pickslip number not tally with    */
/*                               nCounter table. (Leong01)                 */
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length      */
/***************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders03d]
(
   @c_loadkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- Added by YokeBeen on 30-Jul-2004 (SOS#25474) - (YokeBeen01)
   -- Added SKU.SUSR3 (Agency) & ORDERS.InvoiceNo.

DECLARE @c_pickheaderkey       NVARCHAR(10),
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
       /*@c_Notes1             NVARCHAR(60), SOS133437 START
         @c_Notes2             NVARCHAR(60),*/
         @c_Notes1             NVARCHAR(200),
         @c_Notes2             NVARCHAR(200), --SOS133437 END
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
         @c_firsttime          NVARCHAR(1),
         @c_logicalloc         NVARCHAR(18),
         @c_Lottable01         NVARCHAR(18),
         @c_Lottable02         NVARCHAR(18),
         @c_Lottable03         NVARCHAR(18),
         @d_Lottable04         DATETIME,
         @d_Lottable05         DATETIME,
         @n_packpallet         INT,
         @n_packcasecnt        INT,
         @c_externorderkey     NVARCHAR(50),   --tlting_ext
         @n_pickslips_required INT,
         @dt_deliverydate      DATETIME

DECLARE @c_PrevOrderKey NVARCHAR(10),
         @n_Pallets     INT,
         @n_Cartons     INT,
         @n_Eaches      INT,
         @n_UOMQty      INT,
       --@c_Susr3       NVARCHAR(18),  -- (YokeBeen01)
         @c_InvoiceNo   NVARCHAR(10)   -- (YokeBeen01)

DECLARE @n_starttcnt INT

SELECT @n_starttcnt = @@TRANCOUNT
SELECT @n_pickslips_required = 0 -- (Leong01)

WHILE @@TRANCOUNT > 0
BEGIN
   COMMIT TRAN
END

BEGIN TRAN
   CREATE TABLE #temp_pick
      (
         PickSlipNo      NVARCHAR(10) NULL,
         LoadKey         NVARCHAR(10),
         OrderKey        NVARCHAR(10),
         ConsigneeKey    NVARCHAR(15),
         Company         NVARCHAR(45),
         Addr1           NVARCHAR(45) NULL,
         Addr2           NVARCHAR(45) NULL,
         Addr3           NVARCHAR(45) NULL,
         PostCode        NVARCHAR(15) NULL,
         Route           NVARCHAR(10) NULL,
         Route_Desc      NVARCHAR(60) NULL, -- RouteMaster.Desc
         TrfRoom         NVARCHAR(5)  NULL,  -- LoadPlan.TrfRoom
       --Notes1          NVARCHAR(60) NULL, --SOS133437 START
       --Notes2          NVARCHAR(60) NULL,
         Notes1          NVARCHAR(200) NULL,
         Notes2          NVARCHAR(200) NULL, --SOS133437 END
         LOC             NVARCHAR(10)  NULL,
         SKU             NVARCHAR(20),
         SkuDesc         NVARCHAR(60),
         Qty             INT,
         TempQty1        INT,
         TempQty2        INT,
         PrintedFlag     NVARCHAR(1) NULL,
         Zone            NVARCHAR(1),
         PgGroup         INT,
         RowNum          INT,
         Lot             NVARCHAR(10),
         Carrierkey      NVARCHAR(60) NULL,
         VehicleNo       NVARCHAR(10) NULL,
         Lottable01      NVARCHAR(18) NULL,
         Lottable02      NVARCHAR(18) NULL,
         Lottable03      NVARCHAR(18) NULL,
         Lottable04      DATETIME NULL,
         Lottable05      DATETIME NULL,
         packpallet      INT,
         packcasecnt     INT,
         externorderkey  NVARCHAR(50) NULL,  --tlting_ext
         LogicalLoc      NVARCHAR(18) NULL,
         DeliveryDate    DATETIME NULL,
         Uom             NVARCHAR(10),     -- SOS24726
      -- Susr3           NVARCHAR(18) NULL,  -- (YokeBeen01)
         InvoiceNo       NVARCHAR(10) NULL,  -- (YokeBeen01)
         Ovas            CHAR(30) NULL,   -- SOS53643 (Loon01)
         Putawayzone     NVARCHAR(10) NULL
         )

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS ( SELECT 1
               FROM PickHeader (NOLOCK)
               WHERE ExternOrderKey = @c_loadkey
               AND Zone = "3" )
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = "N"
   END -- Record Not Exists

   INSERT INTO #Temp_Pick
      ( PickSlipNo,
         LoadKey,
         OrderKey,
         ConsigneeKey,
         Company,
         Addr1,
         Addr2,
         PgGroup,
         Addr3,
         PostCode,
         Route,
         Route_Desc,
         TrfRoom,
         Notes1,
         RowNum,
         Notes2,
         LOC,
         SKU,
         SkuDesc,
         Qty,
         TempQty1,
         TempQty2,
         PrintedFlag,
         Zone,
         Lot,
         CarrierKey,
         VehicleNo,
         Lottable01,
         Lottable02,
         Lottable03,
         Lottable04,
         Lottable05,
         packpallet,
         packcasecnt,
         externorderkey,
         LogicalLoc,
         DeliveryDate,
         UOM,       -- SOS24726
       --Susr3,     InvoiceNo, -- (YokeBeen01)
         InvoiceNo,
         Ovas,
         Putawayzone
      ) -- SOS53643 (Loon01)
   SELECT ( SELECT PICKHEADERKEY
            FROM PICKHEADER (NOLOCK)
            WHERE ExternOrderKey = @c_LoadKey
            AND OrderKey = PickDetail.OrderKey
            AND Zone = '3'
          ),
         @c_LoadKey AS LoadKey,
         PickDetail.OrderKey,
         ISNULL(ORDERS.BillToKey, '') AS ConsigneeKey,
         ISNULL(ORDERS.c_Company, '') AS Company,
         ISNULL(ORDERS.c_Address1, '') AS Addr1,
         ISNULL(ORDERS.c_Address2, '') AS Addr2,
         0 AS PgGroup,
         ISNULL(ORDERS.c_Address3, '') AS Addr3,
         ISNULL(ORDERS.c_Zip, '') AS PostCode,
         ISNULL(ORDERS.Route, '') AS Route,
         ISNULL(RouteMaster.Descr, '') Route_Desc,
         ORDERS.Door AS TrfRoom,
       --CONVERT(char(60), IsNull(ORDERS.Notes, '')) Notes1,  SOS133437
         CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes, '')) Notes1,  -- SOS133437
         0 AS RowNo,
       --CONVERT(char(60), IsNull(ORDERS.Notes2, '')) Notes2,  SOS133437
         CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes2, '')) Notes2, -- SOS133437
         PickDetail.loc,
         PickDetail.sku,
         ISNULL(Sku.Descr, '') SkuDesc,
         SUM(PickDetail.qty) AS Qty,
         CASE PickDetail.UOM
            WHEN '1' THEN PACK.Pallet
            WHEN '2' THEN PACK.CaseCnt
            WHEN '3' THEN PACK.InnerPack
            ELSE 1
         END AS UOMQty,
         0 AS TempQty2,
         ISNULL(( SELECT DISTINCT
                  'Y'
                  FROM PickHeader (NOLOCK)
                  WHERE ExternOrderKey = @c_LoadKey
                  AND Zone = '3'
               ), 'N') AS PrintedFlag,
         '3' Zone,
         PickDetail.Lot,
         '' CarrierKey,
         '' AS VehicleNo,
         Lotattribute.Lottable01,
         Lotattribute.Lottable02,
         Lotattribute.Lottable03,
         ISNULL(Lotattribute.Lottable04, '19000101') Lottable04,
         ISNULL(Lotattribute.Lottable05, '19000101') Lottable05,
         PACK.Pallet,
         PACK.CaseCnt,
         ORDERS.ExternOrderKey AS ExternOrderKey,
         ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,
         ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,
         PACK.PackUOM3, -- ORDERDETAIL.UOM, -- SOS24726
       --SKU.SUSR3,    -- (YokeBeen01)
         ORDERS.InvoiceNo,    -- (YokeBeen01)
         SKU.Ovas,
         LOC.Putawayzone
         FROM LOADPLANDETAIL (NOLOCK)
         JOIN ORDERS (NOLOCK) ON ( ORDERS.Orderkey = LoadPlanDetail.Orderkey )
      -- Start : SOS38059
      -- JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = LOADPLANDETAIL.Orderkey AND ORDERDETAIL.Loadkey = LOADPLANDETAIL.Loadkey) -- SOS24726
         JOIN ORDERDETAIL (NOLOCK) ON ( ORDERDETAIL.Orderkey = ORDERS.Orderkey )
      -- End : SOS38059
         JOIN Storer (NOLOCK) ON ( ORDERS.StorerKey = Storer.StorerKey )
         LEFT OUTER JOIN RouteMaster ON ( RouteMaster.Route = ORDERS.Route )
      -- SOS24726
      -- JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey  and  ORDERS.Orderkey = PICKDETAIL.Orderkey)
         JOIN PickDetail (NOLOCK) ON ( PickDetail.OrderKey = ORDERDETAIL.Orderkey
                                       AND PickDetail.OrderLineNumber = ORDERDETAIL.OrderLineNumber
                                     )
         JOIN LotAttribute (NOLOCK) ON ( PickDetail.Lot = LotAttribute.Lot )
         JOIN Sku (NOLOCK) ON ( Sku.StorerKey = PickDetail.StorerKey
                                AND Sku.Sku = PickDetail.Sku
                              )
      -- Start : SOS38059
      -- JOIN PACK (NOLOCK) ON (PickDetail.Packkey = PACK.Packkey)
         JOIN PACK (NOLOCK) ON ( SKU.Packkey = PACK.Packkey )
      -- End : SOS38059
         JOIN LOC (NOLOCK) ON ( PICKDETAIL.LOC = LOC.LOC )
         WHERE PickDetail.Status >= '0'
         AND LoadPlanDetail.LoadKey = @c_LoadKey
         GROUP BY PickDetail.OrderKey,
         ISNULL(ORDERS.BillToKey, ''),
         ISNULL(ORDERS.c_Company, ''),
         ISNULL(ORDERS.C_Address1, ''),
         ISNULL(ORDERS.C_Address2, ''),
         ISNULL(ORDERS.C_Address3, ''),
         ISNULL(ORDERS.C_Zip, ''),
         ISNULL(ORDERS.Route, ''),
         ISNULL(RouteMaster.Descr, ''),
         ORDERS.Door,
       --CONVERT(char(60), IsNull(ORDERS.Notes,  '')),
       --CONVERT(char(60), IsNull(ORDERS.Notes2, '')),
         CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes, '')),  /*SOS133437 START*/
         CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes2, '')),  /*SOS133437 END*/
         PickDetail.loc,
         PickDetail.sku,
         ISNULL(Sku.Descr, ''),
         CASE PickDetail.UOM
            WHEN '1' THEN PACK.Pallet
            WHEN '2' THEN PACK.CaseCnt
            WHEN '3' THEN PACK.InnerPack
            ELSE 1
         END,
         Pickdetail.Lot,
         LotAttribute.Lottable01,
         LotAttribute.Lottable02,
         LotAttribute.Lottable03,
         ISNULL(LotAttribute.Lottable04, '19000101'),
         ISNULL(LotAttribute.Lottable05, '19000101'),
         PACK.Pallet,
         PACK.CaseCnt,
         ORDERS.ExternOrderKey,
         ISNULL(LOC.LogicalLocation, ''),
         ISNULL(ORDERS.DeliveryDate, '19000101'),
         PACK.PackUOM3,    -- ORDERDETAIL.UOM, -- SOS24726
         --SKU.SUSR3,      -- (YokeBeen01)
         ORDERS.InvoiceNo, -- (YokeBeen01)
         sku.ovas,         -- SOS53643 (Loon01)
         LOC.Putawayzone

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
   WHERE ExternOrderKey = @c_loadkey
   AND Zone = "3"
   AND PickType = '0'

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
         -- SELECT @c_PrintedFlag = "Y"
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
   ELSE
   IF @n_pickslips_required > 0
   BEGIN
      BEGIN TRAN

      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT,
                          @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, 0,
                          @n_pickslips_required

      COMMIT TRAN

      BEGIN TRAN
      INSERT INTO PICKHEADER
         (  PickHeaderKey,
            OrderKey,
            ExternOrderKey,
            PickType,
            Zone,
            TrafficCop
         )
      SELECT 'P' + RIGHT(REPLICATE('0', 9)
                 + dbo.fnc_LTrim(dbo.fnc_RTrim(STR(CAST(@c_pickheaderkey AS INT)
                 + ( SELECT
                     COUNT(DISTINCT orderkey)
                     FROM
                     #TEMP_PICK AS Rank
                     WHERE
                     Rank.OrderKey < #TEMP_PICK.OrderKey
                     AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' -- (Leong01)
                   ))-- str
                   ))-- dbo.fnc_RTrim
                 , 9),
               OrderKey,
               LoadKey,
               '0',
               '3',
               ''
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)
      GROUP BY LoadKey,
               OrderKey

      UPDATE #TEMP_PICK
         SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
        AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
        AND PICKHEADER.Zone = '3'
        AND ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' -- (Leong01)

      UPDATE PICKDETAIL
         SET PickSlipNo = #TEMP_PICK.PickSlipNo,
             TrafficCop = NULL
      FROM #TEMP_PICK
      WHERE #TEMP_PICK.OrderKey = PICKDETAIL.OrderKey
        AND ISNULL(RTRIM(PICKDETAIL.PickSlipNo),'') = '' -- (Leong01)

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   GOTO SUCCESS

   FAILURE:
   DELETE FROM #TEMP_PICK

   SUCCESS:
   SELECT *
   FROM #TEMP_PICK

   DROP TABLE #TEMP_PICK

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END
END

GO