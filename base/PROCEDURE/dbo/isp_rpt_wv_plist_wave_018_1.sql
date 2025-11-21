SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_018_1                         */
/* Creation Date: 29-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Adarsh                                                    */
/*                                                                       */
/* Purpose: WMS-22131-Migrate WMS Report To LogiReport                   */
/*                                                                       */
/* Called By: RPT_WV_PLIST_WAVE_018_1                                    */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 30-Mar-2023 WLChooi 1.0   DevOps Combine Script                       */
/* 26-Apr-2023 CSCHONG 1.1   WMS-22336 add new field (CS01)              */
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_018_1]
(@c_wavekey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue           INT
         , @c_errmsg             NVARCHAR(255)
         , @b_success            INT
         , @n_err                INT
         , @n_starttcnt          INT
         , @n_pickslips_required INT
         , @c_PickHeaderKey      NVARCHAR(10)
         , @c_FirstTime          NVARCHAR(1)
         , @c_PrintedFlag        NVARCHAR(1)
         , @c_Orderkey           NVARCHAR(10)
         , @c_SKUGROUP           NVARCHAR(10)
         , @n_Qty                INT
         , @c_StorerKey          NVARCHAR(15)
         , @c_PickSlipNo         NVARCHAR(10)
         , @c_VASLBLValue        NVARCHAR(10)
         , @c_pickgrp            NVARCHAR(1)
         , @c_getUdf01           NVARCHAR(100)
         , @c_getUdf02           NVARCHAR(100)
         , @c_ordudf05           NVARCHAR(20)
         , @c_udf01              NVARCHAR(5)
         , @c_getorderkey        NVARCHAR(10)
         , @c_condition          NVARCHAR(100)
         , @c_ExecStatements     NVARCHAR(4000)
         , @c_ExecAllStatements  NVARCHAR(4000)
         , @c_ExecArguments      NVARCHAR(4000)
         , @c_CSKUUDF04          NVARCHAR(30)
         , @c_SHOWMSKU           NVARCHAR(5)                --CS01
         , @c_PreGenRptData    NVARCHAR(10) = ''            --CS01


   SET @c_udf01 = N''

   SELECT @n_starttcnt = @@TRANCOUNT
        , @n_continue = 1
        , @b_success = 0
        , @n_err = 0
        , @c_errmsg = N''

   CREATE TABLE #TEMP_PICK
   (
      PickSlipNo      NVARCHAR(10)  NULL
    , OrderKey        NVARCHAR(10)
    , ExternOrderkey  NVARCHAR(50)
    , WaveKey         NVARCHAR(10)
    , StorerKey       NVARCHAR(15)
    , InvoiceNo       NVARCHAR(10)
    , Route           NVARCHAR(10)  NULL
    , RouteDescr      NVARCHAR(60)  NULL
    , ConsigneeKey    NVARCHAR(15)  NULL
    , C_Company       NVARCHAR(45)  NULL
    , C_Addr1         NVARCHAR(45)  NULL
    , C_Addr2         NVARCHAR(45)  NULL
    , C_Addr3         NVARCHAR(45)  NULL
    , C_PostCode      NVARCHAR(18)  NULL
    , C_City          NVARCHAR(45)  NULL
    , Sku             NVARCHAR(20)  NULL
    , SkuDescr        NVARCHAR(60)  NULL
    , Lot             NVARCHAR(10)
    , Lottable01      NVARCHAR(18)  NULL
    , Lottable04      DATETIME      NULL
    , Qty             INT
    , Loc             NVARCHAR(10)  NULL
    , MasterUnit      INT
    , LowestUOM       NVARCHAR(10)
    , CaseCnt         INT
    , InnerPack       INT
    , Capacity        FLOAT
    , GrossWeight     FLOAT
    , PrintedFlag     NVARCHAR(1)
    , Notes1          NVARCHAR(60)  NULL
    , Notes2          NVARCHAR(60)  NULL
    , Lottable02      NVARCHAR(18)  NULL
    , DeliveryNote    NVARCHAR(20)  NULL
    , SKUGROUP        NVARCHAR(10)  NULL
    , SkuGroupQty     INT
    , DeliveryDate    DATETIME      NULL
    , OrderGroup      NVARCHAR(20)  NULL
    , scanserial      NVARCHAR(30)  NULL
    , LogicalLoc      NVARCHAR(18)  NULL
    , Lottable03      NVARCHAR(18)  NULL
    , LabelFlag       NVARCHAR(10)  NULL
    , RetailSku       NVARCHAR(20)  NULL
    , Internalflag    NVARCHAR(10)  NULL
    , scancaseidflag  NVARCHAR(20)  NULL
    , showbarcodeflag NCHAR(1)      NULL
    , UDF01           NVARCHAR(5)   NULL
    , OHUDF04         NVARCHAR(20)  NULL
    , showfield       NCHAR(1)      NULL
    , ODUDF05         NVARCHAR(5)   NULL
    , showbuyerpo     NCHAR(1)      NULL
    , CSKUUDF04       NVARCHAR(30)  NULL
    , showpltpackage  NCHAR(1)      NULL
    , pltpackage      NVARCHAR(120) NULL
    , ManufactureSKU  NVARCHAR(20)  NULL      --CS01
   )

   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE WaveKey = @c_wavekey AND Zone = '8')
   BEGIN
      SELECT @c_FirstTime = N'N'
      SELECT @c_PrintedFlag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = N'Y'
      SELECT @c_PrintedFlag = N'N'
   END

   BEGIN TRAN

   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
     , TrafficCop = NULL
   WHERE WaveKey = @c_wavekey AND Zone = '8' AND PickType = '0'

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


   SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey
   FROM PICKHEADER WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey)
   WHERE PICKHEADER.WaveKey = @c_wavekey AND PICKHEADER.Zone = '8'

   SELECT @c_VASLBLValue = SValue
   FROM StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey AND ConfigKey = 'WAVEPICKSLIP04_VASLBL'


   SELECT @c_pickgrp = CASE WHEN ISNULL(Code, '') <> '' THEN 'Y'
                            ELSE 'N' END
   FROM CODELKUP WITH (NOLOCK)
   WHERE Code = 'PICKPGRP'
   AND   LISTNAME = 'REPORTCFG'
   AND   Long = 'RPT_WV_PLIST_WAVE_018_1'
   AND   ISNULL(Short, '') <> 'N'
   AND   Storerkey = @c_StorerKey

   --CS01 S

     IF @c_FirstTime = 'Y'
     BEGIN
         SET @c_PreGenRptData = 'Y'
     END
     ELSE
     BEGIN
          SET @c_PreGenRptData = IIF(ISNULL(@c_PreGenRptData, '') IN ( '0', '' ), '', @c_PreGenRptData)  
     END
      --CS01 E

   BEGIN TRAN


   INSERT INTO #TEMP_PICK
   SELECT (  SELECT PICKHEADER.PickHeaderKey
             FROM PICKHEADER (NOLOCK)
             WHERE PICKHEADER.WaveKey = @c_wavekey AND PICKHEADER.OrderKey = ORDERS.OrderKey AND PICKHEADER.Zone = '8')
        , ORDERS.OrderKey
        , ORDERS.ExternOrderKey
        , WAVEDETAIL.WaveKey
        , ISNULL(ORDERS.StorerKey, '')
        , ISNULL(ORDERS.InvoiceNo, '')
        , ISNULL(ORDERS.Route, '')
        , ISNULL(RouteMaster.Descr, '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.ConsigneeKey), '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Company), '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Address1), '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Address2), '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Address3), '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Zip), '')
        , ISNULL(dbo.fnc_RTRIM(ORDERS.C_City), '')
        , SKU.Sku
        , CASE WHEN ISNULL(CL4.Code, '') <> '' AND ISNULL(SKU.NOTES1, '') <> '' THEN SKU.NOTES1
               ELSE ISNULL(SKU.DESCR, '')END AS SkuDescr
        , CASE WHEN @c_pickgrp <> 'Y' THEN PICKDETAIL.Lot
               ELSE '' END AS Lot
        , ISNULL(LOTATTRIBUTE.Lottable01, '')
        , ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04, 112), '01/01/1900')
        , SUM(PICKDETAIL.Qty) AS QTY
        , ISNULL(PICKDETAIL.Loc, '')
        , ISNULL(PACK.Qty, 0) AS MasterUnit
        , ISNULL(PACK.PackUOM3, '') AS LowestUOM
        , ISNULL(PACK.CaseCnt, 0)
        , ISNULL(PACK.InnerPack, 0)
        , ISNULL(ORDERS.Capacity, 0.00)
        , ISNULL(ORDERS.GrossWeight, 0.00)
        , @c_PrintedFlag
        , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) AS Notes1
        , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) AS Notes2
        , ISNULL(LOTATTRIBUTE.Lottable02, '') Lottable02
        , CASE WHEN ISNULL(CL6.Code, '') = '' OR ISNULL(CL6.Code, '') = 'N' THEN ISNULL(ORDERS.DeliveryNote, '')
               ELSE ISNULL(ORDERS.BuyerPO, '')END DeliveryNote
        , SKU.SKUGROUP
        , 0
        , ORDERS.DeliveryDate
        , ORDERS.OrderGroup
        , CASE WHEN SKU.SUSR4 = 'SSCC' THEN '**Scan Serial No** '
               ELSE '' END
        , ISNULL(LOC.LogicalLocation, '')
        , ISNULL(LOTATTRIBUTE.Lottable03, '')
        , CASE WHEN @c_VASLBLValue = '1' AND CS.SKU = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5), '')
               ELSE '' END
        , CASE WHEN ISNULL(SC.Svalue, '') = '1' AND SKU.Sku <> SKU.RETAILSKU AND ISNULL(SKU.RETAILSKU, '') <> '' THEN
                  ISNULL(SKU.RETAILSKU, '')
               ELSE '' END AS RetailSku
        , CASE WHEN LEFT(ORDERS.UserDefine10, 3) = 'YFD' AND SKU.SKUGROUP = 'YFG' THEN 'YFG'
               ELSE '' END AS Internalflag
        , CASE WHEN MAX(ISNULL(CL1.Code, '')) = ''
               AND  MIN(PICKDETAIL.UOM) IN ( 1, 2 )
               AND  MAX(ISNULL(CL3.Code, '')) <> '' THEN '*'
               ELSE '' END AS scancaseidflag
        , CASE WHEN ISNULL(CL2.Code, '') <> '' THEN 'Y'
               ELSE 'N' END AS showbarcodeflag
        , '' AS udf01
        , ISNULL(ORDERS.UserDefine04, '')
        , CASE WHEN ISNULL(CL5.Code, '') <> '' THEN 'Y'
               ELSE 'N' END AS showfield
        , ISNULL(SUBSTRING(OD.UserDefine05, 1, 1), '') AS ODUDF05
        , CASE WHEN ISNULL(CL6.Code, '') <> '' THEN 'Y'
               ELSE 'N' END AS showbuyerpo
        , '' AS cskuudf04
        , CASE WHEN ISNULL(CL7.Code, '') <> '' THEN 'Y'
               ELSE 'N' END AS showpltpackage
        , CASE WHEN ISNULL(CS.UDF04, '') <> '' AND ISNULL(CS.UDF05, '') <> '' THEN
                  ISNULL(CS.UDF04, '') + 'x' + ISNULL(CS.UDF05, '')
               ELSE '' END
        , CASE WHEN ISNULL(CL8.Short, '') ='Y' THEN ISNULL(SKU.MANUFACTURERSKU,'') 
               ELSE '' END                      --CS01
   FROM PICKDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN ORDERDETAIL OD (NOLOCK) ON (   OD.OrderKey = PICKDETAIL.OrderKey
                                   AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber
                                   AND OD.Sku = PICKDETAIL.Sku
                                   AND OD.StorerKey = PICKDETAIL.Storerkey)
   JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = WAVEDETAIL.OrderKey)
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
   JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
   JOIN LOC (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc)
   LEFT OUTER JOIN RouteMaster (NOLOCK) ON (ORDERS.Route = RouteMaster.Route)
   LEFT OUTER JOIN STORER ST WITH (NOLOCK) ON (ST.StorerKey = ORDERS.ConsigneeKey)
   LEFT OUTER JOIN ConsigneeSKU CS WITH (NOLOCK) ON (CS.ConsigneeKey = ST.StorerKey) AND (CS.SKU = PICKDETAIL.Sku)
   LEFT OUTER JOIN V_StorerConfig2 SC WITH (NOLOCK) ON  ORDERS.StorerKey = SC.storerkey
                                                    AND SC.ConfigKey = 'DELNOTE06_RSKU'
   LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON (SKU.CLASS = CL1.Code AND CL1.LISTNAME = 'MHCSSCAN')
   LEFT OUTER JOIN CODELKUP CL2 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL2.Storerkey
                                            AND CL2.Code = 'SHOWBARCODE'
                                            AND CL2.LISTNAME = 'REPORTCFG'
                                            AND CL2.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL2.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL3.Storerkey
                                            AND CL3.Code = 'SHOWSCNFG'
                                            AND CL3.LISTNAME = 'REPORTCFG'
                                            AND CL3.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL3.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CL4 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL4.Storerkey
                                            AND CL4.Code = 'PRTSKUDESC'
                                            AND CL4.LISTNAME = 'REPORTCFG'
                                            AND CL4.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL4.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CL5 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL5.Storerkey
                                            AND CL5.Code = 'SHOWFIELD'
                                            AND CL5.LISTNAME = 'REPORTCFG'
                                            AND CL5.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL5.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CL6 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL6.Storerkey
                                            AND CL6.Code = 'SHOWBUYERPO'
                                            AND CL6.LISTNAME = 'REPORTCFG'
                                            AND CL6.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL6.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CL7 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL7.Storerkey
                                            AND CL7.Code = 'showPalletPackage'
                                            AND CL7.LISTNAME = 'REPORTCFG'
                                            AND CL7.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL7.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CL8 (NOLOCK) ON (   PICKDETAIL.Storerkey = CL8.Storerkey     --CS01
                                            AND CL8.Code = 'SHOWMSKU'
                                            AND CL8.LISTNAME = 'REPORTCFG'
                                            AND CL8.Long = 'RPT_WV_PLIST_WAVE_018_1'
                                            AND ISNULL(CL8.Short, '') <> 'N')
   WHERE (WAVEDETAIL.WaveKey = @c_wavekey)
   GROUP BY ORDERS.OrderKey
          , ORDERS.ExternOrderKey
          , WAVEDETAIL.WaveKey
          , ISNULL(ORDERS.StorerKey, '')
          , ISNULL(ORDERS.InvoiceNo, '')
          , ISNULL(ORDERS.Route, '')
          , ISNULL(RouteMaster.Descr, '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.ConsigneeKey), '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Company), '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Address1), '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Address2), '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Address3), '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.C_Zip), '')
          , ISNULL(dbo.fnc_RTRIM(ORDERS.C_City), '')
          , SKU.Sku
          , CASE WHEN ISNULL(CL4.Code, '') <> '' AND ISNULL(SKU.NOTES1, '') <> '' THEN SKU.NOTES1
                 ELSE ISNULL(SKU.DESCR, '')END
          , PICKDETAIL.Lot
          , ISNULL(LOTATTRIBUTE.Lottable01, '')
          , ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04, 112), '01/01/1900')
          , ISNULL(PICKDETAIL.Loc, '')
          , ISNULL(PACK.Qty, 0)
          , ISNULL(PACK.PackUOM3, '')
          , ISNULL(PACK.CaseCnt, 0)
          , ISNULL(PACK.InnerPack, 0)
          , ISNULL(ORDERS.Capacity, 0.00)
          , ISNULL(ORDERS.GrossWeight, 0.00)
          , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, ''))
          , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, ''))
          , ISNULL(LOTATTRIBUTE.Lottable02, '')
          , CASE WHEN ISNULL(CL6.Code, '') = '' OR ISNULL(CL6.Code, '') = 'N' THEN ISNULL(ORDERS.DeliveryNote, '')
                 ELSE ISNULL(ORDERS.BuyerPO, '')END
          , SKU.SKUGROUP
          , ORDERS.DeliveryDate
          , ORDERS.OrderGroup
          , CASE WHEN SKU.SUSR4 = 'SSCC' THEN '**Scan Serial No** '
                 ELSE '' END
          , ISNULL(LOC.LogicalLocation, '')
          , ISNULL(LOTATTRIBUTE.Lottable03, '')
          , CASE WHEN @c_VASLBLValue = '1' AND CS.SKU = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5), '')
                 ELSE '' END
          , CASE WHEN ISNULL(SC.Svalue, '') = '1' AND SKU.Sku <> SKU.RETAILSKU AND ISNULL(SKU.RETAILSKU, '') <> '' THEN
                    ISNULL(SKU.RETAILSKU, '')
                 ELSE '' END
          , CASE WHEN LEFT(ORDERS.UserDefine10, 3) = 'YFD' AND SKU.SKUGROUP = 'YFG' THEN 'YFG'
                 ELSE '' END
          , CASE WHEN ISNULL(CL2.Code, '') <> '' THEN 'Y'
                 ELSE 'N' END
          , ISNULL(ORDERS.UserDefine04, '')
          , CASE WHEN ISNULL(CL5.Code, '') <> '' THEN 'Y'
                 ELSE 'N' END
          , ISNULL(SUBSTRING(OD.UserDefine05, 1, 1), '')
          , CASE WHEN ISNULL(CL6.Code, '') <> '' THEN 'Y'
                 ELSE 'N' END
          , CASE WHEN ISNULL(CL7.Code, '') <> '' THEN 'Y'
                 ELSE 'N' END
          , CASE WHEN ISNULL(CS.UDF04, '') <> '' AND ISNULL(CS.UDF05, '') <> '' THEN
                    ISNULL(CS.UDF04, '') + 'x' + ISNULL(CS.UDF05, '')
                 ELSE '' END
          , CASE WHEN ISNULL(CL8.Short, '') ='Y' THEN ISNULL(SKU.MANUFACTURERSKU,'')    --CS01
               ELSE '' END                      

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


   DECLARE C_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
        , SKUGROUP
        , SUM(Qty)
   FROM #TEMP_PICK
   GROUP BY OrderKey
          , SKUGROUP

   OPEN C_Pickslip
   FETCH NEXT FROM C_Pickslip
   INTO @c_Orderkey
      , @c_SKUGROUP
      , @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF EXISTS (  SELECT *
                   FROM CODELKUP CLK WITH (NOLOCK)
                   WHERE LISTNAME = 'REPORTCFG'
                   AND   Code = 'afroutedes'
                   AND   Long = 'RPT_WV_PLIST_WAVE_018_1'
                   AND   Storerkey = @c_StorerKey)
      BEGIN

         SELECT TOP 1 @c_getUdf01 = C.UDF01
                    , @c_getUdf02 = C.UDF02
         FROM CODELKUP C WITH (NOLOCK)
         WHERE C.LISTNAME = 'REPORTCFG'
         AND   Code = 'afroutedes'
         AND   Long = 'RPT_WV_PLIST_WAVE_018_1'
         AND   C.Storerkey = @c_StorerKey

         SET @c_ExecStatements = N''
         SET @c_ExecArguments = N''
         SET @c_condition = N''
         SET @c_ordudf05 = N''

         IF ISNULL(@c_getUdf02, '') <> ''
         BEGIN
            SET @c_condition = N'AND ' + @c_getUdf02
         END
         ELSE
         BEGIN
            SET @c_condition = N'AND Orders.userdefine05=''*'''
         END

         SET @c_ExecStatements = N'SELECT @c_ordudf05 =' + @c_getUdf01
                                 + N' from Orders (nolock) where orderkey=@c_OrderKey '
         SET @c_ExecAllStatements = @c_ExecStatements + @c_condition

         SET @c_ExecArguments = N'@c_getudf01    NVARCHAR(100) ' + N',@c_OrderKey    NVARCHAR(30)'
                                + N',@c_ordudf05    NVARCHAR(20) OUTPUT'

         EXEC sp_executesql @c_ExecAllStatements
                          , @c_ExecArguments
                          , @c_getUdf01
                          , @c_Orderkey
                          , @c_ordudf05 OUTPUT




      END



      SET @c_CSKUUDF04 = N''

      SELECT @c_CSKUUDF04 = UDF04
      FROM ConsigneeSKU csku WITH (NOLOCK)
      JOIN ORDERS O WITH (NOLOCK) ON O.StorerKey = csku.StorerKey AND O.ConsigneeKey = csku.ConsigneeKey
      WHERE O.OrderKey = @c_Orderkey AND SKU IN (  SELECT TOP 1 Sku
                                                   FROM ORDERDETAIL (NOLOCK)
                                                   WHERE OrderKey = @c_Orderkey )

      UPDATE #TEMP_PICK
      SET SkuGroupQty = @n_Qty
        , UDF01 = @c_ordudf05
        , CSKUUDF04 = @c_CSKUUDF04
      WHERE OrderKey = @c_Orderkey AND SKUGROUP = @c_SKUGROUP
      FETCH NEXT FROM C_Pickslip
      INTO @c_Orderkey
         , @c_SKUGROUP
         , @n_Qty
   END
   CLOSE C_Pickslip
   DEALLOCATE C_Pickslip




   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo), '') = ''

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_pickslips_required > 0 AND @c_PreGenRptData ='Y'       --CS01
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP'
                        , 9
                        , @c_PickHeaderKey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                        , 0
                        , @n_pickslips_required

      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)
      SELECT 'P'
             + RIGHT(REPLICATE('0', 9)
                     + dbo.fnc_LTRIM(
                          dbo.fnc_RTRIM(
                             STR(
                                CAST(@c_PickHeaderKey AS INT)
                                + (  SELECT COUNT(DISTINCT OrderKey)
                                     FROM #TEMP_PICK AS Rank
                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                                     AND   ISNULL(RTRIM(Rank.PickSlipNo), '') = '')))), 9)
           , OrderKey
           , WaveKey
           , '0'
           , '8'
           , ''
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo), '') = ''
      GROUP BY WaveKey
             , OrderKey

      UPDATE #TEMP_PICK
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.WaveKey = #TEMP_PICK.WaveKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '8'
      AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo), '') = ''
   END

   GOTO SUCCESS


   FAILURE:
   DELETE FROM #TEMP_PICK
   SUCCESS:


   SET @c_StorerKey = N''
   SET @c_PickSlipNo = N''

   SELECT DISTINCT @c_StorerKey = StorerKey
   FROM #TEMP_PICK (NOLOCK)

   IF EXISTS (  SELECT 1
                FROM StorerConfig (NOLOCK)
                WHERE ConfigKey = 'AUTOSCANIN' AND SValue = '1' AND StorerKey = @c_StorerKey)
   BEGIN
      DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PickSlipNo
      FROM #TEMP_PICK (NOLOCK)

      OPEN C_AutoScanPickSlip
      FETCH NEXT FROM C_AutoScanPickSlip
      INTO @c_PickSlipNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF NOT EXISTS (  SELECT 1
                          FROM PickingInfo (NOLOCK)
                          WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_SNAME(), NULL)

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                    , @n_err = 61900
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                  + N': Insert PickingInfo Failed. (isp_RPT_WV_PLIST_WAVE_018_1)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + N' ) '
            END
         END

         FETCH NEXT FROM C_AutoScanPickSlip
         INTO @c_PickSlipNo
      END
      CLOSE C_AutoScanPickSlip
      DEALLOCATE C_AutoScanPickSlip
   END

   SELECT PickSlipNo
        , OrderKey
        , ExternOrderkey
        , WaveKey
        , StorerKey
        , InvoiceNo
        , Route
        , RouteDescr
        , ConsigneeKey
        , C_Company
        , C_Addr1
        , C_Addr2
        , C_Addr3
        , C_PostCode
        , C_City
        , Sku
        , SkuDescr
        , Lot
        , Lottable01
        , Lottable04
        , SUM(Qty) AS Qty
        , Loc
        , MasterUnit
        , LowestUOM
        , CaseCnt
        , InnerPack
        , Capacity
        , GrossWeight
        , PrintedFlag
        , Notes1
        , Notes2
        , Lottable02
        , DeliveryNote
        , SKUGROUP
        , SkuGroupQty
        , DeliveryDate
        , OrderGroup
        , scanserial
        , LogicalLoc
        , Lottable03
        , LabelFlag
        , RetailSku
        , Internalflag
        , scancaseidflag
        , showbarcodeflag
        , ISNULL(UDF01, '') AS udf01
        , ISNULL(OHUDF04, '') AS OHUDF04
        , showfield
        , ODUDF05
        , showbuyerpo
        , CSKUUDF04
        , showpltpackage
        , pltpackage
        , ManufactureSKU       --CS01
   FROM #TEMP_PICK
   GROUP BY PickSlipNo
          , OrderKey
          , ExternOrderkey
          , WaveKey
          , StorerKey
          , InvoiceNo
          , Route
          , RouteDescr
          , ConsigneeKey
          , C_Company
          , C_Addr1
          , C_Addr2
          , C_Addr3
          , C_PostCode
          , C_City
          , Sku
          , SkuDescr
          , Lot
          , Lottable01
          , Lottable04
          , Loc
          , MasterUnit
          , LowestUOM
          , CaseCnt
          , InnerPack
          , Capacity
          , GrossWeight
          , PrintedFlag
          , Notes1
          , Notes2
          , Lottable02
          , DeliveryNote
          , SKUGROUP
          , SkuGroupQty
          , DeliveryDate
          , OrderGroup
          , scanserial
          , LogicalLoc
          , Lottable03
          , LabelFlag
          , RetailSku
          , Internalflag
          , scancaseidflag
          , showbarcodeflag
          , udf01
          , OHUDF04
          , showfield
          , ODUDF05
          , showbuyerpo
          , CSKUUDF04
          , showpltpackage
          , pltpackage
          , ManufactureSKU       --CS01
   ORDER BY PickSlipNo
          , LogicalLoc
          , Loc
          , Sku
          , SKUGROUP

   DROP TABLE #TEMP_PICK

   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PLIST_WAVE_018_1'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
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