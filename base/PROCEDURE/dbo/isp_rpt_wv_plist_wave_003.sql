SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_003                             */
/* Creation Date: 20-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18806                                                      */
/*                                                                         */
/* Called By: RPT_WV_PLIST_WAVE_003                                        */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 24-Jan-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_003] (
      @c_Wavekey       NVARCHAR(10),
      @c_PreGenRptData NVARCHAR(10) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue             INT,
            @c_errmsg               NVARCHAR(255),
            @b_success              INT,
            @n_err                  INT,
            @n_starttcnt            INT,
            @n_pickslips_required   INT,
            @c_PickHeaderKey        NVARCHAR(10),
            @c_FirstTime            NVARCHAR(1),
            @c_PrintedFlag          NVARCHAR(1),
            @c_Orderkey             NVARCHAR(10),
            @c_SKUGROUP             NVARCHAR(10),
            @n_Qty                  INT,
            @c_StorerKey            NVARCHAR(15),
            @c_PickSlipNo           NVARCHAR(10),
            @c_VASLBLValue          NVARCHAR(10),
            @c_pickgrp              NVARCHAR(1),
            @c_getUdf01             NVARCHAR(100),
            @c_getUdf02             NVARCHAR(100),
            @c_ordudf05             NVARCHAR(20),
            @c_udf01                NVARCHAR(5),
            @c_getorderkey          NVARCHAR(10),
            @c_condition            NVARCHAR(100),
            @c_ExecStatements       NVARCHAR(4000),
            @c_ExecAllStatements    NVARCHAR(4000),
            @c_ExecArguments        NVARCHAR(4000),
            @c_CSKUUDF04            NVARCHAR(30)

   SET @c_udf01 = ''

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

   CREATE TABLE #TEMP_PICK
      ( PickSlipNo      NVARCHAR(10) NULL,
      OrderKey          NVARCHAR(10),
      ExternOrderkey    NVARCHAR(50),   --tlting_ext
      WaveKey           NVARCHAR(10),
      StorerKey         NVARCHAR(15),
      InvoiceNo         NVARCHAR(10),
      [Route]           NVARCHAR(10) NULL,
      RouteDescr        NVARCHAR(60) NULL,
      ConsigneeKey      NVARCHAR(15) NULL,
      C_Company         NVARCHAR(45) NULL,
      C_Addr1           NVARCHAR(45) NULL,
      C_Addr2           NVARCHAR(45) NULL,
      C_Addr3           NVARCHAR(45) NULL,
      C_PostCode        NVARCHAR(18) NULL,
      C_City            NVARCHAR(45) NULL,
      Sku               NVARCHAR(20) NULL,
      SkuDescr          NVARCHAR(60) NULL,
      Lot               NVARCHAR(10),
      Lottable01        NVARCHAR(18) NULL, -- Batch No
      Lottable04        DATETIME NULL, -- Expiry Date
      Qty               INT,           -- PickDetail.Qty
      Loc               NVARCHAR(10) NULL,
      MasterUnit        INT,
      LowestUOM         NVARCHAR(10),
      CaseCnt           INT,
      InnerPack         INT,
      Capacity          FLOAT,
      GrossWeight       FLOAT,
      PrintedFlag       NVARCHAR(1),
      Notes1            NVARCHAR(60) NULL,
      Notes2            NVARCHAR(60) NULL,
      Lottable02        NVARCHAR(18) NULL,
      DeliveryNote      NVARCHAR(20) NULL,
      SKUGROUP          NVARCHAR(10) NULL,
      SkuGroupQty       INT,
      DeliveryDate      DATETIME NULL,
      OrderGroup        NVARCHAR(20) NULL,
      scanserial        NVARCHAR(30) NULL,
      LogicalLoc        NVARCHAR(18) NULL,
      Lottable03        NVARCHAR(18) NULL,
      LabelFlag         NVARCHAR(10) NULL,
      RetailSku         NVARCHAR(20) NULL,
      Internalflag      NVARCHAR(10) NULL,
      scancaseidflag    NVARCHAR(20) NULL,
      showbarcodeflag   NCHAR(1) NULL,
      UDF01             NVARCHAR(5) NULL,
      OHUDF04           NVARCHAR(20) NULL,
      showfield         NCHAR(1) NULL,
      ODUDF05           NVARCHAR(5) NULL,
      showbuyerpo       NCHAR(1) NULL,
      CSKUUDF04         NVARCHAR(30) NULL,
      ShowPltPackage    NVARCHAR(10) NULL,
      PltPackage        NVARCHAR(120) NULL)
   -- Check if wavekey existed
   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)
               WHERE WaveKey = @c_Wavekey
               AND   Zone = '8')
   BEGIN
      SELECT @c_FirstTime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END

   IF @c_PreGenRptData = 'Y'
   BEGIN
      BEGIN TRAN
      -- Uses PickType as a Printed Flag
      UPDATE PICKHEADER WITH (ROWLOCK)  -- tlting
      SET PickType = '1',
          TrafficCop = NULL
      WHERE WaveKey = @c_Wavekey
      AND Zone = '8'
      AND PickType = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
            GOTO FAILURE
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
            GOTO FAILURE
         END
      END
   END

   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
   FROM PICKHEADER WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey)
   WHERE PICKHEADER.Wavekey = @c_Wavekey
   AND PICKHEADER.ZONE = '8'

   SELECT @c_VASLBLValue = SValue
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Configkey = 'WAVEPICKSLIP04_VASLBL'

   SELECT @c_pickgrp = CASE WHEN ISNULL(Code,'') <> '' THEN 'Y' ELSE 'N' END
   FROM CODELKUP  WITH (NOLOCK)
   WHERE Code = 'PICKPGRP'
   AND Listname = 'REPORTCFG'
   AND Long = 'RPT_WV_PLIST_WAVE_003'
   AND ISNULL(Short,'') <> 'N'
   AND Storerkey = @c_Storerkey

   BEGIN TRAN

   -- Select all records into temp table
   INSERT INTO #TEMP_PICK
   SELECT (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)
            WHERE PICKHEADER.Wavekey = @c_Wavekey
            AND PICKHEADER.OrderKey = ORDERS.OrderKey
            AND PICKHEADER.ZONE = '8'),
   ORDERS.Orderkey,
   ORDERS.ExternOrderkey,
   WAVEDETAIL.WaveKey,
   ISNULL(ORDERS.StorerKey, ''),
   ISNULL(ORDERS.Invoiceno, ''),
   ISNULL(ORDERS.[Route], ''),
   ISNULL(ROUTEMASTER.Descr, ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address1), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address2), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address3), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Zip), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_City), ''),
   SKU.Sku,
   --ISNULL(SKU.Descr,'') AS SkuDescr,
     CASE WHEN ISNULL(CL4.Code,'') <> '' AND ISNULL(SKU.Notes1,'') <> '' THEN SKU.Notes1 ELSE ISNULL(SKU.Descr,'') END AS SkuDescr, --NJOW06
   --PICKDETAIL.Lot,
   CASE WHEN @c_pickgrp <> 'Y' THEN PICKDETAIL.Lot ELSE '' END as Lot,
   ISNULL(LOTATTRIBUTE.Lottable01, ''),
   ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
   SUM(PICKDETAIL.Qty) AS QTY,
   ISNULL(PICKDETAIL.Loc, ''),
   ISNULL(PACK.Qty, 0) AS MasterUnit,
   ISNULL(PACK.PackUOM3, '') AS LowestUOM,
   ISNULL(PACK.CaseCnt, 0),
   ISNULL(PACK.InnerPack, 0),
   ISNULL(ORDERS.Capacity, 0.00),
   ISNULL(ORDERS.GrossWeight, 0.00),
   @c_PrintedFlag,
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) AS Notes1,
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) AS Notes2,
   ISNULL(LOTATTRIBUTE.Lottable02, '') Lottable02,
   CASE WHEN ISNULL(CL6.Code,'') = '' OR ISNULL(CL6.Code,'') = 'N' THEN ISNULL(Orders.DeliveryNote,'')
    ELSE ISNULL(orders.buyerpo,'') END DeliveryNote,
   SKU.SKUGROUP,
   0,
   ORDERS.DeliveryDate,
   ORDERS.OrderGroup,
   CASE WHEN SKU.SUSR4 = 'SSCC' THEN
              '**Scan Serial No** '
             ELSE
             ''
   END,
   ISNULL(LOC.LogicalLocation,''),
   ISNULL(LOTATTRIBUTE.Lottable03, '')
   ,CASE WHEN  @c_VASLBLValue = '1' AND CS.Sku = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5),'')
                                 ELSE '' END,
   CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN
                ISNULL(SKU.RetailSku,'')
   ELSE '' END AS RetailSku
   ,CASE WHEN LEFT(ORDERS.Userdefine10,3) = 'YFD' AND SKU.SKUGroup = 'YFG' THEN
        'YFG' ELSE '' END AS Internalflag
   ,CASE WHEN MAX(ISNULL(CL1.Code,'')) = '' AND MIN(PICKDETAIL.UOM) IN (1,2) AND MAX(ISNULL(CL3.Code,'')) <> '' THEN '*' ELSE '' END AS scancaseidflag --NJOW05
     ,CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbarcodeflag
     ,'' AS udf01
     ,ISNULL(ORDERS.UserDefine04,'')
     ,CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showfield
     ,ISNULL(substring(OD.userdefine05,1,1),'') AS ODUDF05
     ,CASE WHEN ISNULL(CL6.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbuyerpo
     ,''  AS cskuudf04
     ,CASE WHEN ISNULL(CL7.Code,'') <> '' THEN N'底x高: ' ELSE '' END AS ShowPltPackage  
     ,CASE WHEN ISNULL(CS.UDF04,'') <> '' AND ISNULL(CS.UDF05,'') <> '' THEN ISNULL(CS.UDF04,'') + 'x' +  ISNULL(CS.UDF05,'')  ELSE '' END
   FROM PICKDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN ORDERDETAIL OD (NOLOCK) ON (OD.Orderkey = PICKDETAIL.Orderkey
                                   AND OD.OrderLineNumber=PICKDETAIL.OrderLineNumber
                                   AND OD.Sku = PICKDETAIL.Sku AND OD.StorerKey=PICKDETAIL.Storerkey)
   JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
   JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN LOC (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC)
   LEFT OUTER JOIN ROUTEMASTER (NOLOCK) ON (ORDERS.[Route] = ROUTEMASTER.[Route])
   LEFT OUTER JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ORDERS.Consigneekey)
   LEFT OUTER JOIN CONSIGNEESKU CS WITH (NOLOCK) ON (CS.Consigneekey = ST.Storerkey)
                                                 AND(CS.Sku = PICKDETAIL.Sku)
   LEFT OUTER JOIN v_storerconfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'DELNOTE06_RSKU'
   LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON (SKU.Class = CL1.Code AND CL1.Listname = 'MHCSSCAN')
   LEFT OUTER JOIN CODELKUP CL2 (NOLOCK) ON (PICKDETAIL.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWBARCODE'
                                          AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'RPT_WV_PLIST_WAVE_003' AND ISNULL(CL2.Short,'') <> 'N')
   LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (PICKDETAIL.Storerkey = CL3.Storerkey AND CL3.Code = 'SHOWSCNFG'
                                          AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'RPT_WV_PLIST_WAVE_003' AND ISNULL(CL3.Short,'') <> 'N')
   LEFT OUTER JOIN CODELKUP CL4 (NOLOCK) ON (PICKDETAIL.Storerkey = CL4.Storerkey AND CL4.Code = 'PRTSKUDESC'
                                          AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'RPT_WV_PLIST_WAVE_003' AND ISNULL(CL4.Short,'') <> 'N')
   LEFT OUTER JOIN CODELKUP CL5 (NOLOCK) ON (PICKDETAIL.Storerkey = CL5.Storerkey AND CL5.Code = 'SHOWFIELD'
                                          AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'RPT_WV_PLIST_WAVE_003' AND ISNULL(CL5.Short,'') <> 'N')
   LEFT OUTER JOIN CODELKUP CL6 (NOLOCK) ON (PICKDETAIL.Storerkey = CL6.Storerkey AND CL6.Code = 'SHOWBUYERPO'
                                          AND CL6.Listname = 'REPORTCFG' AND CL6.Long = 'RPT_WV_PLIST_WAVE_003' AND ISNULL(CL6.Short,'') <> 'N')
   LEFT OUTER JOIN CODELKUP CL7 (NOLOCK) ON (PICKDETAIL.Storerkey = CL7.Storerkey AND CL7.Code = 'ShowPalletPackage'
                                          AND CL7.Listname = 'REPORTCFG' AND CL7.Long = 'RPT_WV_PLIST_WAVE_003' AND ISNULL(CL7.Short,'') <> 'N')
   WHERE (WAVEDETAIL.Wavekey = @c_Wavekey)
   -- AND (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')
   GROUP BY ORDERS.Orderkey,
   ORDERS.ExternOrderkey,
   WAVEDETAIL.WaveKey,
   ISNULL(ORDERS.StorerKey, ''),
   ISNULL(ORDERS.Invoiceno, ''),
   ISNULL(ORDERS.[Route], ''),
   ISNULL(ROUTEMASTER.Descr, ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address1), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address2), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address3), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Zip), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_City), ''),
   SKU.Sku,
   --ISNULL(SKU.Descr,''),
   CASE WHEN ISNULL(CL4.Code,'') <> '' AND ISNULL(SKU.Notes1,'') <> '' THEN SKU.Notes1 ELSE ISNULL(SKU.Descr,'') END,
   PICKDETAIL.Lot,
   ISNULL(LOTATTRIBUTE.Lottable01, ''),
   ISNULL(Convert(NVARCHAR(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
   ISNULL(PICKDETAIL.Loc, ''),
   ISNULL(PACK.Qty, 0),
   ISNULL(PACK.PackUOM3, ''),
   ISNULL(PACK.CaseCnt, 0),
   ISNULL(PACK.InnerPack, 0),
   ISNULL(ORDERS.Capacity, 0.00),
   ISNULL(ORDERS.GrossWeight, 0.00),
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
   ISNULL(LOTATTRIBUTE.Lottable02, ''),
   CASE WHEN ISNULL(CL6.Code,'') = '' OR ISNULL(CL6.Code,'') = 'N' THEN ISNULL(Orders.DeliveryNote,'')
    ELSE ISNULL(orders.buyerpo,'') END,
   SKU.SKUGROUP,
   ORDERS.DeliveryDate,
   ORDERS.OrderGroup,
   CASE WHEN SKU.SUSR4 = 'SSCC' THEN
              '**Scan Serial No** '
             ELSE
             ''
   END,
   ISNULL(LOC.LogicalLocation,''),
   ISNULL(LOTATTRIBUTE.Lottable03, '')
   ,CASE WHEN  @c_VASLBLValue = '1' AND CS.Sku = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5),'')
                                 ELSE '' END,
   CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN
                ISNULL(SKU.RetailSku,'')
   ELSE '' END
   ,CASE WHEN LEFT(ORDERS.Userdefine10,3) = 'YFD' AND SKU.SKUGroup = 'YFG' THEN
        'YFG' ELSE '' END
     ,CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END
     ,ISNULL(ORDERS.UserDefine04,'')
     ,CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END
     ,ISNULL(substring(OD.userdefine05,1,1),'')
     ,CASE WHEN ISNULL(CL6.Code,'') <> '' THEN 'Y' ELSE 'N' END
     ,CASE WHEN ISNULL(CL7.Code,'') <> '' THEN N'底x高: ' ELSE '' END
     ,CASE WHEN ISNULL(CS.UDF04,'') <> '' AND ISNULL(CS.UDF05,'') <> '' THEN ISNULL(CS.UDF04,'') + 'x' +  ISNULL(CS.UDF05,'')  ELSE '' END

   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
         GOTO FAILURE
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
         GOTO FAILURE
      END
   END

   /* Re-calculate SKUGROUP BEGIN*/
   DECLARE C_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Orderkey, SKUGROUP, SUM(Qty)
   FROM  #TEMP_PICK
   GROUP BY Orderkey, SKUGROUP

   OPEN C_Pickslip
   FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF EXISTS (SELECT * FROM CODELKUP CLK WITH (NOLOCK)
                 WHERE listname = 'REPORTCFG'
                 AND code = 'afroutedes'
                 AND long ='RPT_WV_PLIST_WAVE_003'
                 AND storerkey = @c_StorerKey)
      BEGIN

         SELECT TOP 1 @c_getudf01 = C.udf01
                     ,@c_getUdf02 = C.udf02
         FROM Codelkup C WITH (NOLOCK)
         WHERE C.listname='REPORTCFG'
         AND code = 'afroutedes'
         AND long ='RPT_WV_PLIST_WAVE_003'
         AND c.Storerkey = @c_Storerkey

         SET @c_ExecStatements = ''
         SET @c_ExecArguments = ''
         SET @c_condition = ''
         SET @c_ordudf05 = ''

         IF  ISNULL(@c_getUdf02,'') <> ''
         BEGIN
            SET @c_condition = 'AND ' + @c_getUdf02
         END
         ELSE
         BEGIN
            SET @c_condition = 'AND Orders.userdefine05=''*'''
         END

         SET @c_ExecStatements = N'SELECT @c_ordudf05 =' + @c_getudf01 + ' from Orders (nolock) where orderkey=@c_OrderKey '
         SET @c_ExecAllStatements = @c_ExecStatements + @c_condition

         SET @c_ExecArguments = N'@c_getudf01    NVARCHAR(100) '
                              +',@c_OrderKey    NVARCHAR(30)'
                              +',@c_ordudf05    NVARCHAR(20) OUTPUT'

         EXEC sp_ExecuteSql @c_ExecAllStatements
                          , @c_ExecArguments
                          , @c_getudf01
                          , @c_OrderKey
                          , @c_ordudf05 OUTPUT


         --IF @b_debug = '1'
         --    BEGIN
         --      PRINT ' @c_ordudf05 : ' + @c_ordudf05
         --    END

      END

      SET @c_CSKUUDF04 = ''

      SELECT @c_CSKUUDF04 = udf04
      FROM consigneesku csku WITH (nolock)
      JOIN Orders O WITH (NOLOCK) ON O.storerkey = csku.StorerKey AND o.ConsigneeKey = csku.ConsigneeKey
      WHERE O.OrderKey =  @c_Orderkey
      AND sku in (SELECT TOP 1 sku
                  FROM orderdetail(nolock)
      WHERE orderkey=@c_Orderkey)

      UPDATE #TEMP_PICK
      SET SKUGroupQty = @n_Qty
         ,UDF01 = @c_ordudf05
         ,CSKUUDF04 = @c_CSKUUDF04
      WHERE Orderkey = @c_Orderkey
      AND SKUGroup = @c_SKUGROUP
      FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty
   END
   CLOSE C_Pickslip
   DEALLOCATE C_Pickslip
   /* Re-calculate SKUGROUP END*/

   IF @c_PreGenRptData = 'Y'
   BEGIN
      -- Check if any pickslipno with NULL value
      SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''

      IF @@ERROR <> 0
      BEGIN
         GOTO FAILURE
      END
      ELSE IF @n_pickslips_required > 0
      BEGIN
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
         dbo.fnc_LTrim( dbo.fnc_RTrim(
         STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT OrderKey)
                                              FROM #TEMP_PICK AS Rank
                                              WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                                              AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' )
             ) -- str
             )) -- dbo.fnc_RTrim
             , 9)
            , OrderKey, WaveKey, '0', '8', ''
         FROM #TEMP_PICK
         WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
         GROUP By WaveKey, OrderKey

         UPDATE #TEMP_PICK
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM PICKHEADER (NOLOCK)
         WHERE PICKHEADER.WaveKey = #TEMP_PICK.Wavekey
         AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
         AND   PICKHEADER.Zone = '8'
         AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = ''
      END

      GOTO SUCCESS
   END
   ELSE   --IF @c_PreGenRptData <> 'Y'
   BEGIN
      GOTO SUCCESS
   END

