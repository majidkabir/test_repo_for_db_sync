SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipNike01                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2014-Mar-21  TLTING        SQL20112 Bug                              */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nsp_GetPickSlipNike01    Script Date: 06/21/2001 5:14:10 PM ******/
CREATE PROC [dbo].[nsp_GetPickSlipNike01] (@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickSlipNo NVARCHAR(10),
   @c_OrderKey	 NVARCHAR(10),
   @c_BuyerPO	 NVARCHAR(20),
   @c_OrderGroup NVARCHAR(10),
   @c_ExternOrderKey NVARCHAR(50),  --tlting_ext
   @c_Route	 NVARCHAR(10),
   @c_Notes	 NVARCHAR(255),
   @d_OrderDate		datetime,
   @c_ConsigneeKey NVARCHAR(15),
   @c_Company	 NVARCHAR(45),
   @d_DeliveryDate	datetime,
   @c_Notes2	 NVARCHAR(255),
   @c_Loc	 NVARCHAR(10),
   @c_Sku	 NVARCHAR(20),
   @c_UOM	 NVARCHAR(10),
   @c_SkuSize	 NVARCHAR(5),
   @n_qty		int,
   @c_floor	 NVARCHAR(1),
   @c_tempfloor	 NVARCHAR(1),
   @c_temporderkey NVARCHAR(10),
   @b_success   	int,
   @n_err       	int,
   @c_errmsg     NVARCHAR(255),
   @c_tempsize	 NVARCHAR(5),
   @n_counter		int,
   @c_column	 NVARCHAR(10),
   @c_qty1	 NVARCHAR(10),
   @c_qty2	 NVARCHAR(10),
   @c_qty3	 NVARCHAR(10),
   @c_qty4	 NVARCHAR(10),
   @c_qty5	 NVARCHAR(10),
   @c_qty6	 NVARCHAR(10),
   @c_qty7	 NVARCHAR(10),
   @c_qty8	 NVARCHAR(10),
   @c_qty9	 NVARCHAR(10),
   @c_qty10	 NVARCHAR(10),
   @c_qty11	 NVARCHAR(10),
   @c_qty12	 NVARCHAR(10),
   @c_qty13	 NVARCHAR(10),
   @c_qty14	 NVARCHAR(10),
   @c_qty15	 NVARCHAR(10),
   @c_qty16	 NVARCHAR(10),
   @c_bin	 NVARCHAR(2),
   @c_temploc	 NVARCHAR(10)

   CREATE TABLE #TempPickSlip
   (PickSlipNo NVARCHAR(10) NULL,
   Loadkey NVARCHAR(10) NULL,
   OrderKey NVARCHAR(10) NULL,
   BuyerPO NVARCHAR(20) NULL,
   OrderGroup NVARCHAR(10) NULL,
   ExternOrderKey NVARCHAR(50) NULL,  --tlting_ext
   Route	 NVARCHAR(10) NULL,
   Notes	 NVARCHAR(255) NULL,
   OrderDate	datetime NULL,
   ConsigneeKey NVARCHAR(15) NULL,
   Company NVARCHAR(45) NULL,
   DeliveryDate	datetime NULL,
   Notes2	 NVARCHAR(255) NULL,
   Loc	 NVARCHAR(10) NULL,
   Sku	 NVARCHAR(20) NULL,
   UOM	 NVARCHAR(10) NULL,
   SkuSize1 NVARCHAR(5) NULL,
   SkuSize2 NVARCHAR(5) NULL,
   SkuSize3 NVARCHAR(5) NULL,
   SkuSize4 NVARCHAR(5) NULL,
   SkuSize5 NVARCHAR(5) NULL,
   SkuSize6 NVARCHAR(5) NULL,
   SkuSize7 NVARCHAR(5) NULL,
   SkuSize8 NVARCHAR(5) NULL,
   SkuSize9 NVARCHAR(5) NULL,
   SkuSize10 NVARCHAR(5) NULL,
   SkuSize11 NVARCHAR(5) NULL,
   SkuSize12 NVARCHAR(5) NULL,
   SkuSize13 NVARCHAR(5) NULL,
   SkuSize14 NVARCHAR(5) NULL,
   SkuSize15 NVARCHAR(5) NULL,
   SkuSize16 NVARCHAR(5) NULL,
   Defination NVARCHAR(1) NULL,
   LFloor	 NVARCHAR(5) NULL,
   Bin	 NVARCHAR(2) NULL)
   SELECT @c_tempfloor = '', @c_temporderkey = '', @c_temploc = ''
   DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT SUBSTRING(PICKDETAIL.Loc, 1, 6),
   SUBSTRING(PICKDETAIL.Sku, 1, 9) StyleColour,
   (CASE WHEN PICKDETAIL.UOM = '1' THEN PACK.PackUom4
   WHEN PICKDETAIL.UOM = '2' THEN PACK.PackUom1
   WHEN PICKDETAIL.UOM = '6' THEN PACK.PackUom3
END) UOM,
SUBSTRING(PICKDETAIL.Sku, 16, 5) SSize,
SUM(PICKDETAIL.Qty),
SUBSTRING(PICKDETAIL.Loc, 2, 1) LFloor,
ORDERS.BuyerPO,
ORDERS.OrderGroup,
ORDERS.ExternOrderKey,
ORDERS.Route,
CONVERT(NVARCHAR(255), ORDERS.Notes) Notes,
ORDERS.OrderDate,
ORDERS.ConsigneeKey,
ORDERS.C_Company,
ORDERS.DeliveryDate,
CONVERT(NVARCHAR(255), ORDERS.Notes2) Notes2,
ORDERS.Orderkey,
SUBSTRING(PICKDETAIL.Loc, 7, 2) Bin
FROM PICKDETAIL (NOLOCK), ORDERS (NOLOCK), PACK (NOLOCK), LOADPLANDETAIL (NOLOCK)
WHERE PICKDETAIL.OrderKey = ORDERS.OrderKey
AND PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey
AND LOADPLANDETAIL.LoadKey = @c_loadkey
AND PICKDETAIL.Packkey = PACK.Packkey
GROUP BY SUBSTRING(PICKDETAIL.Loc, 1, 6),
SUBSTRING(PICKDETAIL.Sku, 1, 9),
PICKDETAIL.UOM,
SUBSTRING(PICKDETAIL.Sku, 16, 5),
SUBSTRING(PICKDETAIL.Loc, 2, 1),
ORDERS.BuyerPO,
ORDERS.OrderGroup,
ORDERS.ExternOrderKey,
ORDERS.Route,
CONVERT(NVARCHAR(255), ORDERS.Notes),
ORDERS.OrderDate,
ORDERS.ConsigneeKey,
ORDERS.C_Company,
ORDERS.DeliveryDate,
CONVERT(NVARCHAR(255), ORDERS.Notes2),
PACK.PackUom1,
PACK.PackUom3,
PACK.PackUom4,
ORDERS.OrderKey,
SUBSTRING(PICKDETAIL.Loc, 7, 2)
ORDER BY ORDERS.OrderKey,
LFloor,
Bin,
StyleColour,
UOM
OPEN pick_cur
FETCH NEXT FROM pick_cur INTO @c_Loc, @c_Sku, @c_UOM, @c_SkuSize, @n_qty, @c_floor,
@c_BuyerPO, @c_OrderGroup, @c_ExternOrderKey, @c_Route, @c_Notes,
@d_OrderDate, @c_ConsigneeKey, @c_Company, @d_DeliveryDate, @c_Notes2,
@c_OrderKey, @c_bin
WHILE (@@FETCH_STATUS <> -1)
BEGIN
   IF @c_temporderkey = @c_orderkey
   BEGIN
      IF @c_tempfloor <> @c_floor
      BEGIN
         SELECT @c_tempfloor = @c_floor
         SELECT @c_tempsize = @c_skusize
         SELECT @n_counter = 1
         INSERT INTO #TempPickSlip
         (PickSlipNo,
         Loadkey,
         OrderKey,
         BuyerPO,
         OrderGroup,
         ExternOrderKey,
         Route,
         Notes,
         OrderDate,
         ConsigneeKey,
         Company,
         DeliveryDate,
         Notes2,
         Loc,
         Sku,
         UOM,
         SkuSize1,
         Defination,
         LFloor,
         Bin)
         VALUES
         (@c_PickSlipNo,
         @c_LoadKey,
         @c_OrderKey,
         @c_BuyerPO,
         @c_OrderGroup,
         @c_ExternOrderkey,
         @c_Route,
         @c_Notes,
         @d_OrderDate,
         @c_ConsigneeKey,
         @c_Company,
         @d_DeliveryDate,
         @c_Notes2,
         'LOC',
         'STYLE/COLOUR',
         'UOM',
         @c_SkuSize,
         'H',
         @c_floor,
         @c_bin)
      END
   END
ELSE
   BEGIN
      SELECT @c_tempfloor = @c_floor
      SELECT @c_tempsize = @c_skusize
      SELECT @n_counter = 1
      SELECT @c_temporderkey = @c_orderkey
      EXECUTE nspg_GetKey
      "PICKSLIP",
      9,
      @c_PickSlipNo   OUTPUT,
      @b_success   	 OUTPUT,
      @n_err       	 OUTPUT,
      @c_errmsg    	 OUTPUT
      SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo
      BEGIN TRAN
         INSERT INTO PICKHEADER
         (PickHeaderKey, OrderKey,    ExternOrderKey, Zone, TrafficCop)
         VALUES
         (@c_PickSlipNo, @c_OrderKey, @c_LoadKey,     "8",  "")
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         ROLLBACK TRAN
      ELSE
         COMMIT TRAN
         INSERT INTO #TempPickSlip
         (PickSlipNo,
         Loadkey,
         OrderKey,
         BuyerPO,
         OrderGroup,
         ExternOrderKey,
         Route,
         Notes,
         OrderDate,
         ConsigneeKey,
         Company,
         DeliveryDate,
         Notes2,
         Loc,
         Sku,
         UOM,
         SkuSize1,
         Defination,
         LFloor,
         Bin)
         VALUES
         (@c_PickSlipNo,
         @c_LoadKey,
         @c_OrderKey,
         @c_BuyerPO,
         @c_OrderGroup,
         @c_ExternOrderkey,
         @c_Route,
         @c_Notes,
         @d_OrderDate,
         @c_ConsigneeKey,
         @c_Company,
         @d_DeliveryDate,
         @c_Notes2,
         'LOC',
         'STYLE/COLOUR',
         'UOM',
         @c_SkuSize,
         'H',
         @c_floor,
         @c_bin)
      END
      IF @c_tempsize <> @c_skusize
      BEGIN
         SELECT @c_tempsize = @c_skusize
         SELECT @n_counter = @n_counter + 1
         IF @n_counter = 2
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize2 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
             
         END
      ELSE IF @n_counter = 3
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize3 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 4
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize4 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 5
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize5 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 6
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize6 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 7
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize7 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 8
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize8 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 9
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize9 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 10
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize10 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 11
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize11 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 12
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize12 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 13
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize13 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 14
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize14 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 15
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize15 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      ELSE IF @n_counter = 16
         BEGIN
            UPDATE #TempPickSlip
            SET SkuSize16 = @c_SkuSize
            WHERE OrderKey = @c_orderKey
            AND LFloor = @c_floor
            AND Defination = 'H'
         END
      END
      SELECT @c_column = CASE WHEN SkuSize1 = @c_skusize THEN '1'
      WHEN SkuSize2 = @c_skusize THEN '2'
      WHEN SkuSize3 = @c_skusize THEN '3'
      WHEN SkuSize4 = @c_skusize THEN '4'
      WHEN SkuSize5 = @c_skusize THEN '5'
      WHEN SkuSize6 = @c_skusize THEN '6'
      WHEN SkuSize7 = @c_skusize THEN '7'
      WHEN SkuSize8 = @c_skusize THEN '8'
      WHEN SkuSize9 = @c_skusize THEN '9'
      WHEN SkuSize10 = @c_skusize THEN '10'
      WHEN SkuSize11 = @c_skusize THEN '11'
      WHEN SkuSize12 = @c_skusize THEN '12'
      WHEN SkuSize13 = @c_skusize THEN '13'
      WHEN SkuSize14 = @c_skusize THEN '14'
      WHEN SkuSize15 = @c_skusize THEN '15'
      WHEN SkuSize16 = @c_skusize THEN '16'
   END
   FROM #TempPickSlip
   WHERE OrderKey = @c_orderKey
   AND LFloor = @c_floor
   AND Defination = 'H'
   SELECT @c_qty1 = ''
   SELECT @c_qty2 = ''
   SELECT @c_qty3 = ''
   SELECT @c_qty4 = ''
   SELECT @c_qty5 = ''
   SELECT @c_qty6 = ''
   SELECT @c_qty7 = ''
   SELECT @c_qty8 = ''
   SELECT @c_qty9 = ''
   SELECT @c_qty10 = ''
   SELECT @c_qty11 = ''
   SELECT @c_qty12 = ''
   SELECT @c_qty13 = ''
   SELECT @c_qty14 = ''
   SELECT @c_qty15 = ''
   SELECT @c_qty16 = ''
   IF @c_column = '1' SELECT @c_qty1 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '2' SELECT @c_qty2 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '3' SELECT @c_qty3 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '4' SELECT @c_qty4 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '5' SELECT @c_qty5 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '6' SELECT @c_qty6 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '7' SELECT @c_qty7 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '8' SELECT @c_qty8 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '9' SELECT @c_qty9 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '10' SELECT @c_qty10 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '11' SELECT @c_qty11 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '12' SELECT @c_qty12 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '13' SELECT @c_qty13 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '14' SELECT @c_qty14 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '15' SELECT @c_qty15 = CONVERT(NVARCHAR(10), @n_qty)
ELSE IF @c_column = '16' SELECT @c_qty16 = CONVERT(NVARCHAR(10), @n_qty)
   INSERT INTO #TempPickSlip
   (PickSlipNo,
   Loadkey,
   OrderKey,
   BuyerPO,
   OrderGroup,
   ExternOrderKey,
   Route,
   Notes,
   OrderDate,
   ConsigneeKey,
   Company,
   DeliveryDate,
   Notes2,
   Loc,
   Sku,
   UOM,
   SkuSize1,
   SkuSize2,
   SkuSize3,
   SkuSize4,
   SkuSize5,
   SkuSize6,
   SkuSize7,
   SkuSize8,
   SkuSize9,
   SkuSize10,
   SkuSize11,
   SkuSize12,
   SkuSize13,
   SkuSize14,
   SkuSize15,
   SkuSize16,
   Defination,
   LFloor,
   Bin)
   VALUES
   (@c_PickSlipNo,
   @c_LoadKey,
   @c_OrderKey,
   @c_BuyerPO,
   @c_OrderGroup,
   @c_ExternOrderkey,
   @c_Route,
   @c_Notes,
   @d_OrderDate,
   @c_ConsigneeKey,
   @c_Company,
   @d_DeliveryDate,
   @c_Notes2,
   @c_loc,
   @c_sku,
   @c_uom,
   @c_qty1,
   @c_qty2,
   @c_qty3,
   @c_qty4,
   @c_qty5,
   @c_qty6,
   @c_qty7,
   @c_qty8,
   @c_qty9,
   @c_qty10,
   @c_qty11,
   @c_qty12,
   @c_qty13,
   @c_qty14,
   @c_qty15,
   @c_qty16,
   'D',
   @c_floor,
   @c_bin)
   FETCH NEXT FROM pick_cur INTO @c_Loc, @c_Sku, @c_UOM, @c_SkuSize, @n_qty, @c_floor,
   @c_BuyerPO, @c_OrderGroup, @c_ExternOrderKey, @c_Route, @c_Notes,
   @d_OrderDate, @c_ConsigneeKey, @c_Company, @d_DeliveryDate, @c_Notes2,
   @c_OrderKey, @c_bin
END
CLOSE pick_cur
DEALLOCATE pick_cur
SELECT * FROM #TempPickSlip
DROP TABLE #TempPickSlip
END

GO