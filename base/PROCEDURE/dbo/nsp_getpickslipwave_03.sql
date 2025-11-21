SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Stored Procedure: nsp_GetPickSlipWave_03                                 */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose:                                                                 */
/*                                                                          */
/* Usage:                                                                   */
/*                                                                          */
/* Local Variables:                                                         */
/*                                                                          */
/* Called By: When records updated                                          */
/*                                                                          */
/* Revision: 1.7                                                            */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author     Ver.  Purposes                                   */
/* 13-Apr-2006  SHONG      1.1   Add StorerKey into PickHeader              */
/* 28-Jan-2019  TLTING_ext 1.2   enlarge externorderkey field length        */
/* 03-Sep-2019  WLChooi    1.3   WMS-10468 - Add new mapping (WL01)         */
/* 05-Nov-2019  Leong      1.4   INC0921332 - Change DeliveryDate data type */
/* 30-Apr-2021  Mingle     1.5   WMS-16856 - Add mapping and sorting(ML01)  */
/* 08-Oct-2021  WLChooi    1.6   DevOps Combine Script                      */
/* 08-Oct-2021  WLChooi    1.6   WMS-18113 - Add new mapping (WL02)         */
/* 29-Oct-2021  WLChooi    1.7   WMS-18113 - Show Barcode based on OrderType*/
/*                               (WL03)                                     */
/****************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipWave_03] (@c_wavekey NVARCHAR(10))
 AS
 BEGIN
 -- Modified by MaryVong on 01Sep04 (SOS25171)
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue           INT,
           @c_errmsg             NVARCHAR(255),
           @b_success            INT,
           @n_err                INT,
           @n_pickslips_required INT,
           @c_pickheaderkey      NVARCHAR(10),
           @c_sorting            NVARCHAR(10)         --ML01

   --WL03 S
   DECLARE @c_UDF01              NVARCHAR(60)
         , @c_UDF02              NVARCHAR(60)
         , @c_UDF03              NVARCHAR(60)
         , @c_UDF04              NVARCHAR(60)
         , @c_UDF05              NVARCHAR(200)
         , @c_OrderType          NVARCHAR(250) = ''

   SELECT @c_UDF01 = TRIM(ISNULL(CL1.UDF01,''))
        , @c_UDF02 = TRIM(ISNULL(CL1.UDF02,''))
        , @c_UDF03 = TRIM(ISNULL(CL1.UDF03,''))
        , @c_UDF04 = TRIM(ISNULL(CL1.UDF04,''))
        , @c_UDF05 = TRIM(ISNULL(CL1.UDF05,''))
   FROM ORDERS (NOLOCK)
   JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ShowAltSKU' AND CL1.LONG = 'r_dw_print_wave_pickslip_03'
                             AND CL1.STORERKEY = ORDERS.STORERKEY
   WHERE ORDERS.UserDefine09 = @c_wavekey

   SET @c_OrderType = CASE WHEN ISNULL(@c_UDF01,'') = '' THEN '' ELSE @c_UDF01 + ',' END
                    + CASE WHEN ISNULL(@c_UDF02,'') = '' THEN '' ELSE @c_UDF02 + ',' END
                    + CASE WHEN ISNULL(@c_UDF03,'') = '' THEN '' ELSE @c_UDF03 + ',' END
                    + CASE WHEN ISNULL(@c_UDF04,'') = '' THEN '' ELSE @c_UDF04 + ',' END
                    + CASE WHEN ISNULL(@c_UDF05,'') = '' THEN '' ELSE @c_UDF05 + ',' END

   SET @c_OrderType = SUBSTRING(@c_OrderType, 1, LEN(@c_OrderType) - 1)
   --WL03 E

   CREATE TABLE #TEMP_PICK
         ( PickSlipNo      NVARCHAR(10) NULL,
         OrderKey          NVARCHAR(10),
         ExternOrderkey    NVARCHAR(50),  --tlting_ext
         WaveKey           NVARCHAR(10),
         StorerKey         NVARCHAR(15),
         InvoiceNo         NVARCHAR(10),
         BuyerPO           NVARCHAR(20) NULL,
         Route             NVARCHAR(10) NULL,
         Company           NVARCHAR(62) NULL,
         Sku               NVARCHAR(20) NULL,
         SkuDescr          NVARCHAR(60) NULL,
         ManufacturerSku   NVARCHAR(20) NULL,
         Lottable02        NVARCHAR(18) NULL,
         Lottable04        DATETIME NULL,
         Qty               INT,
         DeliveryDate      DATETIME NULL, --NVARCHAR(25) NULL, -- INC0921332
         LogicalLocation   NVARCHAR(10) NULL,
         Loc               NVARCHAR(10) NULL,
         PutawayZone       NVARCHAR(10) NULL,
         MasterUnit        INT,
         LowestUOM         NVARCHAR(10),
         PrintedFlag       NVARCHAR(1),          -- SOS25171
         Notes1            NVARCHAR(60) NULL,
         Notes2            NVARCHAR(60) NULL,
         Lottable12        NVARCHAR(30) NULL,    --WL01
         pickroute         NVARCHAR(5) NULL,         --ML01
         showroute         NVARCHAR(5) NULL,             --ML01
         ShowAltSKU        NVARCHAR(10) NULL,   --WL02
         AltSKU            NVARCHAR(20) )   --WL02

   INSERT INTO #TEMP_PICK
   SELECT (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)
               WHERE PICKHEADER.Wavekey = @c_wavekey
               AND PICKHEADER.OrderKey = ORDERS.OrderKey
               AND PICKHEADER.ZONE = '8'),
               ORDERS.Orderkey,
               ORDERS.ExternOrderkey,
               WAVEDETAIL.WaveKey,
               ISNULL(ORDERS.StorerKey, ''),
               ISNULL(ORDERS.Invoiceno, ''),
               ISNULL(ORDERS.BuyerPO, ''),
               ISNULL(ORDERS.Route, ''),
               ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), '') + ' -- ' +  ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), '') AS Company,
               SKU.Sku,
               ISNULL(SKU.Descr,'') AS SkuDescr,
               ISNULL(SKU.ManufacturerSku,''),  --WL01 Fix ambiguous column name
               ISNULL(LOTATTRIBUTE.Lottable02, ''),
               ISNULL(Convert(NVARCHAR(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
               SUM(PICKDETAIL.Qty) AS QTY,
               ISNULL(Convert(NVARCHAR(10), ORDERS.DeliveryDate, 112), '01/01/1900'),
               ISNULL(LOC.LogicalLocation, ''),
               ISNULL(PICKDETAIL.Loc, ''),
               ISNULL(LOC.PutawayZone, ''),
               ISNULL(PACK.Qty, 0) AS MasterUnit,
               LTRIM(RTRIM(ISNULL(PACK.PackUOM3, ''))) AS LowestUOM, --WL01 Trim
               ISNULL((SELECT DISTINCT 'Y' FROM PICKHEADER (NOLOCK) WHERE WaveKey = @c_wavekey AND Zone = '8'), 'N') AS PrintedFlag, -- SOS25171
               CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) AS Notes1,
               CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) AS Notes2,
               ISNULL(ORDERDETAIL.Lottable12,'') AS Lottable02,   --WL01
               CASE WHEN ISNULL(ORDERS.Route, '') LIKE 'BKK%' THEN 'B' ELSE 'U' END AS PICKROUTE,         --ML01
               SHOWROUTE = ISNULL(CL.SHORT,'N'),         --ML01
               ShowAltSKU = ISNULL(CL1.Short,'N'),   --WL02
               AltSKU = ISNULL(SKU.ALTSKU,'')        --WL02
   FROM PICKDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
   JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
   JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.ORDERKEY = PICKDETAIL.ORDERKEY AND ORDERDETAIL.SKU = PICKDETAIL.SKU  --WL01
                             AND ORDERDETAIL.ORDERLINENUMBER = PICKDETAIL.ORDERLINENUMBER)                        --WL01
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'SHOWROUTE' AND CL.LONG = 'R_DW_PRINT_WAVE_PICKSLIP_03'
                                 AND CL.STORERKEY = PICKDETAIL.STORERKEY
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ShowAltSKU' AND CL1.LONG = 'r_dw_print_wave_pickslip_03'   --WL02
                                  AND CL1.STORERKEY = ORDERS.STORERKEY   --WL02
                                  AND ORDERS.[Type] IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit (',', @c_OrderType) )   --WL03
   WHERE PICKDETAIL.Status < '5'
    AND (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')
    AND (WAVEDETAIL.Wavekey = @c_wavekey)
   GROUP BY ORDERS.Orderkey,
            ORDERS.ExternOrderkey,
            WAVEDETAIL.WaveKey,
            ISNULL(ORDERS.StorerKey, ''),
            ISNULL(ORDERS.Invoiceno, ''),
            ISNULL(ORDERS.BuyerPO, ''),
            ISNULL(ORDERS.Route, ''),
            ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), '') + ' -- ' +  ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),
            SKU.Sku,
            ISNULL(SKU.Descr,''),
            ISNULL(SKU.ManufacturerSku,''),  --WL01 Fix ambiguous column name
            ISNULL(LOTATTRIBUTE.Lottable02, ''),
            ISNULL(Convert(NVARCHAR(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
            ISNULL(Convert(NVARCHAR(10), ORDERS.DeliveryDate, 112), '01/01/1900'),
            ISNULL(LOC.LogicalLocation, ''),
            ISNULL(PICKDETAIL.Loc, ''),
            ISNULL(LOC.PutawayZone, ''),
            ISNULL(PACK.Qty, 0),
            LTRIM(RTRIM(ISNULL(PACK.PackUOM3, ''))),   --WL01 Trim
            CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),
            CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
            ISNULL(ORDERDETAIL.Lottable12,''),                    --WL01
            CASE WHEN ISNULL(ORDERS.Route, '') LIKE 'BKK%' THEN 'B' ELSE 'U' END,         --ML01
            ISNULL(CL.SHORT,'N'),         --ML01
            ISNULL(CL1.Short,'N'),   --WL02
            ISNULL(SKU.ALTSKU,'')   --WL02

   BEGIN TRAN

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

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE PickSlipNo IS NULL

   IF @@ERROR <> 0
   BEGIN
      DELETE FROM #TEMP_PICK
   END
   ELSE IF @n_pickslips_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop, StorerKey)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
      dbo.fnc_LTrim( dbo.fnc_RTrim(
      STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT orderkey)
                                           FROM #TEMP_PICK AS Rank
                                           WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )
          ) -- str
          )) -- dbo.fnc_RTrim
          , 9)
         , OrderKey, WaveKey, '0', '8', '', StorerKey
      FROM #TEMP_PICK WHERE PickSlipNo IS NULL
      GROUP By WaveKey, OrderKey, StorerKey

      UPDATE #TEMP_PICK
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.WaveKey = #TEMP_PICK.Wavekey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '8'
      AND   #TEMP_PICK.PickSlipNo IS NULL
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END

   SELECT TOP 1 @c_sorting = SHOWROUTE FROM #TEMP_PICK          --ML01
   IF @c_sorting = 'Y'
      SELECT * FROM #TEMP_PICK ORDER BY CASE WHEN Route LIKE 'BKK%' THEN 1 ELSE 2 END,externorderkey,LogicalLocation, Loc, Sku
      
   ELSE
      SELECT * FROM #TEMP_PICK ORDER BY PickSlipNo, LogicalLocation, Loc, Sku
      
   DROP Table #TEMP_PICK
END

GO