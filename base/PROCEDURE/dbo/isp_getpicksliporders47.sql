SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : isp_GetPickSlipOrders47                                   */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: 251367-L'OREAL - SG - Pick Slip                                */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_print_pickorder47                                       */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 12-Feb-2014 Leong       1.1   Prevent Pickslip number not tally with    */
/*                               nCounter table. (Leong01)                 */
/* 28-Jan-2019  TLTING_ext 1.2   enlarge externorderkey field length      */
/***************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders47] (@c_loadkey NVARCHAR(10))
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
        @c_Route_Desc         NVARCHAR(60),
        @c_TrfRoom            NVARCHAR(5),
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
        @c_firsttime          NVARCHAR(1),
        @c_logicalloc         NVARCHAR(18),
        @c_Lottable02         NVARCHAR(10),
        @d_Lottable04         DATETIME,
        @n_packpallet         INT,
        @n_packcasecnt        INT,
        @c_externorderkey     NVARCHAR(50),   --tlting_ext
        @n_pickslips_required INT,
        @c_areakey            NVARCHAR(10),
        @c_skugroup           NVARCHAR(10)

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
        Route_Desc       NVARCHAR(60) NULL,
        TrfRoom          NVARCHAR(5) NULL,
        Notes1           NVARCHAR(60) NULL,
        Notes2           NVARCHAR(60) NULL,
        LOC              NVARCHAR(10) NULL,
        ID               NVARCHAR(18) NULL,
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
        Lottable02       NVARCHAR(18) NULL,
        Lottable04       DATETIME NULL,
        packpallet       INT,
        packcasecnt      INT,
        packinner        INT,
        packeaches       INT,
        externorderkey   NVARCHAR(50) NULL,   --tlting_ext
        LogicalLoc       NVARCHAR(18) NULL,
        Areakey          NVARCHAR(10) NULL,
        UOM              NVARCHAR(10),
        Pallet_cal       INT,
        Cartons_cal      INT,
        inner_cal        INT,
        Each_cal         INT,
        Total_cal        INT,
        DeliveryDate     DATETIME NULL,
        RetailSku        NVARCHAR(20) NULL,
        BuyerPO          NVARCHAR(20) NULL,
        InvoiceNo        NVARCHAR(10) NULL,
        OrderDate        DATETIME NULL,
        Susr4            NVARCHAR(18) NULL,
        vat              NVARCHAR(18) NULL,
        OVAS             NVARCHAR(30) NULL,
        SKUGROUP         NVARCHAR(10) NULL,
        Storerkey        NVARCHAR(15) NULL,
        Country          NVARCHAR(20) NULL,
        Brand            NVARCHAR(50) NULL
       )

   INSERT INTO #TEMP_PICK
      (PickSlipNo,     LoadKey,         OrderKey,    ConsigneeKey,
       Company,        Addr1,           Addr2,       PgGroup,
       Addr3,          PostCode,        Route,
       Route_Desc,     TrfRoom,         Notes1,      RowNum,
       Notes2,         LOC,             ID,          SKU,
       SkuDesc,        Qty,             TempQty1,
       TempQty2,       PrintedFlag,     Zone,
       Lot,            CarrierKey,      VehicleNo,   Lottable02,
       Lottable04,     packpallet,      packcasecnt, packinner,
       packeaches,     externorderkey,  LogicalLoc,  Areakey,    UOM,
       Pallet_cal,     Cartons_cal,     inner_cal,   Each_cal,   Total_cal,
       DeliveryDate,   RetailSku,       BuyerPO,     InvoiceNo,  OrderDate,
       Susr4,          Vat,             OVAS,        SKUGROUP,   Storerkey, Country, Brand)
   SELECT
      (SELECT PICKHEADERKEY FROM PICKHEADER
       WHERE ExternOrderKey = @c_LoadKey
       AND OrderKey = PickDetail.OrderKey
       AND ZONE = '3'),
      @c_LoadKey as LoadKey,
      PickDetail.OrderKey,
      ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,
      ISNULL(ORDERS.c_Company, '')  AS Company,
      ISNULL(ORDERS.C_Address1,'') AS Addr1,
      ISNULL(ORDERS.C_Address2,'')  AS Addr2,
      0 AS PgGroup,
      ISNULL(ORDERS.C_Address3,'') AS Addr3,
      ISNULL(ORDERS.C_Zip,'') AS PostCode,
      ISNULL(ORDERS.Route,'') AS Route,
      ISNULL(RouteMaster.Descr, '') Route_Desc,
      CONVERT(CHAR(5),ORDERS.Door) AS TrfRoom,
      CONVERT(CHAR(60), ISNULL(ORDERS.Notes,  '')) Notes1,
      0 AS RowNo,
      CONVERT(CHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,
      PickDetail.loc,
      PickDetail.id,
      PickDetail.sku,
      ISNULL(Sku.Descr,'') SkuDescr,
      SUM(PickDetail.qty) as Qty,
      1 AS UOMQTY,
      0 AS TempQty2,
      ISNULL((SELECT DISTINCT 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,
      '3' Zone,
      Pickdetail.Lot,
      '' CarrierKey,
      '' AS VehicleNo,
      LotAttribute.Lottable02,
      ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,
      PACK.Pallet,
      PACK.CaseCnt,
      pack.innerpack,
      PACK.Qty,
      ORDERS.ExternOrderKey AS ExternOrderKey,
      ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,
      ISNULL(AreaDetail.AreaKey, '00') AS Areakey,
      ISNULL(OrderDetail.UOM, '') AS UOM,
      Pallet_cal = CASE Pack.Pallet WHEN 0 THEN 0
                     ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)
                   END,
      Cartons_cal = 0,
      inner_cal = 0,
      Each_cal = 0,
      Total_cal = sum(pickdetail.qty),
      ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,
      ISNULL(Sku.RetailSku,'') RetailSku,
      ISNULL(ORDERS.BuyerPO,'') BuyerPO,
      ISNULL(ORDERS.InvoiceNo,'') InvoiceNo,
      ISNULL(ORDERS.OrderDate, '19000101') OrderDate,
      SKU.Susr4,
      ST.vat,
      SKU.OVAS,
      SKU.SKUGROUP,
      ORDERS.Storerkey,
      CASE WHEN ORDERS.C_ISOCntryCode IN ('ID','IN','KR','PH','TH','TW','VN') THEN
           'EXPORT' ELSE ISNULL(ORDERS.C_ISOCntryCode,'') END,
      ISNULL(BRAND.BrandName,'')
      FROM pickdetail (nolock)
      JOIN orders (nolock) on pickdetail.orderkey = orders.orderkey
      JOIN lotattribute (nolock) on pickdetail.lot = lotattribute.lot
      JOIN loadplandetail (nolock) on pickdetail.orderkey = loadplandetail.orderkey
      JOIN orderdetail (nolock) on pickdetail.orderkey = orderdetail.orderkey and pickdetail.orderlinenumber = orderdetail.orderlinenumber
      JOIN storer (nolock) on pickdetail.storerkey = storer.storerkey
      JOIN sku (nolock) on pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey
      JOIN pack (nolock) on pickdetail.packkey = pack.packkey
      JOIN loc (nolock) on pickdetail.loc = loc.loc
      LEFT JOIN routemaster (nolock) on orders.route = routemaster.route
      LEFT JOIN areadetail (nolock) on loc.putawayzone = areadetail.putawayzone
      LEFT JOIN storer st (nolock) on orders.consigneekey = st.storerkey
      LEFT JOIN (SELECT O.Orderkey, MAX(SUBSTRING(LTRIM(ISNULL(CL.Description,'')),6,50)) AS BrandName
                 FROM ORDERS O (NOLOCK)
                 JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                 JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
                 LEFT JOIN CODELKUP CL (NOLOCK) ON SKU.ItemClass = CL.Code AND CL.Listname = 'ITEMCLASS'
                 WHERE O.Loadkey = @c_Loadkey
                 GROUP BY O.Orderkey
                 HAVING COUNT(DISTINCT SUBSTRING(LTRIM(ISNULL(CL.Description,'')),6,50)) = 1) BRAND ON ORDERS.Orderkey = BRAND.Orderkey
      WHERE PickDetail.Status < '5'
      AND LoadPlanDetail.LoadKey = @c_LoadKey
      GROUP BY PickDetail.OrderKey,
               ISNULL(ORDERS.ConsigneeKey, ''),
               ISNULL(ORDERS.c_Company, ''),
               ISNULL(ORDERS.C_Address1,''),
               ISNULL(ORDERS.C_Address2,''),
               ISNULL(ORDERS.C_Address3,''),
               ISNULL(ORDERS.C_Zip,''),
               ISNULL(ORDERS.Route,''),
               ISNULL(RouteMaster.Descr, ''),
               CONVERT(CHAR(5),ORDERS.Door),
               CONVERT(CHAR(60), ISNULL(ORDERS.Notes,  '')),
               CONVERT(CHAR(60), ISNULL(ORDERS.Notes2, '')),
               PickDetail.loc,
               PickDetail.id,
               PickDetail.sku,
               ISNULL(Sku.Descr,''),
               Pickdetail.Lot,
               LotAttribute.Lottable02,
               ISNULL(LotAttribute.Lottable04, '19000101'),
               PACK.Pallet,
               PACK.CaseCnt,
               pack.innerpack,
               PACK.Qty,
               ORDERS.ExternOrderKey,
               ISNULL(LOC.LogicalLocation, ''),
               ISNULL(AreaDetail.AreaKey, '00'),
               ISNULL(OrderDetail.UOM, ''),
               ISNULL(ORDERS.DeliveryDate, '19000101'),
               ISNULL(Sku.RetailSku,''),
               ISNULL(ORDERS.BuyerPO,''),
               ISNULL(ORDERS.InvoiceNo,''),
               ISNULL(ORDERS.OrderDate, '19000101'),
               SKU.Susr4,
               ST.vat,
               SKU.OVAS,
               SKU.SKUGROUP,
               ORDERS.Storerkey,
               CASE WHEN ORDERS.C_ISOCntryCode IN ('ID','IN','KR','PH','TH','TW','VN') THEN
                    'EXPORT' ELSE ISNULL(ORDERS.C_ISOCntryCode,'') END,
               ISNULL(BRAND.BrandName,'')

   UPDATE #temp_pick
   SET cartons_cal = CASE packcasecnt
                        WHEN 0 THEN 0
                        ELSE FLOOR(total_cal/packcasecnt)
                     END

   UPDATE #temp_pick
   SET inner_cal = CASE packinner
                      WHEN 0 THEN 0
                      ELSE FLOOR(total_cal/packinner) - ((packcasecnt*cartons_cal)/packinner)
                   END

   UPDATE #temp_pick
   SET each_cal = total_cal - (packcasecnt*cartons_cal) - (packinner*inner_cal)

   BEGIN TRAN
      UPDATE PickHeader WITH (ROWLOCK)
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

         BEGIN TRAN

         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
                      dbo.fnc_LTrim( dbo.fnc_RTrim(
                      STR(
                          CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)
                                                            FROM #TEMP_PICK as Rank
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
      DROP TABLE #TEMP_PICK

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END
END

GO