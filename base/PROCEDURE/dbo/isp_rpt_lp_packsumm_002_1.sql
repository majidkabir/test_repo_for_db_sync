SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PACKSUMM_002_1                             */
/* Creation Date:  08-SEP-2023                                             */
/* Copyright: MAERSK                                                       */
/* Written by: Aftab                                                       */
/*                                                                         */
/* Purpose: WMS-23626 - Migrate WMS report to Logi Report                  */
/*                                                                         */
/* Called By:RPT_LP_PACKSUMM_002_1                                         */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 08-Sep-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PACKSUMM_002_1]
(@c_Orderkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT
   SELECT @b_debug = 0

   DECLARE @c_PickSlipNo   NVARCHAR(10)
         , @c_GetOrderkey  NVARCHAR(10)
         , @c_SkuSize      NVARCHAR(5)
         , @c_TempOrderKey NVARCHAR(10)
         , @c_TempSize     NVARCHAR(5)
         , @n_TempQty      INT
         , @c_PrevOrderKey NVARCHAR(10)
         , @b_success      INT
         , @n_err          INT
         , @c_errmsg       NVARCHAR(255)
         , @n_Count        INT
         , @c_Column       NVARCHAR(10)
         , @c_SkuSize1     NVARCHAR(5)
         , @c_SkuSize2     NVARCHAR(5)
         , @c_SkuSize3     NVARCHAR(5)
         , @c_SkuSize4     NVARCHAR(5)
         , @c_SkuSize5     NVARCHAR(5)
         , @c_SkuSize6     NVARCHAR(5)
         , @c_SkuSize7     NVARCHAR(5)
         , @c_SkuSize8     NVARCHAR(5)
         , @c_SkuSize9     NVARCHAR(5)
         , @c_SkuSize10    NVARCHAR(5)
         , @c_SkuSize11    NVARCHAR(5)
         , @c_SkuSize12    NVARCHAR(5)
         , @c_SkuSize13    NVARCHAR(5)
         , @c_SkuSize14    NVARCHAR(5)
         , @c_SkuSize15    NVARCHAR(5)
         , @c_SkuSize16    NVARCHAR(5)
         , @c_SkuSize17    NVARCHAR(5)
         , @c_SkuSize18    NVARCHAR(5)
         , @c_SkuSize19    NVARCHAR(5)
         , @c_SkuSize20    NVARCHAR(5)
         , @c_SkuSize21    NVARCHAR(5)
         , @c_SkuSize22    NVARCHAR(5)
         , @c_SkuSize23    NVARCHAR(5)
         , @c_SkuSize24    NVARCHAR(5)
         , @c_SkuSize25    NVARCHAR(5)
         , @c_SkuSize26    NVARCHAR(5)
         , @c_SkuSize27    NVARCHAR(5)
         , @c_SkuSize28    NVARCHAR(5)
         , @c_SkuSize29    NVARCHAR(5)
         , @c_SkuSize30    NVARCHAR(5)
         , @c_SkuSize31    NVARCHAR(5)
         , @c_SkuSize32    NVARCHAR(5)
         , @c_Carton       FLOAT
         , @C_BUSR6        NVARCHAR(30)
         , @c_BUSR6_01     NVARCHAR(30)
         , @c_BUSR6_02     NVARCHAR(30)
         , @c_BUSR6_03     NVARCHAR(30)
         , @c_BUSR6_04     NVARCHAR(30)
         , @c_BUSR6_05     NVARCHAR(30)
         , @c_BUSR6_06     NVARCHAR(30)
         , @c_BUSR6_07     NVARCHAR(30)
         , @c_BUSR6_08     NVARCHAR(30)
         , @c_BUSR6_09     NVARCHAR(30)
         , @c_BUSR6_10     NVARCHAR(30)
         , @c_BUSR6_11     NVARCHAR(30)
         , @c_BUSR6_12     NVARCHAR(30)
         , @c_BUSR6_13     NVARCHAR(30)
         , @c_BUSR6_14     NVARCHAR(30)
         , @c_BUSR6_15     NVARCHAR(30)
         , @c_BUSR6_16     NVARCHAR(30)
         , @c_BUSR6_17     NVARCHAR(30)
         , @c_BUSR6_18     NVARCHAR(30)
         , @c_BUSR6_19     NVARCHAR(30)
         , @c_BUSR6_20     NVARCHAR(30)
         , @c_BUSR6_21     NVARCHAR(30)
         , @c_BUSR6_22     NVARCHAR(30)
         , @c_BUSR6_23     NVARCHAR(30)
         , @c_BUSR6_24     NVARCHAR(30)
         , @c_BUSR6_25     NVARCHAR(30)
         , @c_BUSR6_26     NVARCHAR(30)
         , @c_BUSR6_27     NVARCHAR(30)
         , @c_BUSR6_28     NVARCHAR(30)
         , @c_BUSR6_29     NVARCHAR(30)
         , @c_BUSR6_30     NVARCHAR(30)
         , @c_BUSR6_31     NVARCHAR(30)
         , @c_BUSR6_32     NVARCHAR(30)
         , @c_SkuSize33    NVARCHAR(5)
         , @c_SkuSize34    NVARCHAR(5)
         , @c_SkuSize35    NVARCHAR(5)
         , @c_SkuSize36    NVARCHAR(5)
         , @c_size         NVARCHAR(20)
         , @c_MoreField    NVARCHAR(30)

   CREATE TABLE #TempPickSlip
   (
      PickSlipNo     NVARCHAR(10)  NULL
    , Loadkey        NVARCHAR(10)  NULL
    , OrderKey       NVARCHAR(10)  NULL
    , ExternOrderKey NVARCHAR(50)  NULL
    , ExternPOkey    NVARCHAR(30)  NULL
    , Notes          NVARCHAR(255) NULL
    , ConsigneeKey   NVARCHAR(15)  NULL
    , Company        NVARCHAR(45)  NULL
    , c_Address1     NVARCHAR(45)  NULL
    , c_Address2     NVARCHAR(45)  NULL
    , c_Address3     NVARCHAR(45)  NULL
    , C_City         NVARCHAR(45)  NULL
    , C_Zip          NVARCHAR(18)  NULL
    , Userdefine06   DATETIME      NULL
    , Type           NVARCHAR(10)  NULL
    , CodelkupDesc   NVARCHAR(250) NULL
    , Sku            NVARCHAR(20)  NULL
    , UOM            NVARCHAR(10)  NULL
    , CaseCnt        FLOAT
    , TotCarton      FLOAT
    , SkuSize1       NVARCHAR(5)   NULL
    , SkuSize2       NVARCHAR(5)   NULL
    , SkuSize3       NVARCHAR(5)   NULL
    , SkuSize4       NVARCHAR(5)   NULL
    , SkuSize5       NVARCHAR(5)   NULL
    , SkuSize6       NVARCHAR(5)   NULL
    , SkuSize7       NVARCHAR(5)   NULL
    , SkuSize8       NVARCHAR(5)   NULL
    , SkuSize9       NVARCHAR(5)   NULL
    , SkuSize10      NVARCHAR(5)   NULL
    , SkuSize11      NVARCHAR(5)   NULL
    , SkuSize12      NVARCHAR(5)   NULL
    , SkuSize13      NVARCHAR(5)   NULL
    , SkuSize14      NVARCHAR(5)   NULL
    , SkuSize15      NVARCHAR(5)   NULL
    , SkuSize16      NVARCHAR(5)   NULL
    , SkuSize17      NVARCHAR(5)   NULL
    , SkuSize18      NVARCHAR(5)   NULL
    , SkuSize19      NVARCHAR(5)   NULL
    , SkuSize20      NVARCHAR(5)   NULL
    , SkuSize21      NVARCHAR(5)   NULL
    , SkuSize22      NVARCHAR(5)   NULL
    , SkuSize23      NVARCHAR(5)   NULL
    , SkuSize24      NVARCHAR(5)   NULL
    , SkuSize25      NVARCHAR(5)   NULL
    , SkuSize26      NVARCHAR(5)   NULL
    , SkuSize27      NVARCHAR(5)   NULL
    , SkuSize28      NVARCHAR(5)   NULL
    , SkuSize29      NVARCHAR(5)   NULL
    , SkuSize30      NVARCHAR(5)   NULL
    , SkuSize31      NVARCHAR(5)   NULL
    , SkuSize32      NVARCHAR(5)   NULL
    , Qty1           INT           NULL
    , Qty2           INT           NULL
    , Qty3           INT           NULL
    , Qty4           INT           NULL
    , Qty5           INT           NULL
    , Qty6           INT           NULL
    , Qty7           INT           NULL
    , Qty8           INT           NULL
    , Qty9           INT           NULL
    , Qty10          INT           NULL
    , Qty11          INT           NULL
    , Qty12          INT           NULL
    , Qty13          INT           NULL
    , Qty14          INT           NULL
    , Qty15          INT           NULL
    , Qty16          INT           NULL
    , Qty17          INT           NULL
    , Qty18          INT           NULL
    , Qty19          INT           NULL
    , Qty20          INT           NULL
    , Qty21          INT           NULL
    , Qty22          INT           NULL
    , Qty23          INT           NULL
    , Qty24          INT           NULL
    , Qty25          INT           NULL
    , Qty26          INT           NULL
    , Qty27          INT           NULL
    , Qty28          INT           NULL
    , Qty29          INT           NULL
    , Qty30          INT           NULL
    , Qty31          INT           NULL
    , Qty32          INT           NULL
    , StorerAdd1     NVARCHAR(45)  NULL
    , StorerAdd2     NVARCHAR(45)  NULL
    , StorerPhone1   NVARCHAR(18)  NULL
    , StorerCompany  NVARCHAR(45)  NULL
    , SkuSize33      NVARCHAR(5)   NULL
    , SkuSize34      NVARCHAR(5)   NULL
    , SkuSize35      NVARCHAR(5)   NULL
    , SkuSize36      NVARCHAR(5)   NULL
    , Qty33          INT           NULL
    , Qty34          INT           NULL
    , Qty35          INT           NULL
    , Qty36          INT           NULL
    , MoreField      NVARCHAR(30)  NULL
    , B_Company      NVARCHAR(45)  NULL
   )

   SELECT @c_TempOrderKey = N''
        , @n_Count = 0
   SELECT @c_SkuSize1 = N''
        , @c_SkuSize2 = N''
        , @c_SkuSize3 = N''
        , @c_SkuSize4 = N''
   SELECT @c_SkuSize5 = N''
        , @c_SkuSize6 = N''
        , @c_SkuSize7 = N''
        , @c_SkuSize8 = N''
   SELECT @c_SkuSize9 = N''
        , @c_SkuSize10 = N''
        , @c_SkuSize11 = N''
        , @c_SkuSize12 = N''
   SELECT @c_SkuSize13 = N''
        , @c_SkuSize14 = N''
        , @c_SkuSize15 = N''
        , @c_SkuSize16 = N''
   SELECT @c_SkuSize17 = N''
        , @c_SkuSize18 = N''
        , @c_SkuSize19 = N''
        , @c_SkuSize20 = N''
   SELECT @c_SkuSize21 = N''
        , @c_SkuSize22 = N''
        , @c_SkuSize23 = N''
        , @c_SkuSize24 = N''
   SELECT @c_SkuSize25 = N''
        , @c_SkuSize26 = N''
        , @c_SkuSize27 = N''
        , @c_SkuSize28 = N''
   SELECT @c_SkuSize29 = N''
        , @c_SkuSize30 = N''
        , @c_SkuSize31 = N''
        , @c_SkuSize32 = N''
   SELECT @c_SkuSize33 = N''
        , @c_SkuSize34 = N''
        , @c_SkuSize35 = N''
        , @c_SkuSize36 = N''
   SELECT @c_MoreField = N''


   SELECT @c_BUSR6_01 = N''
        , @c_BUSR6_02 = N''
        , @c_BUSR6_03 = N''
        , @c_BUSR6_04 = N''
   SELECT @c_BUSR6_05 = N''
        , @c_BUSR6_06 = N''
        , @c_BUSR6_07 = N''
        , @c_BUSR6_08 = N''
   SELECT @c_BUSR6_09 = N''
        , @c_BUSR6_10 = N''
        , @c_BUSR6_11 = N''
        , @c_BUSR6_12 = N''
   SELECT @c_BUSR6_13 = N''
        , @c_BUSR6_14 = N''
        , @c_BUSR6_15 = N''
        , @c_BUSR6_16 = N''
   SELECT @c_BUSR6_17 = N''
        , @c_BUSR6_18 = N''
        , @c_BUSR6_19 = N''
        , @c_BUSR6_20 = N''
   SELECT @c_BUSR6_21 = N''
        , @c_BUSR6_22 = N''
        , @c_BUSR6_23 = N''
        , @c_BUSR6_24 = N''
   SELECT @c_BUSR6_25 = N''
        , @c_BUSR6_26 = N''
        , @c_BUSR6_27 = N''
        , @c_BUSR6_28 = N''
   SELECT @c_BUSR6_29 = N''
        , @c_BUSR6_30 = N''
        , @c_BUSR6_31 = N''
        , @c_BUSR6_32 = N''

   SELECT DISTINCT OrderKey
   INTO #TempOrder
   FROM ORDERS (NOLOCK)
   WHERE OrderKey = @c_Orderkey

   WHILE (1 = 1)
   BEGIN
      SELECT @c_TempOrderKey = MIN(OrderKey)
      FROM #TempOrder
      WHERE OrderKey > @c_TempOrderKey

      IF @c_TempOrderKey IS NULL OR @c_TempOrderKey = ''
         BREAK

      DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) SSize
           , OD.OrderKey
           , '' BUSR6
           , CASE WHEN ISNUMERIC(C.Short) = 1 THEN CAST(CAST(C.Short AS FLOAT) AS NVARCHAR(10))
                  ELSE C.Short END
      FROM ORDERDETAIL OD (NOLOCK)
      JOIN LoadPlanDetail LP (NOLOCK) ON (LP.OrderKey = OD.OrderKey)
      JOIN SKU (NOLOCK) ON (SKU.Sku = OD.Sku AND SKU.StorerKey = OD.StorerKey)
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'SIZELSTORD'
                                         AND C.Storerkey = OD.StorerKey
                                         AND C.Code = dbo.fnc_RTRIM(
                                                         SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5))
      WHERE OD.OrderKey = @c_TempOrderKey --AND OD.LoadKey = @c_LoadKey
      GROUP BY dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5))
             , OD.OrderKey
             , CASE WHEN ISNUMERIC(C.Short) = 1 THEN CAST(CAST(C.Short AS FLOAT) AS NVARCHAR(10))
                    ELSE C.Short END
      ORDER BY OD.OrderKey
             , CASE WHEN ISNUMERIC(C.Short) = 1 THEN CAST(CAST(C.Short AS FLOAT) AS NVARCHAR(10))
                    ELSE C.Short END


      OPEN pick_cur
      FETCH NEXT FROM pick_cur
      INTO @c_SkuSize
         , @c_GetOrderkey
         , @C_BUSR6
         , @c_size

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN


         SELECT @n_Count = @n_Count + 1
         IF @b_debug = 1
         BEGIN
            SELECT 'Count of sizes is ' + CONVERT(NVARCHAR(5), @n_Count)
         END

         SELECT @c_SkuSize1 = CASE @n_Count
                                   WHEN 1 THEN @c_SkuSize
                                   ELSE @c_SkuSize1 END
         SELECT @c_SkuSize2 = CASE @n_Count
                                   WHEN 2 THEN @c_SkuSize
                                   ELSE @c_SkuSize2 END
         SELECT @c_SkuSize3 = CASE @n_Count
                                   WHEN 3 THEN @c_SkuSize
                                   ELSE @c_SkuSize3 END
         SELECT @c_SkuSize4 = CASE @n_Count
                                   WHEN 4 THEN @c_SkuSize
                                   ELSE @c_SkuSize4 END
         SELECT @c_SkuSize5 = CASE @n_Count
                                   WHEN 5 THEN @c_SkuSize
                                   ELSE @c_SkuSize5 END
         SELECT @c_SkuSize6 = CASE @n_Count
                                   WHEN 6 THEN @c_SkuSize
                                   ELSE @c_SkuSize6 END
         SELECT @c_SkuSize7 = CASE @n_Count
                                   WHEN 7 THEN @c_SkuSize
                                   ELSE @c_SkuSize7 END
         SELECT @c_SkuSize8 = CASE @n_Count
                                   WHEN 8 THEN @c_SkuSize
                                   ELSE @c_SkuSize8 END
         SELECT @c_SkuSize9 = CASE @n_Count
                                   WHEN 9 THEN @c_SkuSize
                                   ELSE @c_SkuSize9 END
         SELECT @c_SkuSize10 = CASE @n_Count
                                    WHEN 10 THEN @c_SkuSize
                                    ELSE @c_SkuSize10 END
         SELECT @c_SkuSize11 = CASE @n_Count
                                    WHEN 11 THEN @c_SkuSize
                                    ELSE @c_SkuSize11 END
         SELECT @c_SkuSize12 = CASE @n_Count
                                    WHEN 12 THEN @c_SkuSize
                                    ELSE @c_SkuSize12 END
         SELECT @c_SkuSize13 = CASE @n_Count
                                    WHEN 13 THEN @c_SkuSize
                                    ELSE @c_SkuSize13 END
         SELECT @c_SkuSize14 = CASE @n_Count
                                    WHEN 14 THEN @c_SkuSize
                                    ELSE @c_SkuSize14 END
         SELECT @c_SkuSize15 = CASE @n_Count
                                    WHEN 15 THEN @c_SkuSize
                                    ELSE @c_SkuSize15 END
         SELECT @c_SkuSize16 = CASE @n_Count
                                    WHEN 16 THEN @c_SkuSize
                                    ELSE @c_SkuSize16 END
         SELECT @c_SkuSize17 = CASE @n_Count
                                    WHEN 17 THEN @c_SkuSize
                                    ELSE @c_SkuSize17 END
         SELECT @c_SkuSize18 = CASE @n_Count
                                    WHEN 18 THEN @c_SkuSize
                                    ELSE @c_SkuSize18 END
         SELECT @c_SkuSize19 = CASE @n_Count
                                    WHEN 19 THEN @c_SkuSize
                                    ELSE @c_SkuSize19 END
         SELECT @c_SkuSize20 = CASE @n_Count
                                    WHEN 20 THEN @c_SkuSize
                                    ELSE @c_SkuSize20 END
         SELECT @c_SkuSize21 = CASE @n_Count
                                    WHEN 21 THEN @c_SkuSize
                                    ELSE @c_SkuSize21 END
         SELECT @c_SkuSize22 = CASE @n_Count
                                    WHEN 22 THEN @c_SkuSize
                                    ELSE @c_SkuSize22 END
         SELECT @c_SkuSize23 = CASE @n_Count
                                    WHEN 23 THEN @c_SkuSize
                                    ELSE @c_SkuSize23 END
         SELECT @c_SkuSize24 = CASE @n_Count
                                    WHEN 24 THEN @c_SkuSize
                                    ELSE @c_SkuSize24 END
         SELECT @c_SkuSize25 = CASE @n_Count
                                    WHEN 25 THEN @c_SkuSize
                                    ELSE @c_SkuSize25 END
         SELECT @c_SkuSize26 = CASE @n_Count
                                    WHEN 26 THEN @c_SkuSize
                                    ELSE @c_SkuSize26 END
         SELECT @c_SkuSize27 = CASE @n_Count
                                    WHEN 27 THEN @c_SkuSize
                                    ELSE @c_SkuSize27 END
         SELECT @c_SkuSize28 = CASE @n_Count
                                    WHEN 28 THEN @c_SkuSize
                                    ELSE @c_SkuSize28 END
         SELECT @c_SkuSize29 = CASE @n_Count
                                    WHEN 29 THEN @c_SkuSize
                                    ELSE @c_SkuSize29 END
         SELECT @c_SkuSize30 = CASE @n_Count
                                    WHEN 30 THEN @c_SkuSize
                                    ELSE @c_SkuSize30 END
         SELECT @c_SkuSize31 = CASE @n_Count
                                    WHEN 31 THEN @c_SkuSize
                                    ELSE @c_SkuSize31 END
         SELECT @c_SkuSize32 = CASE @n_Count
                                    WHEN 32 THEN @c_SkuSize
                                    ELSE @c_SkuSize32 END

         SELECT @c_SkuSize33 = CASE @n_Count
                                    WHEN 33 THEN @c_SkuSize
                                    ELSE @c_SkuSize33 END
         SELECT @c_SkuSize34 = CASE @n_Count
                                    WHEN 34 THEN @c_SkuSize
                                    ELSE @c_SkuSize34 END

         SELECT @c_SkuSize35 = CASE @n_Count
                                    WHEN 35 THEN @c_SkuSize
                                    ELSE @c_SkuSize35 END
         SELECT @c_SkuSize36 = CASE @n_Count
                                    WHEN 36 THEN @c_SkuSize
                                    ELSE @c_SkuSize36 END

         IF @n_Count > 36
         BEGIN
            SET @c_MoreField = N'More Fields'
         END


         IF @b_debug = 1
         BEGIN
            IF @c_TempOrderKey = '0000907514'
            BEGIN
               SELECT 'SkuSize is ' + @c_SkuSize
               SELECT 'SkuSize1 to 16 is ' + @c_SkuSize1 + ',' + @c_SkuSize2 + ',' + @c_SkuSize3 + ',' + @c_SkuSize4
                      + ',' + @c_SkuSize5 + ',' + @c_SkuSize6 + ',' + @c_SkuSize7 + ',' + @c_SkuSize8 + ','
                      + @c_SkuSize9 + ',' + @c_SkuSize10 + ',' + @c_SkuSize11 + ',' + @c_SkuSize12 + ',' + @c_SkuSize13
                      + ',' + @c_SkuSize14 + ',' + @c_SkuSize15 + ',' + @c_SkuSize16 + ',' + @c_SkuSize17 + ','
                      + @c_SkuSize18 + ',' + @c_SkuSize19 + ',' + @c_SkuSize20 + ',' + @c_SkuSize21 + ','
                      + @c_SkuSize22 + ',' + @c_SkuSize23 + ',' + @c_SkuSize24 + ',' + @c_SkuSize25 + ','
                      + @c_SkuSize26 + ',' + @c_SkuSize27 + ',' + @c_SkuSize28 + ',' + @c_SkuSize29 + ','
                      + @c_SkuSize30 + ',' + @c_SkuSize31 + ',' + @c_SkuSize32
               SELECT 'BUSR6_01 to 32 is ' + @c_BUSR6_01 + ',' + @c_BUSR6_02 + ',' + @c_BUSR6_03 + ',' + @c_BUSR6_04
                      + ',' + @c_BUSR6_05 + ',' + @c_BUSR6_06 + ',' + @c_BUSR6_07 + ',' + @c_BUSR6_08 + ','
                      + @c_BUSR6_09 + ',' + @c_BUSR6_10 + ',' + @c_BUSR6_11 + ',' + @c_BUSR6_12 + ',' + @c_BUSR6_13
                      + ',' + @c_BUSR6_14 + ',' + @c_BUSR6_15 + ',' + @c_BUSR6_16 + ',' + @c_BUSR6_17 + ','
                      + @c_BUSR6_18 + ',' + @c_BUSR6_19 + ',' + @c_BUSR6_20 + ',' + @c_BUSR6_21 + ',' + @c_BUSR6_22
                      + ',' + @c_BUSR6_23 + ',' + @c_BUSR6_24 + ',' + @c_BUSR6_25 + ',' + @c_BUSR6_26 + ','
                      + @c_BUSR6_27 + ',' + @c_BUSR6_28 + ',' + @c_BUSR6_29 + ',' + @c_BUSR6_30 + ',' + @c_BUSR6_31
                      + ',' + @c_BUSR6_32
            END
         END

         SELECT @c_PrevOrderKey = @c_GetOrderkey

         FETCH NEXT FROM pick_cur
         INTO @c_SkuSize
            , @c_GetOrderkey
            , @C_BUSR6
            , @c_size

         IF @b_debug = 1
         BEGIN
            SELECT 'PrevOrderkey= ' + @c_PrevOrderKey + ', Orderkey= ' + @c_GetOrderkey
         END

         IF (@c_PrevOrderKey <> @c_GetOrderkey) OR (@@FETCH_STATUS = -1)
         BEGIN
            INSERT INTO #TempPickSlip
            SELECT PICKHEADER.PickHeaderKey
                 , LoadPlanDetail.LoadKey
                 , ORDERS.OrderKey
                 , ORDERS.ExternOrderKey
                 , ORDERS.ExternPOKey
                 , CONVERT(NVARCHAR(255), ORDERS.Notes) Notes
                 , ORDERS.ConsigneeKey
                 , ORDERS.C_Company
                 , ORDERS.C_Address1
                 , ORDERS.C_Address2
                 , ORDERS.C_Address3
                 , ORDERS.C_City
                 , ORDERS.C_Zip
                 , ORDERS.UserDefine06
                 , ORDERS.Type
                 , Long = (  SELECT TOP 1 CODELKUP.Description
                             FROM CODELKUP (NOLOCK)
                             WHERE LISTNAME = 'ORDERTYPE'
                             AND   CODELKUP.Code = ORDERS.Type
                             AND   (CODELKUP.Storerkey = ORDERS.StorerKey OR ISNULL(CODELKUP.Storerkey, '') = '')
                             ORDER BY CODELKUP.Storerkey DESC)
                 , SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 1, 9) StyleColour
                 , PACK.PackUOM3 UOM
                 , PACK.CaseCnt
                 , "0" TotCarton
                 , @c_SkuSize1
                 , @c_SkuSize2
                 , @c_SkuSize3
                 , @c_SkuSize4
                 , @c_SkuSize5
                 , @c_SkuSize6
                 , @c_SkuSize7
                 , @c_SkuSize8
                 , @c_SkuSize9
                 , @c_SkuSize10
                 , @c_SkuSize11
                 , @c_SkuSize12
                 , @c_SkuSize13
                 , @c_SkuSize14
                 , @c_SkuSize15
                 , @c_SkuSize16
                 , @c_SkuSize17
                 , @c_SkuSize18
                 , @c_SkuSize19
                 , @c_SkuSize20
                 , @c_SkuSize21
                 , @c_SkuSize22
                 , @c_SkuSize23
                 , @c_SkuSize24
                 , @c_SkuSize25
                 , @c_SkuSize26
                 , @c_SkuSize27
                 , @c_SkuSize28
                 , @c_SkuSize29
                 , @c_SkuSize30
                 , @c_SkuSize31
                 , @c_SkuSize32
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize1 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize2 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize3 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize4 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize5 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize6 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize7 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize8 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize9 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize10 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize11 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize12 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize13 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize14 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize15 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize16 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize17 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize18 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize19 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize20 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize21 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize22 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize23 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize24 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize25 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize26 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize27 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize28 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize29 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize30 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize31 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize32 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , STORER.Address1
                 , STORER.Address2
                 , STORER.Phone1
                 , STORER.Company
                 , @c_SkuSize33
                 , @c_SkuSize34
                 , @c_SkuSize35
                 , @c_SkuSize36
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize33 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize34 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize35 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , CASE WHEN dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5)) = @c_SkuSize36 THEN
                           SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                        ELSE 0 END
                 , @c_MoreField
                 , ORDERS.B_Company
            FROM ORDERDETAIL OD (NOLOCK)
            JOIN ORDERS (NOLOCK) ON OD.OrderKey = ORDERS.OrderKey
            JOIN PACK (NOLOCK) ON OD.PackKey = PACK.PackKey
            JOIN LoadPlanDetail (NOLOCK) ON  OD.OrderKey = LoadPlanDetail.OrderKey
                                         AND LoadPlanDetail.LoadKey = ORDERS.LoadKey
            JOIN SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku)
            LEFT JOIN PICKHEADER (NOLOCK) ON (OD.OrderKey = PICKHEADER.OrderKey)
            JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
            WHERE ORDERS.OrderKey = @c_PrevOrderKey
            AND   PACK.CaseCnt > 0
            AND   1 = CASE dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5))
                           WHEN @c_SkuSize1 THEN 1
                           WHEN @c_SkuSize2 THEN 1
                           WHEN @c_SkuSize3 THEN 1
                           WHEN @c_SkuSize4 THEN 1
                           WHEN @c_SkuSize5 THEN 1
                           WHEN @c_SkuSize6 THEN 1
                           WHEN @c_SkuSize7 THEN 1
                           WHEN @c_SkuSize8 THEN 1
                           WHEN @c_SkuSize9 THEN 1
                           WHEN @c_SkuSize10 THEN 1
                           WHEN @c_SkuSize11 THEN 1
                           WHEN @c_SkuSize12 THEN 1
                           WHEN @c_SkuSize13 THEN 1
                           WHEN @c_SkuSize14 THEN 1
                           WHEN @c_SkuSize15 THEN 1
                           WHEN @c_SkuSize16 THEN 1
                           WHEN @c_SkuSize17 THEN 1
                           WHEN @c_SkuSize18 THEN 1
                           WHEN @c_SkuSize19 THEN 1
                           WHEN @c_SkuSize20 THEN 1
                           WHEN @c_SkuSize21 THEN 1
                           WHEN @c_SkuSize22 THEN 1
                           WHEN @c_SkuSize23 THEN 1
                           WHEN @c_SkuSize24 THEN 1
                           WHEN @c_SkuSize25 THEN 1
                           WHEN @c_SkuSize26 THEN 1
                           WHEN @c_SkuSize27 THEN 1
                           WHEN @c_SkuSize28 THEN 1
                           WHEN @c_SkuSize29 THEN 1
                           WHEN @c_SkuSize30 THEN 1
                           WHEN @c_SkuSize31 THEN 1
                           WHEN @c_SkuSize32 THEN 1
                           WHEN @c_SkuSize33 THEN 1
                           WHEN @c_SkuSize34 THEN 1
                           WHEN @c_SkuSize35 THEN 1
                           WHEN @c_SkuSize36 THEN 1
                           ELSE 0 END
            GROUP BY PICKHEADER.PickHeaderKey
                   , LoadPlanDetail.LoadKey
                   , ORDERS.OrderKey
                   , ORDERS.ExternOrderKey
                   , ORDERS.ExternPOKey
                   , CONVERT(NVARCHAR(255), ORDERS.Notes)
                   , ORDERS.ConsigneeKey
                   , ORDERS.C_Company
                   , ORDERS.C_Address1
                   , ORDERS.C_Address2
                   , ORDERS.C_Address3
                   , ORDERS.C_City
                   , ORDERS.C_Zip
                   , ORDERS.UserDefine06
                   , ORDERS.Type
                   , ORDERS.Type
                   , ORDERS.StorerKey
                   , SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 1, 9)
                   , dbo.fnc_RTRIM(SUBSTRING(dbo.fnc_RTRIM(dbo.fnc_LTRIM(OD.Sku)), 10, 5))
                   , PACK.PackUOM3
                   , PACK.CaseCnt
                   , SKU.BUSR6
                   , STORER.Address1
                   , STORER.Address2
                   , STORER.Phone1
                   , STORER.Company
                   , ORDERS.B_Company
            HAVING SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0
            ORDER BY ORDERS.OrderKey
                   , StyleColour
                   , UOM

            SELECT @n_Count = 0
            SELECT @c_SkuSize1 = N''
                 , @c_SkuSize2 = N''
                 , @c_SkuSize3 = N''
                 , @c_SkuSize4 = N''
            SELECT @c_SkuSize5 = N''
                 , @c_SkuSize6 = N''
                 , @c_SkuSize7 = N''
                 , @c_SkuSize8 = N''
            SELECT @c_SkuSize9 = N''
                 , @c_SkuSize10 = N''
                 , @c_SkuSize11 = N''
                 , @c_SkuSize12 = N''
            SELECT @c_SkuSize13 = N''
                 , @c_SkuSize14 = N''
                 , @c_SkuSize15 = N''
                 , @c_SkuSize16 = N''
            SELECT @c_SkuSize17 = N''
                 , @c_SkuSize18 = N''
                 , @c_SkuSize19 = N''
                 , @c_SkuSize20 = N''
            SELECT @c_SkuSize21 = N''
                 , @c_SkuSize22 = N''
                 , @c_SkuSize23 = N''
                 , @c_SkuSize24 = N''
            SELECT @c_SkuSize25 = N''
                 , @c_SkuSize26 = N''
                 , @c_SkuSize27 = N''
                 , @c_SkuSize28 = N''
            SELECT @c_SkuSize29 = N''
                 , @c_SkuSize30 = N''
                 , @c_SkuSize31 = N''
                 , @c_SkuSize32 = N''

            SELECT @c_SkuSize33 = N''
                 , @c_SkuSize34 = N''
                 , @c_SkuSize35 = N''
                 , @c_SkuSize36 = N''

            SELECT @c_BUSR6_01 = N''
                 , @c_BUSR6_02 = N''
                 , @c_BUSR6_03 = N''
                 , @c_BUSR6_04 = N''
            SELECT @c_BUSR6_05 = N''
                 , @c_BUSR6_06 = N''
                 , @c_BUSR6_07 = N''
                 , @c_BUSR6_08 = N''
            SELECT @c_BUSR6_09 = N''
                 , @c_BUSR6_10 = N''
                 , @c_BUSR6_11 = N''
                 , @c_BUSR6_12 = N''
            SELECT @c_BUSR6_13 = N''
                 , @c_BUSR6_14 = N''
                 , @c_BUSR6_15 = N''
                 , @c_BUSR6_16 = N''
            SELECT @c_BUSR6_17 = N''
                 , @c_BUSR6_18 = N''
                 , @c_BUSR6_19 = N''
                 , @c_BUSR6_20 = N''
            SELECT @c_BUSR6_21 = N''
                 , @c_BUSR6_22 = N''
                 , @c_BUSR6_23 = N''
                 , @c_BUSR6_24 = N''
            SELECT @c_BUSR6_25 = N''
                 , @c_BUSR6_26 = N''
                 , @c_BUSR6_27 = N''
                 , @c_BUSR6_28 = N''
            SELECT @c_BUSR6_29 = N''
                 , @c_BUSR6_30 = N''
                 , @c_BUSR6_31 = N''
                 , @c_BUSR6_32 = N''

         END
      END

      CLOSE pick_cur
      DEALLOCATE pick_cur

   END

   DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Loadkey
        , OrderKey
        , CONVERT(
             DECIMAL(20, 2)
           , SUM((Qty1 + Qty2 + Qty3 + Qty4 + Qty5 + Qty6 + Qty7 + Qty8 + Qty9 + Qty10 + Qty11 + Qty12 + Qty13
                  + Qty14 + Qty15 + Qty16 + Qty17 + Qty18 + Qty19 + Qty20 + Qty21 + Qty22 + Qty23 + Qty24 + Qty25
                  + Qty26 + Qty27 + Qty28 + Qty29 + Qty30 + Qty31 + Qty32 + Qty33 + Qty34 + Qty35 + Qty36) / CaseCnt))
   FROM #TempPickSlip
   GROUP BY Loadkey
          , OrderKey
          , CaseCnt

   OPEN pick_cur
   FETCH NEXT FROM pick_cur
   INTO @c_PickSlipNo
      , @c_GetOrderkey
      , @c_Carton

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      UPDATE #TempPickSlip
      SET TotCarton = TotCarton + @c_Carton
      WHERE Loadkey = @c_PickSlipNo AND OrderKey = @c_GetOrderkey
      FETCH NEXT FROM pick_cur
      INTO @c_PickSlipNo
         , @c_GetOrderkey
         , @c_Carton
   END

   CLOSE pick_cur
   DEALLOCATE pick_cur

   SELECT PickSlipNo
        , Loadkey
        , OrderKey
        , ExternOrderKey
        , ExternPOkey
        , Notes
        , ConsigneeKey
        , Company
        , RTRIM(c_Address1) AS c_Address1
        , LTRIM(c_Address2) AS c_Address2
        , RTRIM(c_Address3) AS c_Address3
        , C_City
        , C_Zip
        , Userdefine06
        , Type
        , CodelkupDesc
        , Sku
        , UOM
        , CaseCnt
        , CEILING(TotCarton) AS TotCarton
        , SkuSize1
        , SkuSize2
        , SkuSize3
        , SkuSize4
        , SkuSize5
        , SkuSize6
        , SkuSize7
        , SkuSize8
        , SkuSize9
        , SkuSize10
        , SkuSize11
        , SkuSize12
        , SkuSize13
        , SkuSize14
        , SkuSize15
        , SkuSize16
        , SkuSize17
        , SkuSize18
        , SkuSize19
        , SkuSize20
        , SkuSize21
        , SkuSize22
        , SkuSize23
        , SkuSize24
        , SkuSize25
        , SkuSize26
        , SkuSize27
        , SkuSize28
        , SkuSize29
        , SkuSize30
        , SkuSize31
        , SkuSize32
        , SUM(Qty1) Qty1
        , SUM(Qty2) Qty2
        , SUM(Qty3) Qty3
        , SUM(Qty4) Qty4
        , SUM(Qty5) Qty5
        , SUM(Qty6) Qty6
        , SUM(Qty7) Qty7
        , SUM(Qty8) Qty8
        , SUM(Qty9) Qty9
        , SUM(Qty10) Qty10
        , SUM(Qty11) Qty11
        , SUM(Qty12) Qty12
        , SUM(Qty13) Qty13
        , SUM(Qty14) Qty14
        , SUM(Qty15) Qty15
        , SUM(Qty16) Qty16
        , SUM(Qty17) Qty17
        , SUM(Qty18) Qty18
        , SUM(Qty19) Qty19
        , SUM(Qty20) Qty20
        , SUM(Qty21) Qty21
        , SUM(Qty22) Qty22
        , SUM(Qty23) Qty23
        , SUM(Qty24) Qty24
        , SUM(Qty25) Qty25
        , SUM(Qty26) Qty26
        , SUM(Qty27) Qty27
        , SUM(Qty28) Qty28
        , SUM(Qty29) Qty29
        , SUM(Qty30) Qty30
        , SUM(Qty31) Qty31
        , SUM(Qty32) Qty32
        , StorerAdd1
        , StorerAdd2
        , StorerPhone1
        , StorerCompany
        , SkuSize33
        , SkuSize34
        , SkuSize35
        , SkuSize36
        , SUM(Qty33) Qty33
        , SUM(Qty34) Qty34
        , SUM(Qty35) Qty35
        , SUM(Qty36) Qty36
        , MoreField
        , B_Company
        , SUBSTRING(TRIM(SKU), 1, 6) + '-' + SUBSTRING(TRIM(SKU), 7, 3) AS StyleColor
   FROM #TempPickSlip
   GROUP BY PickSlipNo
          , Loadkey
          , OrderKey
          , ExternOrderKey
          , ExternPOkey
          , Notes
          , ConsigneeKey
          , Company
          , c_Address1
          , c_Address2
          , c_Address3
          , C_City
          , C_Zip
          , Userdefine06
          , Type
          , CodelkupDesc
          , Sku
          , UOM
          , CaseCnt
          , TotCarton
          , SkuSize1
          , SkuSize2
          , SkuSize3
          , SkuSize4
          , SkuSize5
          , SkuSize6
          , SkuSize7
          , SkuSize8
          , SkuSize9
          , SkuSize10
          , SkuSize11
          , SkuSize12
          , SkuSize13
          , SkuSize14
          , SkuSize15
          , SkuSize16
          , SkuSize17
          , SkuSize18
          , SkuSize19
          , SkuSize20
          , SkuSize21
          , SkuSize22
          , SkuSize23
          , SkuSize24
          , SkuSize25
          , SkuSize26
          , SkuSize27
          , SkuSize28
          , SkuSize29
          , SkuSize30
          , SkuSize31
          , SkuSize32
          , StorerAdd1
          , StorerAdd2
          , StorerPhone1
          , StorerCompany
          , SkuSize33
          , SkuSize34
          , SkuSize35
          , SkuSize36
          , MoreField
          , B_Company
          , SUBSTRING(TRIM(SKU), 1, 6) + '-' + SUBSTRING(TRIM(SKU), 7, 3)
   ORDER BY OrderKey
          , SKU

   IF OBJECT_ID('tempdb..#TempOrder') IS NOT NULL
      DROP TABLE #TempOrder

   IF OBJECT_ID('tempdb..#TempPickSlip') IS NOT NULL
      DROP TABLE #TempPickSlip

   QUIT:
END

GO