FAILURE:
   DELETE FROM #TEMP_PICK
SUCCESS:
   IF @c_PreGenRptData = 'Y'
   BEGIN
      -- Do Auto Scan-in when Configkey is setup.
      SET @c_StorerKey = ''
      SET @c_PickSlipNo = ''

      SELECT DISTINCT @c_StorerKey = StorerKey
        FROM #TEMP_PICK (NOLOCK)

      IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'
                    AND SValue = '1' AND StorerKey = @c_StorerKey)
      BEGIN
         DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PickSlipNo
           FROM #TEMP_PICK (NOLOCK)

         OPEN C_AutoScanPickSlip
         FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) Where PickSlipNo = @c_PickSlipNo)
            BEGIN
               INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                     ': Insert PickingInfo Failed. (isp_RPT_WV_PLIST_WAVE_003)' + ' ( ' +
                                     ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- PickSlipNo Does Not Exist

            FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo
         END
         CLOSE C_AutoScanPickSlip
         DEALLOCATE C_AutoScanPickSlip
      END -- Configkey is setup
   END

   IF ISNULL(@c_PreGenRptData,'') IN ('','0')
   BEGIN
      SELECT PickSlipNo ,OrderKey ,ExternOrderkey ,WaveKey ,StorerKey  ,InvoiceNo ,[Route]  ,RouteDescr ,ConsigneeKey
            ,C_Company ,C_Addr1 ,C_Addr2 ,C_Addr3 ,C_PostCode, C_City, Sku ,SkuDescr ,Lot ,Lottable01 ,Lottable04
            ,SUM(Qty) AS Qty ,Loc ,MasterUnit ,LowestUOM ,CaseCnt ,InnerPack ,Capacity ,GrossWeight ,PrintedFlag ,Notes1
            ,Notes2 ,Lottable02 ,DeliveryNote ,SKUGROUP ,SkuGroupQty ,DeliveryDate ,OrderGroup  ,scanserial, LogicalLoc, Lottable03
            ,LabelFlag, RetailSku
            ,Internalflag
            ,scancaseidflag, showbarcodeflag,ISNULL(UDF01,'') AS udf01
            ,ISNULL(OHUDF04,'') AS OHUDF04
            ,showfield,ODUDF05,showbuyerpo,CSKUUDF04,ShowPltPackage
            ,CASE WHEN ShowPltPackage = '' THEN '' ELSE PltPackage END AS PltPackage
            FROM #TEMP_PICK

      GROUP BY PickSlipNo ,OrderKey ,ExternOrderkey ,WaveKey ,StorerKey  ,InvoiceNo ,[Route]  ,RouteDescr ,ConsigneeKey
            ,C_Company ,C_Addr1 ,C_Addr2 ,C_Addr3 ,C_PostCode, C_City, Sku ,SkuDescr ,Lot ,Lottable01 ,Lottable04
            ,Loc ,MasterUnit ,LowestUOM ,CaseCnt ,InnerPack ,Capacity ,GrossWeight ,PrintedFlag ,Notes1
            ,Notes2 ,Lottable02 ,DeliveryNote ,SKUGROUP ,SkuGroupQty ,DeliveryDate ,OrderGroup  ,scanserial, LogicalLoc, Lottable03
            ,LabelFlag, RetailSku
            ,Internalflag
            ,scancaseidflag, showbarcodeflag ,UDF01,OHUDF04 ,showfield,ODUDF05
            ,showbuyerpo,CSKUUDF04,ShowPltPackage
            ,CASE WHEN ShowPltPackage = '' THEN '' ELSE PltPackage END

      ORDER BY PickSlipNo, LogicalLoc, Loc, Sku, SkuGroup
   END

   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL
      DROP TABLE #TEMP_PICK

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PLIST_WAVE_003'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
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
END

GO