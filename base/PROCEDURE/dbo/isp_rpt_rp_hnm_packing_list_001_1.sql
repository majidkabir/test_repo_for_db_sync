SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_RP_HNM_PACKING_LIST_001_1                     */
/* Creation Date: 09-Nov-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21179 - HNM Packing List                                   */
/*                                                                         */
/* Called By: RPT_RP_HNM_PACKING_LIST_001_1                                */
/*            Convert from HNM Web Report:                                 */
/*            https://wms.lfapps.net/WMSReport/                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver  Purposes                                     */
/* 09-Nov-2022  WLChooi  1.0  DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_HNM_PACKING_LIST_001_1]
(
   @c_StorerKey NVARCHAR(15)
 , @c_OrderKey  NVARCHAR(10)
 , @c_HMOrder   NVARCHAR(30)
 , @c_ProductID NVARCHAR(50)
 , @c_Type      NVARCHAR(10) = 'TD1'
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ArticleID   NVARCHAR(100)
         , @n_TotalQty    INT          = 0
         , @c_PackingMode NVARCHAR(10)
         , @c_Size        NVARCHAR(200)
         , @c_SizeInText  NVARCHAR(200)
         , @c_SQL         NVARCHAR(MAX)
         , @c_SQL2        NVARCHAR(MAX)
         , @c_SQLExecArg  NVARCHAR(MAX)
         , @n_CountRec    INT
         , @n_CurrRec     INT
         , @c_Columns     NVARCHAR(500) = ''
         , @c_GetSize     NVARCHAR(100)

   DECLARE @T_DET1 AS TABLE
   (
      CartonType NVARCHAR(50) NULL
    , CartonSize NVARCHAR(50) NULL
    , CtnCount   INT          NULL
   )

   DECLARE @T_DET2 AS TABLE
   (
      TotalQty    INT          NULL
    , Article     NVARCHAR(30) NULL
    , Qty         INT          NULL
    , SumCtnCount INT          NULL
   )

   DECLARE @T_DET2_1 AS TABLE
   (
      HDR   NVARCHAR(100)
    , DET   NVARCHAR(100)
    , SeqNo INT
   )

   DECLARE @T_DET2_2 AS TABLE
   (
      HDR   NVARCHAR(100)
    , DET   NVARCHAR(100)
    , Tick  NVARCHAR(10)
    , SeqNo INT
   )

   CREATE TABLE #TMP_DET3_TEMP
   (
      Size        NVARCHAR(30) NULL
    , STDGrossWgt NVARCHAR(30) NULL
   )

   CREATE TABLE #TMP_DET3
   (
      HDR01   NVARCHAR(100)
    , DET01   NVARCHAR(100) NULL
    , DET02   NVARCHAR(100) NULL
    , DET03   NVARCHAR(100) NULL
    , DET04   NVARCHAR(100) NULL
    , DET05   NVARCHAR(100) NULL
    , DET06   NVARCHAR(100) NULL
    , DET07   NVARCHAR(100) NULL
    , DET08   NVARCHAR(100) NULL
    , DET09   NVARCHAR(100) NULL
    , DET10   NVARCHAR(100) NULL
    , DET11   NVARCHAR(100) NULL
   )

   CREATE TABLE #TMP_DET4
   (
      Orderkey      NVARCHAR(10)
    , HMOrder       NVARCHAR(50)  NULL
    , CartonNo      INT           NULL
    , ArticleNumber NVARCHAR(50)  NULL
    , Color         NVARCHAR(50)  NULL
    , CartonType    NVARCHAR(50)  NULL
    , HDR01         NVARCHAR(100) NULL
    , DET01         INT NULL
    , HDR02         NVARCHAR(100) NULL
    , DET02         INT NULL
    , HDR03         NVARCHAR(100) NULL
    , DET03         INT NULL
    , HDR04         NVARCHAR(100) NULL
    , DET04         INT NULL
    , HDR05         NVARCHAR(100) NULL
    , DET05         INT NULL
    , HDR06         NVARCHAR(100) NULL
    , DET06         INT NULL
    , HDR07         NVARCHAR(100) NULL
    , DET07         INT NULL
    , HDR08         NVARCHAR(100) NULL
    , DET08         INT NULL
    , HDR09         NVARCHAR(100) NULL
    , DET09         INT NULL
    , HDR10         NVARCHAR(100) NULL
    , DET10         INT NULL
   )

   SET @c_ArticleID = TRIM(@c_ProductID) + N'%'

   IF ISNULL(@c_Type, '') = ''
      SET @c_Type = 'TD1'

   --Debug
   --SET @c_StorerKey = 'HM'
   --SET @c_OrderKey  = '0001648983'
   --SET @c_HMOrder   = '102718'
   --SET @c_ProductID = '0176754'

   --'HM','0001648983','102718','0176754', 'TD2_2'

   --Detail
   INSERT INTO @T_DET1 (CartonType, CartonSize, CtnCount)
   SELECT AllCtnInfo.CartonType
        , CartonSize
        , COUNT(1) [CtnCount]
   FROM (  SELECT PackDT.PickSlipNo
                , PackDT.CartonNo
                , PackDT.LabelNo
                , PackInf.CartonType
                , ISNULL(CtnInfo.Notes, 'No size info') [CartonSize] --<Warning>No size info
           FROM ORDERS (NOLOCK) OrdHD
           JOIN PackHeader (NOLOCK) PackHD ON PackHD.OrderKey = OrdHD.OrderKey AND PackHD.StorerKey = OrdHD.StorerKey
           JOIN PackDetail (NOLOCK) PackDT ON  PackDT.PickSlipNo = PackHD.PickSlipNo
                                           AND PackDT.StorerKey = PackHD.StorerKey
           JOIN PackInfo (NOLOCK) PackInf ON  PackDT.PickSlipNo = PackInf.PickSlipNo
                                          AND PackDT.CartonNo = PackInf.CartonNo
           LEFT JOIN CODELKUP (NOLOCK) CtnInfo ON  PackInf.CartonType = CtnInfo.Short
                                               AND CtnInfo.LISTNAME IN ( 'HMCARTON', 'COSCARTON', 'OSECARTON'
                                                                       , 'AKTCARTON' )
                                               AND CtnInfo.UDF01 = OrdHD.ShipperKey
                                               AND CtnInfo.Storerkey = OrdHD.StorerKey
           WHERE OrdHD.OrderKey = @c_OrderKey
           GROUP BY PackDT.PickSlipNo
                  , PackDT.CartonNo
                  , PackDT.LabelNo
                  , PackInf.CartonType
                  , ISNULL(CtnInfo.Notes, 'No size info')) AllCtnInfo
   JOIN (  SELECT PickDT.OrderKey
                , PickDT.DropID
           FROM PICKDETAIL (NOLOCK) PickDT
           JOIN LOTATTRIBUTE (NOLOCK) LotAttr ON PickDT.Lot = LotAttr.Lot AND PickDT.Sku = LotAttr.Sku
           WHERE PickDT.OrderKey = @c_OrderKey AND PickDT.Sku LIKE @c_ArticleID AND LotAttr.Lottable12 = @c_HMOrder
           GROUP BY PickDT.OrderKey
                  , PickDT.DropID) PackedCtnInfo ON AllCtnInfo.LabelNo = PackedCtnInfo.DropID
   GROUP BY AllCtnInfo.CartonType
          , CartonSize

   IF @c_Type = 'TD1'
   BEGIN
      SELECT TD1.CartonType
           , TD1.CartonSize
           , TD1.CtnCount
      FROM @T_DET1 TD1
   END
   ELSE IF @c_Type = 'TD2_1'
   BEGIN
      INSERT INTO @T_DET2_1 (HDR, DET, SeqNo)
      SELECT 'Total Weight: '
           , 'Net: '
           , 1
      UNION ALL
      SELECT 'Total Weight: '
           , 'Gross: '
           , 2
      UNION ALL
      SELECT 'Total Weight: '
           , 'Volume: '
           , 3

      SELECT TD2_1.HDR
           , TD2_1.DET
      FROM @T_DET2_1 TD2_1
      ORDER BY TD2_1.SeqNo
   END
   ELSE IF @c_Type IN ( 'TD2_2', 'TD2_3' )
   BEGIN
      SELECT @n_TotalQty = SUM(Qty)
      FROM ORDERDETAIL (NOLOCK) A
      JOIN (  SELECT OrderKey
                   , OrderLineNumber
                   , Storerkey
                   , SUM(Qty) [Qty]
                   , Sku
                   , Lot
              FROM PICKDETAIL (NOLOCK)
              WHERE OrderKey = @c_OrderKey AND Storerkey = @c_StorerKey
              GROUP BY OrderKey
                     , OrderLineNumber
                     , Storerkey
                     , Sku
                     , Lot) B ON  A.OrderKey = B.OrderKey
                              AND A.OrderLineNumber = B.OrderLineNumber
                              AND A.StorerKey = B.Storerkey
      JOIN LOTATTRIBUTE (NOLOCK) C ON B.Storerkey = C.StorerKey AND B.Lot = C.Lot AND B.Sku = C.Sku
      WHERE C.Lottable12 = @c_HMOrder
      AND   B.Sku LIKE @c_ArticleID
      AND   A.OrderKey = @c_OrderKey
      AND   C.Lottable12 = @c_HMOrder

      INSERT INTO @T_DET2 (TotalQty, Article, Qty, SumCtnCount)
      SELECT @n_TotalQty
           , SUBSTRING(OD.Sku, 8, 3) [Article]
           , SUM(PD.Qty) [Qty]
           , (  SELECT SUM(CtnCount)
                FROM @T_DET1 TD) AS SumCtnCount
      FROM ORDERDETAIL (NOLOCK) OD
      JOIN PICKDETAIL (NOLOCK) PD ON  OD.OrderKey = PD.OrderKey
                                  AND OD.OrderLineNumber = PD.OrderLineNumber
                                  AND OD.StorerKey = PD.Storerkey
      JOIN LOTATTRIBUTE (NOLOCK) LA ON PD.Lot = LA.Lot AND PD.Sku = LA.Sku AND PD.Storerkey = LA.StorerKey
      WHERE OD.OrderKey = @c_OrderKey AND LA.Lottable12 = @c_HMOrder AND OD.Sku LIKE @c_ArticleID
      GROUP BY SUBSTRING(OD.Sku, 8, 3);

      WITH CTE AS
      (
         SELECT A.OrderKey
              , F.Sku
              , G.Lottable12 [HMOrder#]
         FROM ORDERDETAIL (NOLOCK) A
         JOIN (  SELECT OrderKey
                      , OrderLineNumber
                      , Storerkey
                      , SUM(Qty) [Qty]
                      , DropID
                      , Sku
                 FROM PICKDETAIL (NOLOCK)
                 WHERE OrderKey = @c_OrderKey AND Storerkey = @c_StorerKey
                 GROUP BY OrderKey
                        , OrderLineNumber
                        , Storerkey
                        , DropID
                        , Sku) B ON  A.OrderKey = B.OrderKey
                                 AND A.OrderLineNumber = B.OrderLineNumber
                                 AND A.StorerKey = B.Storerkey
         JOIN PackHeader (NOLOCK) C ON A.OrderKey = C.OrderKey AND A.StorerKey = C.StorerKey
         JOIN PackInfo (NOLOCK) D ON C.PickSlipNo = D.PickSlipNo
         JOIN (  SELECT DISTINCT PickSlipNo
                               , CartonNo
                               , LabelNo
                               , StorerKey
                 FROM PackDetail (NOLOCK)
                 WHERE PickSlipNo IN (  SELECT PickSlipNo
                                        FROM PackHeader (NOLOCK)
                                        WHERE OrderKey = @c_OrderKey )) E ON  D.PickSlipNo = E.PickSlipNo
                                                                          AND D.CartonNo = E.CartonNo
                                                                          AND B.DropID = E.LabelNo
                                                                          AND A.StorerKey = E.StorerKey
         JOIN (  SELECT OrderKey
                      , OrderLineNumber
                      , SUM(Qty) [DeliveredQty]
                      , Storerkey
                      , Sku
                      , Lot
                 FROM PICKDETAIL (NOLOCK)
                 WHERE OrderKey = @c_OrderKey
                 GROUP BY OrderKey
                        , OrderLineNumber
                        , Storerkey
                        , Sku
                        , Lot) F ON  B.OrderKey = F.OrderKey
                                 AND B.OrderLineNumber = F.OrderLineNumber
                                 AND B.Storerkey = F.Storerkey
                                 AND B.Sku = F.Sku
         JOIN LOTATTRIBUTE (NOLOCK) G ON F.Storerkey = G.StorerKey AND F.Lot = G.Lot AND F.Sku = G.Sku
         JOIN SKU (NOLOCK) H ON F.Storerkey = H.StorerKey AND F.Sku = H.Sku
         WHERE A.OrderKey = @c_OrderKey AND A.Sku LIKE @c_ArticleID AND G.Lottable12 = @c_HMOrder
         GROUP BY A.OrderKey
                , F.Sku
                , G.Lottable12
                , H.Size
                , H.BUSR6
      )
      SELECT @c_PackingMode = CASE WHEN COUNT(1) = 1 THEN 'S'
                                   ELSE 'M' END
      FROM CTE

      IF @c_Type = 'TD2_3'
      BEGIN
         SELECT TD2.TotalQty
              , TD2.SumCtnCount
              , 'Article: ' AS Article_HDR
              , TD2.Article
              , TD2.Qty
              , 'Total Pcs ' AS HDR
              , (  SELECT COUNT(1)
                   FROM @T_DET2) AS TotalRec
         FROM @T_DET2 TD2
      END
      ELSE
      BEGIN
         INSERT INTO @T_DET2_2 (HDR, DET, Tick, SeqNo)
         SELECT 'Packing Mode: '
              , 'Solid '
              , CASE WHEN @c_PackingMode = 'S' THEN 'X'
                     ELSE '' END
              , 1
         UNION ALL
         SELECT 'Packing Mode: '
              , 'Assorted '
              , ''
              , 2
         UNION ALL
         SELECT 'Packing Mode: '
              , 'Mixed '
              , CASE WHEN @c_PackingMode = 'M' THEN 'X'
                     ELSE '' END
              , 3
         UNION ALL
         SELECT 'Packing Mode: '
              , 'Flat(F)/Hanging(H) '
              , ''
              , 4

         SELECT TD2_2.HDR
              , TD2_2.DET
              , TD2_2.Tick
         FROM @T_DET2_2 TD2_2
         ORDER BY TD2_2.SeqNo
      END
   END
   ELSE IF @c_Type = 'TD3'
   BEGIN
      INSERT INTO #TMP_DET3_TEMP (Size, STDGrossWgt)
      SELECT DISTINCT TOP 11 S.Size [Size]
                           , S.STDGROSSWGT
      FROM ORDERDETAIL (NOLOCK) OD
      JOIN PICKDETAIL (NOLOCK) PD ON  OD.OrderKey = PD.OrderKey
                                  AND OD.OrderLineNumber = PD.OrderLineNumber
                                  AND OD.StorerKey = PD.Storerkey
      JOIN LOTATTRIBUTE (NOLOCK) LA ON PD.Lot = LA.Lot AND PD.Sku = LA.Sku AND PD.Storerkey = LA.StorerKey
      JOIN SKU (NOLOCK) S ON OD.StorerKey = S.StorerKey AND OD.Sku = S.Sku
      WHERE OD.OrderKey = @c_OrderKey AND OD.Sku LIKE @c_ArticleID AND LA.Lottable12 = @c_HMOrder

      SELECT @n_CountRec = COUNT(1)
      FROM #TMP_DET3_TEMP

      SET @c_SQL = ' INSERT INTO #TMP_DET3 ( HDR01'
      SET @n_CurrRec = 1

      WHILE @n_CountRec > 0
      BEGIN
         SET @c_SQL = @c_SQL + ', DET' + RIGHT('00' + CAST(@n_CurrRec AS NVARCHAR), 2)
         SET @n_CountRec = @n_CountRec - 1
         SET @n_CurrRec = @n_CurrRec + 1
      END

      SET @c_SQL = @c_SQL + ' ) '

      SET @c_Size = STUFF((  SELECT ',' + QUOTENAME(Size)
                             FROM #TMP_DET3_TEMP
                             WHERE Size <> ''
                             ORDER BY Size
                             FOR XML PATH(''))
                        , 1
                        , 1
                        , '')
      SET @c_SizeInText = REPLACE(REPLACE(@c_Size, '[', ''''), ']', '''')

      SET @c_SQL = @c_SQL
                 + ' SELECT ''Size'', ' + @c_SizeInText + CHAR(13)
                 + ' UNION ALL ' + CHAR(13)
                 + ' SELECT ''Net per size(g):'' AS Size, ' + @c_Size + CHAR(13)
                 + ' FROM (  ' + CHAR(13)
                 + '    SELECT Size, STDGrossWgt ' + CHAR(13)
                 + '    FROM #TMP_DET3_TEMP ' + CHAR(13)
                 + ' ) AS TTA ' + CHAR(13)
                 + ' PIVOT ' + CHAR(13)
                 + ' ( ' + CHAR(13)
                 + '    MAX(STDGrossWgt) ' + CHAR(13)
                 + '    FOR Size IN ('+ @c_Size + ') ' + CHAR(13)
                 + ' ) AS PivotTable '

      EXEC sp_executesql @c_SQL

      ;WITH CTE1 AS (SELECT TD3.HDR01 AS SizeHDR01
                       , TD3.DET01 AS Size01
                       , TD3.DET02 AS Size02
                       , TD3.DET03 AS Size03
                       , TD3.DET04 AS Size04
                       , TD3.DET05 AS Size05
                       , TD3.DET06 AS Size06
                       , TD3.DET07 AS Size07
                       , TD3.DET08 AS Size08
                       , TD3.DET09 AS Size09
                       , TD3.DET10 AS Size10
                       , TD3.DET11 AS Size11
                       , '1' AS ID
                  FROM #TMP_DET3 TD3
                  WHERE TD3.HDR01 = 'Size')
      , CTE2 AS ( SELECT TD3.HDR01 AS WgtHDR01
                       , TD3.DET01 AS Wgt01
                       , TD3.DET02 AS Wgt02
                       , TD3.DET03 AS Wgt03
                       , TD3.DET04 AS Wgt04
                       , TD3.DET05 AS Wgt05
                       , TD3.DET06 AS Wgt06
                       , TD3.DET07 AS Wgt07
                       , TD3.DET08 AS Wgt08
                       , TD3.DET09 AS Wgt09
                       , TD3.DET10 AS Wgt10
                       , TD3.DET11 AS Wgt11
                       , '1' AS ID
                  FROM #TMP_DET3 TD3
                  WHERE TD3.HDR01 = 'Net per size(g):')
      SELECT CTE1.SizeHDR01
           , CTE2.WgtHDR01
           , CTE1.Size01
           , CTE2.Wgt01
           , CTE1.Size02
           , CTE2.Wgt02
           , CTE1.Size03
           , CTE2.Wgt03
           , CTE1.Size04
           , CTE2.Wgt04
           , CTE1.Size05
           , CTE2.Wgt05
           , CTE1.Size06
           , CTE2.Wgt06
           , CTE1.Size07
           , CTE2.Wgt07
           , CTE1.Size08
           , CTE2.Wgt08
           , CTE1.Size09
           , CTE2.Wgt09
           , CTE1.Size10
           , CTE2.Wgt10
           , CTE1.Size11
           , CTE2.Wgt11
      FROM CTE1 
      JOIN CTE2 ON CTE2.ID = CTE1.ID
   END
   ELSE IF @c_Type = 'TD4'
   BEGIN
      ;WITH CTE AS (SELECT DISTINCT QUOTENAME(UPPER(RTRIM(S.Size))) [Size]
                    FROM ORDERDETAIL (NOLOCK) OD
                    JOIN PICKDETAIL (NOLOCK) PD ON  OD.OrderKey = PD.OrderKey
                                                AND OD.OrderLineNumber = PD.OrderLineNumber
                                                AND OD.StorerKey = PD.Storerkey
                    JOIN LOTATTRIBUTE (NOLOCK) LA ON PD.Lot = LA.Lot AND PD.Sku = LA.Sku AND PD.Storerkey = LA.StorerKey
                    JOIN SKU (NOLOCK) S ON OD.StorerKey = S.StorerKey AND OD.Sku = S.Sku
                    WHERE OD.OrderKey = @c_OrderKey AND LA.Lottable12 = @c_HMOrder AND OD.Sku LIKE @c_ArticleID)
      SELECT @c_Size = STUFF(( SELECT ',' + Size
                               FROM CTE
                               ORDER BY 1
                               FOR XML PATH(''))
                        , 1
                        , 1
                        , '')

      SET @n_CurrRec = 1
      SET @c_SQL2 = ''

      DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TOP 10 TRIM(SS.[Value])
      FROM STRING_SPLIT(@c_Size,',') SS

      OPEN CUR_SPLIT

      FETCH NEXT FROM CUR_SPLIT INTO @c_GetSize

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_SQL2 = ''
         BEGIN
            SET @c_SQL2 = REPLACE(REPLACE(@c_GetSize,'[',''''),']','''') + ' AS HDR' + RIGHT('00' + CAST(@n_CurrRec AS NVARCHAR), 2)
                        + ', '
                        + @c_GetSize + ' AS DET' + RIGHT('00' + CAST(@n_CurrRec AS NVARCHAR), 2)
         END
         ELSE 
         BEGIN
            SET @c_SQL2 = @c_SQL2 + ', ' + REPLACE(REPLACE(@c_GetSize,'[',''''),']','''') + ' AS HDR' + RIGHT('00' + CAST(@n_CurrRec AS NVARCHAR), 2)
                        + ', '
                        + @c_GetSize + ' AS DET' + RIGHT('00' + CAST(@n_CurrRec AS NVARCHAR), 2)
         END

         SET @n_CurrRec = @n_CurrRec + 1
         FETCH NEXT FROM CUR_SPLIT INTO @c_GetSize
      END
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT

      SET @n_CurrRec = 10 - (@n_CurrRec - 1)
      SET @c_SQL2 = @c_SQL2 + REPLICATE(', ''''',(@n_CurrRec * 2))

      SET @c_SQL = ' INSERT INTO #TMP_DET4 ' + CHAR(13)
                 + ' SELECT Orderkey, [HMOrder#], CartonNo, [ArticleNumber], [Color], CartonType, ' + CHAR(13)
                 + @c_SQL2 + CHAR(13)
                 + ' FROM (  SELECT A.OrderKey ' + CHAR(13)
                 + '              , G.Lottable12 [HMOrder#] ' + CHAR(13)
                 + '              , E.CartonNo ' + CHAR(13)
                 + '              , SUBSTRING(B.Sku, 1, 7) + '' '' + SUBSTRING(B.Sku, 8, 3) [ArticleNumber] ' + CHAR(13)
                 + '              , H.BUSR6 [Color] ' + CHAR(13)
                 + '              , H.Size [Size] ' + CHAR(13)
                 + '              , D.CartonType ' + CHAR(13)
                 + '              , SUM(B.DeliveredQty) [PackedQuantity] ' + CHAR(13)
                 + '         FROM ORDERDETAIL (NOLOCK) A ' + CHAR(13)
                 + '         JOIN (  SELECT OrderKey ' + CHAR(13)
                 + '                      , OrderLineNumber ' + CHAR(13)
                 + '                      , SUM(Qty) [DeliveredQty] ' + CHAR(13)
                 + '                      , Storerkey ' + CHAR(13)
                 + '                      , Sku ' + CHAR(13)
                 + '                      , Lot ' + CHAR(13)
                 + '                      , DropID ' + CHAR(13)
                 + '                 FROM PICKDETAIL (NOLOCK) ' + CHAR(13)
                 + '                 WHERE OrderKey = @c_OrderKey AND Storerkey = @c_StorerKey ' + CHAR(13)
                 + '                 GROUP BY OrderKey ' + CHAR(13)
                 + '                        , OrderLineNumber ' + CHAR(13)
                 + '                        , Storerkey ' + CHAR(13)
                 + '                        , Sku ' + CHAR(13)
                 + '                        , Lot ' + CHAR(13)
                 + '                        , DropID) B ON  A.OrderKey = B.OrderKey ' + CHAR(13)
                 + '                                    AND A.OrderLineNumber = B.OrderLineNumber ' + CHAR(13)
                 + '                                    AND A.StorerKey = B.Storerkey ' + CHAR(13)
                 + '         JOIN PackHeader (NOLOCK) C ON A.OrderKey = C.OrderKey AND A.StorerKey = C.StorerKey ' + CHAR(13)
                 + '         JOIN PackInfo (NOLOCK) D ON C.PickSlipNo = D.PickSlipNo ' + CHAR(13)
                 + '         JOIN (  SELECT DISTINCT PickSlipNo ' + CHAR(13)
                 + '                               , CartonNo ' + CHAR(13)
                 + '                               , LabelNo ' + CHAR(13)
                 + '                               , StorerKey ' + CHAR(13)
                 + '                 FROM PackDetail (NOLOCK) ' + CHAR(13)
                 + '                 WHERE PickSlipNo IN (  SELECT PickSlipNo ' + CHAR(13)
                 + '                                        FROM PackHeader (NOLOCK) ' + CHAR(13)
                 + '                                        WHERE OrderKey = @c_OrderKey )) E ON  D.PickSlipNo = E.PickSlipNo ' + CHAR(13)
                 + '                                                                          AND D.CartonNo = E.CartonNo ' + CHAR(13)
                 + '                                                                          AND B.DropID = E.LabelNo ' + CHAR(13)
                 + '                                                                          AND A.StorerKey = E.StorerKey ' + CHAR(13)
                 + '         JOIN LOTATTRIBUTE (NOLOCK) G ON B.Storerkey = G.StorerKey AND B.Lot = G.Lot AND B.Sku = G.Sku ' + CHAR(13)
                 + '         JOIN SKU (NOLOCK) H ON B.Storerkey = H.StorerKey AND B.Sku = H.Sku ' + CHAR(13)
                 + '         WHERE A.OrderKey = @c_OrderKey AND G.Lottable12 = @c_HMOrder AND B.Sku LIKE @c_ArticleID ' + CHAR(13)
                 + '         GROUP BY A.OrderKey ' + CHAR(13)
                 + '                , A.OrderLineNumber ' + CHAR(13)
                 + '                , E.CartonNo ' + CHAR(13)
                 + '                , D.CartonType ' + CHAR(13)
                 + '                , E.LabelNo ' + CHAR(13)
                 + '                , B.DropID ' + CHAR(13)
                 + '                , SUBSTRING(B.Sku, 1, 7) + '' '' + SUBSTRING(B.Sku, 8, 3) ' + CHAR(13)
                 + '                , G.Lottable12 ' + CHAR(13)
                 + '                , H.Size ' + CHAR(13)
                 + '                , H.BUSR6) A ' + CHAR(13)
                 + ' PIVOT (  SUM([PackedQuantity]) ' + CHAR(13)
                 + '          FOR [Size] IN ( ' + @c_Size + ')) AS PV; '

      SET @c_SQLExecArg = N'  @c_Storerkey   NVARCHAR(15)'
                        +  ', @c_Orderkey    NVARCHAR(10)'
                        +  ', @c_HMOrder     NVARCHAR(50)'
                        +  ', @c_ArticleID   NVARCHAR(50)'

      EXEC sp_ExecuteSql @c_SQL
                       , @c_SQLExecArg
                       , @c_Storerkey
                       , @c_Orderkey
                       , @c_HMOrder 
                       , @c_ArticleID
      SELECT   Orderkey      
             , HMOrder       
             , CartonNo      
             , ArticleNumber 
             , Color         
             , CartonType    
             , HDR01         
             , CASE WHEN DET01 = 0 THEN NULL ELSE DET01 END AS DET01    
             , HDR02
             , CASE WHEN DET02 = 0 THEN NULL ELSE DET02 END AS DET02             
             , HDR03
             , CASE WHEN DET03 = 0 THEN NULL ELSE DET03 END AS DET03             
             , HDR04
             , CASE WHEN DET04 = 0 THEN NULL ELSE DET04 END AS DET04             
             , HDR05
             , CASE WHEN DET05 = 0 THEN NULL ELSE DET05 END AS DET05             
             , HDR06
             , CASE WHEN DET06 = 0 THEN NULL ELSE DET06 END AS DET06             
             , HDR07
             , CASE WHEN DET07 = 0 THEN NULL ELSE DET07 END AS DET07             
             , HDR08
             , CASE WHEN DET08 = 0 THEN NULL ELSE DET08 END AS DET08             
             , HDR09
             , CASE WHEN DET09 = 0 THEN NULL ELSE DET09 END AS DET09             
             , HDR10
             , CASE WHEN DET10 = 0 THEN NULL ELSE DET10 END AS DET10    
             , ISNULL(DET01,0) + ISNULL(DET02,0) + ISNULL(DET03,0) + ISNULL(DET04,0) + ISNULL(DET05,0) + 
               ISNULL(DET06,0) + ISNULL(DET07,0) + ISNULL(DET08,0) + ISNULL(DET09,0) + ISNULL(DET10,0) AS Total
             , TRIM(ArticleNumber) + TRIM(Color) AS Grp1
             , 1 AS NoOfCtn
      FROM #TMP_DET4
   END

   IF OBJECT_ID('tempdb..#TMP_DET3') IS NOT NULL
      DROP TABLE #TMP_DET3

   IF OBJECT_ID('tempdb..#TMP_DET3_TEMP') IS NOT NULL
      DROP TABLE #TMP_DET3_TEMP
END

GO