SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_WV_WAVPICKSUM_003                          */
/* Creation Date: 28-Oct-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21060 - JP BirkenStock BSJ DN Invoice                   */
/*                                                                      */
/* Called By: RPT_WV_WAVPICKSUM_003                                     */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 28-Oct-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 20-Jan-2023  WLChooi  1.1  WMS-21060 Show Qty per page and modify    */
/*                            page number logic, modify date (WL01)     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_WAVPICKSUM_003] 
      @c_Wavekey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @b_Success   INT
         , @n_Err       INT
         , @c_Errmsg    NVARCHAR(255)
         , @n_Count     INT

   DECLARE @c_Detail       NVARCHAR(MAX) = N''
         , @n_RowNo        INT
         , @c_SKU          NVARCHAR(20)
         , @n_Qty          INT
         , @c_PrevSku      NVARCHAR(20)
         , @c_Size         NVARCHAR(10)
         , @c_Orderkey     NVARCHAR(10)
         , @c_PrevOrderkey NVARCHAR(10)
         , @n_MaxLineno    INT = 10
         , @n_CurrentRec   INT    
         , @n_MaxRec       INT 
         , @c_Storerkey    NVARCHAR(15)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''

   DECLARE @TMP_ORDER AS TABLE
   (
      Orderkey  NVARCHAR(10)
   )

   INSERT INTO @TMP_ORDER
   SELECT DISTINCT WD.Orderkey
   FROM WAVEDETAIL WD (NOLOCK)
   WHERE WD.WaveKey = @c_Wavekey

   DECLARE @TMP_SKU AS TABLE
   (
      RowNo     INT NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Orderkey  NVARCHAR(10)
    , SKU       NVARCHAR(20)
    , Storerkey NVARCHAR(15)
    , Qty       INT
    , UnitPrice FLOAT
    , Size      NVARCHAR(50)
   )

   DECLARE @TMP_DETAIL AS TABLE
   (
      ID     INT NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , DETAIL NVARCHAR(MAX)
   )

   DECLARE @TMP_SKUSize AS TABLE
   (
      ID          INT NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Storerkey   NVARCHAR(15)
    , Orderkey    NVARCHAR(10)
    , SKU         NVARCHAR(20)
    , Size1       NVARCHAR(20)
    , Qty1        INT
    , Size2       NVARCHAR(20)
    , Qty2        INT
    , Size3       NVARCHAR(20)
    , Qty3        INT
    , Size4       NVARCHAR(20)
    , Qty4        INT
   )

   DECLARE @TMP_TTLUnitPrice AS TABLE
   (
      ID       INT NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Orderkey NVARCHAR(10)
    , ExtPrice FLOAT
   )
   DECLARE @TMP_RESULT AS TABLE
   (
      DeliveryDate      NVARCHAR(11)
    , MarkforKey        NVARCHAR(15)
    , M_Contact1        NVARCHAR(100)
    , ExternOrderKey    NVARCHAR(50)
    , BillToKey         NVARCHAR(100)
    , B_Contact1        NVARCHAR(500)
    , B_Contact2        NVARCHAR(500)
    , BuyerPO           NVARCHAR(20)
    , Orderkey          NVARCHAR(10)
    , Zip               NVARCHAR(100)
    , Addresses         NVARCHAR(500)
    , Address2          NVARCHAR(100)
    , Company           NVARCHAR(100)
    , DESCR             NVARCHAR(60)
    , Notes             NVARCHAR(4000)
    , SKU               NVARCHAR(20)
    , Size1             NVARCHAR(20)
    , Qty1              INT
    , Size2             NVARCHAR(20)
    , Qty2              INT
    , Size3             NVARCHAR(20)
    , Qty3              INT
    , Size4             NVARCHAR(20)
    , Qty4              INT
    , SumQty            INT
    , UnitPrice         FLOAT
    , ExtendedPrice     FLOAT
    , TTLUnitPrice      FLOAT
    , Today             NVARCHAR(11)
    , TTLSumUnitPrice   FLOAT
    , DummyLine         NVARCHAR(1)
    , Loadkey           NVARCHAR(10)   --WL01
   )

   INSERT INTO @TMP_SKU
   SELECT PICKDETAIL.OrderKey
        , S.Style   --ORDERDETAIL.Sku
        , S.StorerKey
        , SUM(PICKDETAIL.Qty) AS Qty   --SUM(ORDERDETAIL.OriginalQty) AS Qty
        , (  SELECT TOP 1 ISNULL(OD.UnitPrice, 0.00)
             FROM ORDERDETAIL OD (NOLOCK)
             JOIN SKU (NOLOCK) ON SKU.StorerKey = OD.StorerKey 
                              AND SKU.SKU = OD.SKU
             WHERE OD.OrderKey = PICKDETAIL.OrderKey
             AND   SKU.StorerKey = S.StorerKey
             AND   SKU.Style = S.Style) AS UnitPrice
        , TRIM(ISNULL(CL.Code,'')) + ' (' + TRIM(ISNULL(S.Size,'')) + ') ' AS Size
   FROM PICKDETAIL (NOLOCK)
   JOIN @TMP_ORDER TOR ON TOR.Orderkey = PICKDETAIL.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = PICKDETAIL.StorerKey AND S.SKU = PICKDETAIL.SKU
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'BSSize' AND CL.Storerkey = S.StorerKey 
                                      AND CL.code2 = S.Size
   GROUP BY PICKDETAIL.OrderKey
          , S.Style   --ORDERDETAIL.Sku
          , S.StorerKey
          , TRIM(ISNULL(CL.Code,'')) + ' (' + TRIM(ISNULL(S.Size,'')) + ') '
   ORDER BY PICKDETAIL.OrderKey
          , S.Style   --ORDERDETAIL.Sku

   SELECT TOP 1 @c_Storerkey = TS.Storerkey
   FROM @TMP_SKU TS

   INSERT INTO @TMP_TTLUnitPrice
   SELECT TS.Orderkey
        , SUM(TS.Qty * TS.UnitPrice)
   FROM @TMP_SKU TS
   GROUP BY TS.Orderkey

   --SELECT *
   --FROM @TMP_TTLUnitPrice

   WHILE EXISTS (  SELECT 1
                   FROM @TMP_SKU TR)
   BEGIN
      SET @c_Detail = N''
      SET @c_PrevSku = N''

      DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 4 RowNo
                 , Orderkey
                 , SKU   --LEFT(SKU, 9)
                 , Size   --SUBSTRING(TRIM(SKU), CHARINDEX('-', TRIM(SKU)) + 1, 3)
                 , Qty
      FROM @TMP_SKU TSKU
      ORDER BY RowNo

      OPEN CUR_SPLIT

      FETCH NEXT FROM CUR_SPLIT
      INTO @n_RowNo
         , @c_Orderkey
         , @c_SKU
         , @c_Size
         , @n_Qty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --SELECT @n_RowNo, @c_Sku, @c_Size, @n_Qty
         IF (@c_PrevSku = @c_SKU AND @c_PrevOrderkey = @c_Orderkey) OR @c_PrevSku = ''
         BEGIN
            SELECT @c_Detail = @c_Detail 
                             + CASE WHEN @c_Detail = '' THEN @c_Storerkey + CHAR(13) + @c_Orderkey + CHAR(13) ELSE '' END 
                             + CASE WHEN @c_Detail = '' THEN @c_SKU + CHAR(13) ELSE '' END 
                             + @c_Size + CHAR(13) 
                             + CAST(@n_Qty AS NVARCHAR) + CHAR(13)

            DELETE FROM @TMP_SKU
            WHERE RowNo = @n_RowNo

            SET @c_PrevOrderkey = @c_Orderkey
            SET @c_PrevSku = @c_SKU
         END

         FETCH NEXT FROM CUR_SPLIT
         INTO @n_RowNo
            , @c_Orderkey
            , @c_SKU
            , @c_Size
            , @n_Qty
      END
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT

      INSERT INTO @TMP_DETAIL (DETAIL)
      SELECT @c_Detail
   END

   --SELECT *
   --FROM @TMP_DETAIL
   ;
   WITH SplitValues (ID, OriginalValue, SplitValue, Level) AS
   (
      SELECT ID
           , DETAIL
           , CAST('' AS NVARCHAR(MAX))
           , 0
      FROM @TMP_DETAIL
      UNION ALL
      SELECT ID
           , SUBSTRING(OriginalValue
                     , CASE WHEN CHARINDEX(CHAR(13), OriginalValue) = 0 THEN LEN(OriginalValue) + 1
                            ELSE CHARINDEX(CHAR(13), OriginalValue) + 1 END
                     , LEN(OriginalValue))
           , SUBSTRING(OriginalValue
                     , 0
                     , CASE WHEN CHARINDEX(CHAR(13), OriginalValue) = 0 THEN LEN(OriginalValue) + 1
                            ELSE CHARINDEX(CHAR(13), OriginalValue)END)
           , Level + 1
      FROM SplitValues
      WHERE LEN(SplitValues.OriginalValue) > 0
   )
   INSERT INTO @TMP_SKUSize
   SELECT [1]  AS [Storerkey]
        , [2]  AS [Orderkey]
        , [3]  AS [SKU]
        , [4]  AS [Size1]
        , [5]  AS [Qty1]
        , [6]  AS [Size2]
        , [7]  AS [Qty2]
        , [8]  AS [Size3]
        , [9]  AS [Qty3]
        , [10] AS [Size4]
        , [11] AS [Qty4]
   FROM (  SELECT ID
                , Level
                , SplitValue
           FROM SplitValues
           WHERE Level > 0) AS p
   PIVOT (  MAX(SplitValue)
            FOR Level IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11])) AS PVT
   ORDER BY ID
   OPTION (MAXRECURSION 0)

   --SELECT *
   --FROM @TMP_SKUSize

   INSERT INTO @TMP_RESULT
   SELECT CAST(DATEPART(YEAR, OH.DeliveryDate) AS NVARCHAR(4)) + N'å¹´'
          + CAST(DATEPART(MONTH, OH.DeliveryDate) AS NVARCHAR(2)) + N'æœˆ'
          + CAST(DATEPART(DAY, OH.DeliveryDate) AS NVARCHAR(2)) + N'æ—¥' AS DeliveryDate
        , OH.MarkforKey
        , OH.M_Contact1
        , OH.ExternOrderKey
        , TRIM(OH.BillToKey) AS BillToKey
        , ISNULL(TRIM(OH.B_Contact1),'') AS B_Contact1
        , ISNULL(TRIM(OH.B_Contact2),'') AS B_Contact2
        , OH.BuyerPO
        , OH.OrderKey
        , N'ã€’' + TRIM(ISNULL(ST.Zip,''))
        , TRIM(ISNULL(ST.[State],'')) + TRIM(ISNULL(ST.City,'')) + TRIM(ISNULL(ST.Address1,''))
        , TRIM(ISNULL(ST.Address2,''))
        , TRIM(ISNULL(ST.Company,''))
        , ODT.DESCR
        , CASE WHEN CHARINDEX('|', TRIM(ISNULL(OH.Notes, ''))) > 0
               THEN SUBSTRING(TRIM(ISNULL(OH.Notes, '')), CHARINDEX('|',TRIM(ISNULL(OH.Notes, ''))) + 1,  
                              LEN(TRIM(ISNULL(TRIM(ISNULL(OH.Notes, '')), ''))) - 
                              CHARINDEX('|', TRIM(ISNULL(OH.Notes, ''))))
               ELSE TRIM(ISNULL(OH.Notes, '')) END AS Notes
        , TSS.SKU
        , TSS.Size1
        , TSS.Qty1
        , TSS.Size2
        , TSS.Qty2
        , TSS.Size3
        , TSS.Qty3
        , TSS.Size4
        , TSS.Qty4
        , ISNULL(TSS.Qty1, 0) + ISNULL(TSS.Qty2, 0) + ISNULL(TSS.Qty3, 0) + ISNULL(TSS.Qty4, 0) AS SumQty
        , ODT.UnitPrice AS UnitPrice
        , ODT.ExtendedPrice
        , ODT.UnitPrice * (ISNULL(TSS.Qty1, 0) + ISNULL(TSS.Qty2, 0) + ISNULL(TSS.Qty3, 0) + ISNULL(TSS.Qty4, 0)) AS TTLUnitPrice
        , CASE WHEN ISNULL(OIF.OrderInfo01,'') = ''                                            --WL01
               THEN CAST(DATEPART(YEAR, GETDATE()) AS NVARCHAR(4)) + N'å¹´'                     --WL01
                  + CAST(DATEPART(MONTH, GETDATE()) AS NVARCHAR(2)) + N'æœˆ'                    --WL01
                  + CAST(DATEPART(DAY, GETDATE()) AS NVARCHAR(2)) + N'æ—¥'                      --WL01
               ELSE CAST(DATEPART(YEAR, OIF.OrderInfo01) AS NVARCHAR(4)) + N'å¹´'               --WL01
                  + CAST(DATEPART(MONTH, OIF.OrderInfo01) AS NVARCHAR(2)) + N'æœˆ'              --WL01
                  + CAST(DATEPART(DAY, OIF.OrderInfo01) AS NVARCHAR(2)) + N'æ—¥' END AS Today   --WL01
        , TTEP.ExtPrice AS TTLSumUnitPrice
        , 'N' AS DummyLine
        , OH.LoadKey   --WL01
   FROM @TMP_ORDER TOD
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = TOD.Orderkey
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN @TMP_SKUSize TSS ON TSS.Orderkey = OH.OrderKey
   JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey
   CROSS APPLY (  SELECT TOP 1 O.UnitPrice
                             , O.ExtendedPrice
                             , SKU.DESCR
                  FROM ORDERDETAIL O WITH (NOLOCK)
                  JOIN SKU WITH (NOLOCK) ON O.StorerKey = SKU.StorerKey AND O.SKU = SKU.SKU
                  WHERE O.OrderKey = TSS.OrderKey 
                  AND SKU.Style = TSS.SKU
                  AND SKU.StorerKey = TSS.StorerKey) AS ODT
   CROSS APPLY (  SELECT SUM(ExtPrice) AS ExtPrice
                  FROM @TMP_TTLUnitPrice 
                  WHERE Orderkey = OH.OrderKey) AS TTEP
   OUTER APPLY (  SELECT TOP 1 ISNULL(OI.OrderInfo01,'') AS OrderInfo01   --WL01
                  FROM ORDERINFO OI (NOLOCK)                              --WL01
                  WHERE OI.OrderKey = OH.OrderKey) AS OIF                 --WL01
   GROUP BY OH.DeliveryDate
          , OH.MarkforKey
          , OH.M_Contact1
          , OH.ExternOrderKey
          , TRIM(OH.BillToKey)
          , ISNULL(TRIM(OH.B_Contact1),'')
          , ISNULL(TRIM(OH.B_Contact2),'')
          , OH.BuyerPO
          , OH.OrderKey
          , N'ã€’' + TRIM(ISNULL(ST.Zip,''))
          , TRIM(ISNULL(ST.[State],'')) + TRIM(ISNULL(ST.City,'')) + TRIM(ISNULL(ST.Address1,''))
          , TRIM(ISNULL(ST.Address2,''))
          , TRIM(ISNULL(ST.Company,''))
          , ODT.DESCR
          , CASE WHEN CHARINDEX('|', TRIM(ISNULL(OH.Notes, ''))) > 0
               THEN SUBSTRING(TRIM(ISNULL(OH.Notes, '')), CHARINDEX('|',TRIM(ISNULL(OH.Notes, ''))) + 1,  
                              LEN(TRIM(ISNULL(TRIM(ISNULL(OH.Notes, '')), ''))) - 
                              CHARINDEX('|', TRIM(ISNULL(OH.Notes, ''))))
               ELSE TRIM(ISNULL(OH.Notes, '')) END
          , TSS.SKU
          , TSS.Size1
          , TSS.Qty1
          , TSS.Size2
          , TSS.Qty2
          , TSS.Size3
          , TSS.Qty3
          , TSS.Size4
          , TSS.Qty4
          , ODT.UnitPrice
          , ODT.ExtendedPrice
          , TTEP.ExtPrice
          , OH.LoadKey   --WL01
          , OIF.OrderInfo01   --WL01
   --ORDER BY OH.OrderKey

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TR.Orderkey, COUNT(1)
   FROM @TMP_RESULT TR
   GROUP BY TR.Orderkey
   ORDER BY TR.Orderkey

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @n_MaxRec

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno 

      WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)             
      BEGIN
         INSERT INTO @TMP_RESULT (DeliveryDate, MarkforKey, M_Contact1, ExternOrderKey, BillToKey, B_Contact1, B_Contact2, BuyerPO
                                , Orderkey, Zip, Addresses, Address2, Company, DESCR, Notes, SKU, Size1, Qty1, Size2
                                , Qty2, Size3, Qty3, Size4, Qty4, SumQty, UnitPrice, ExtendedPrice, TTLUnitPrice
                                , Today, TTLSumUnitPrice, DummyLine, Loadkey)   --WL01
         SELECT TOP 1 DeliveryDate, MarkforKey, M_Contact1, ExternOrderKey, BillToKey, B_Contact1, B_Contact2, BuyerPO
                    , Orderkey, Zip, Addresses, Address2, Company, NULL, Notes, NULL, NULL, NULL, NULL
                    , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                    , Today, TTLSumUnitPrice, 'Y', Loadkey   --WL01
         FROM @TMP_RESULT TR
         WHERE Orderkey = @c_Orderkey

         SET @n_CurrentRec = @n_CurrentRec + 1  
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @n_MaxRec
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   --WL01 S
   ;WITH FINAL_CTE AS (
   SELECT DeliveryDate, MarkforKey, M_Contact1, ExternOrderKey, BillToKey, B_Contact2, BuyerPO
        , Orderkey, Zip, Addresses, Address2, Company, DESCR, Notes, SKU, Size1, Qty1, Size2
        , Qty2, Size3, Qty3, Size4, Qty4, SumQty, UnitPrice, ExtendedPrice, TTLUnitPrice
        , Today, TTLSumUnitPrice, DummyLine, B_Contact1
        , Loadkey
        , (Row_Number() OVER (PARTITION BY TR.Loadkey ORDER BY TR.Loadkey, TR.Orderkey, TR.DummyLine, TR.SKU, TR.Size1 ASC) - 1 ) / @n_MaxLineno + 1 AS PageNo
   FROM @TMP_RESULT TR)
   SELECT DeliveryDate, MarkforKey, M_Contact1, ExternOrderKey, BillToKey, B_Contact2, BuyerPO
        , Orderkey, Zip, Addresses, Address2, Company, DESCR, Notes, SKU, Size1, Qty1, Size2
        , Qty2, Size3, Qty3, Size4, Qty4, SumQty, UnitPrice, ExtendedPrice, TTLUnitPrice
        , Today, TTLSumUnitPrice, DummyLine, B_Contact1
        , Loadkey
        , CAST(PageNo AS NVARCHAR) + ' / ' + CAST((SELECT MAX(PageNo) FROM FINAL_CTE C WHERE C.Loadkey = CTE.Loadkey) AS NVARCHAR) AS PageNo
        , (SELECT SUM(SumQty) FROM FINAL_CTE CT WHERE CT.Loadkey = CTE.Loadkey AND CT.Orderkey = CTE.Orderkey 
           AND CT.PageNo = CTE.PageNo) AS SumQtyPerPage
        , (SELECT SUM(TTLUnitPrice) FROM FINAL_CTE CT WHERE CT.Loadkey = CTE.Loadkey AND CT.Orderkey = CTE.Orderkey 
           AND CT.PageNo = CTE.PageNo) AS SumTTLUnitPrice
   FROM FINAL_CTE CTE
   ORDER BY CTE.Loadkey, CTE.Orderkey, CTE.DummyLine, CTE.SKU, CTE.Size1
   --WL01 E

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT') IN (0 , 1)
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   
END -- procedure

GO