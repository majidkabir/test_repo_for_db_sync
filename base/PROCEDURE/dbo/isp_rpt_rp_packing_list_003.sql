SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_RP_PACKING_LIST_003                           */
/* Creation Date: 23-Aug-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-23493 - [CN] NAOS Jreport_Packinglist_CR                   */
/*          Copy and modify from isp_packing_list_68_rpt                   */
/*                                                                         */
/* Called By: RPT_RP_PACKING_LIST_003                                      */
/*                                                                         */
/* GitHub Version: 1.1                                                     */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 23-Aug-2023  WLChooi 1.0   DevOps Combine Script                        */
/* 28-Aug-2023  WLChooi 1.1   WMS-23493 - Change default column title(WL01)*/
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_PACKING_LIST_003]
(@c_Orderkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue    INT
         , @c_BuyerPO     NVARCHAR(50)
         , @c_SKU         NVARCHAR(20)
         , @c_Sdescr      NVARCHAR(120)
         , @n_PQTY        INT
         , @n_Casecnt     FLOAT
         , @c_FullCTN     INT
         , @n_LooseQty    INT
         , @n_CTN         INT
         , @n_startcnt    INT
         , @n_Packqty     INT
         , @c_Storerkey   NVARCHAR(20)
         , @c_Title_1     NVARCHAR(50)
         , @c_Title_2     NVARCHAR(50)
         , @c_Title_3     NVARCHAR(50)
         , @c_Title_4     NVARCHAR(50)
         , @c_Title_5     NVARCHAR(50)
         , @c_Title       NVARCHAR(500) = ''

   CREATE TABLE #TempPackList003
   (
      OrderKey       NVARCHAR(10)  NULL
    , SKU            NVARCHAR(20)  NULL
    , SDESCR         NVARCHAR(120) NULL
    , PackQty        INT
    , CTNNo          INT
    , BuyerPO        NVARCHAR(50)  NULL
   )

   SET @n_startcnt = 1

   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.OrderKey = @c_Orderkey

   SELECT @c_Title = ISNULL(CL.Notes,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Code = 'CustomColTitle'
   AND CL.Long = 'RPT_RP_PACKING_LIST_003'

   IF ISNULL(@c_Title,'') = ''
      SET @c_Title = 'Carton No|Sephora PO No.|Item Code|Description|QTY'   --WL01

   SELECT @c_Title_1 = ISNULL(MAX(CASE WHEN SeqNo = 1 THEN ColValue ELSE '' END), 0)
        , @c_Title_2 = ISNULL(MAX(CASE WHEN SeqNo = 2 THEN ColValue ELSE '' END), 0)
        , @c_Title_3 = ISNULL(MAX(CASE WHEN SeqNo = 3 THEN ColValue ELSE '' END), 0)
        , @c_Title_4 = ISNULL(MAX(CASE WHEN SeqNo = 4 THEN ColValue ELSE '' END), 0)
        , @c_Title_5 = ISNULL(MAX(CASE WHEN SeqNo = 5 THEN ColValue ELSE '' END), 0)
   FROM dbo.fnc_DelimSplit('|', @c_Title) FDS

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ORD.BuyerPO
                 , PD.Sku
                 , S.DESCR
                 , SUM(PD.Qty)
                 , P.CaseCnt
                 , FLOOR(SUM(PD.Qty) / P.CaseCnt) AS CTN
                 , (SUM(PD.Qty) % CAST(P.CaseCnt AS INT)) AS LooseQty
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PD.OrderKey
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
   JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
   WHERE PD.Storerkey = @c_Storerkey AND PD.OrderKey = @c_Orderkey
   GROUP BY ORD.BuyerPO
          , PD.Sku
          , S.DESCR
          , P.CaseCnt
   ORDER BY PD.Sku

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT
   INTO @c_BuyerPO
      , @c_SKU
      , @c_Sdescr
      , @n_PQTY
      , @n_Casecnt
      , @c_FullCTN
      , @n_LooseQty

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Packqty = 1

      IF @n_startcnt = 1
      BEGIN
         IF @c_FullCTN = 0
         BEGIN
            IF @n_LooseQty <> 0
            BEGIN
               SET @n_Packqty = @n_LooseQty
            END
            ELSE
            BEGIN
               SET @n_Packqty = @n_Casecnt
            END
            INSERT INTO #TempPackList003 (OrderKey, BuyerPO, SKU, SDESCR, PackQty, CTNNo)
            VALUES (@c_Orderkey, @c_BuyerPO, @c_SKU, @c_Sdescr, @n_Packqty, @n_startcnt)

            SET @n_startcnt = @n_startcnt + 1

         END --@c_FullCTN = 0
         ELSE
         BEGIN
            WHILE @c_FullCTN > 0
            BEGIN
               SET @n_Packqty = @n_Casecnt

               INSERT INTO #TempPackList003 (OrderKey, BuyerPO, SKU, SDESCR, PackQty, CTNNo)
               VALUES (@c_Orderkey, @c_BuyerPO, @c_SKU, @c_Sdescr, @n_Packqty, @n_startcnt)

               SET @n_startcnt = @n_startcnt + 1
               SET @c_FullCTN = @c_FullCTN - 1
            END

            IF @c_FullCTN = 0 AND @n_LooseQty <> 0
            BEGIN
               SET @n_Packqty = @n_LooseQty
               INSERT INTO #TempPackList003 (OrderKey, BuyerPO, SKU, SDESCR, PackQty, CTNNo)
               VALUES (@c_Orderkey, @c_BuyerPO, @c_SKU, @c_Sdescr, @n_Packqty, @n_startcnt)

               SET @n_startcnt = @n_startcnt + 1
            END
         END --@c_FullCTN <> 0
      END --@n_startcnt = 1
      ELSE
      BEGIN

         IF @c_FullCTN = 0
         BEGIN
            IF @n_LooseQty <> 0
            BEGIN
               SET @n_Packqty = @n_LooseQty
            END
            ELSE
            BEGIN
               SET @n_Packqty = @n_Casecnt
            END
            INSERT INTO #TempPackList003 (OrderKey, BuyerPO, SKU, SDESCR, PackQty, CTNNo)
            VALUES (@c_Orderkey, @c_BuyerPO, @c_SKU, @c_Sdescr, @n_Packqty, @n_startcnt)

            SET @n_startcnt = @n_startcnt + 1

         END --@c_FullCTN = 0
         ELSE
         BEGIN
            WHILE @c_FullCTN > 0
            BEGIN
               SET @n_Packqty = @n_Casecnt

               INSERT INTO #TempPackList003 (OrderKey, BuyerPO, SKU, SDESCR, PackQty, CTNNo)
               VALUES (@c_Orderkey, @c_BuyerPO, @c_SKU, @c_Sdescr, @n_Packqty, @n_startcnt)

               SET @n_startcnt = @n_startcnt + 1
               SET @c_FullCTN = @c_FullCTN - 1
            END

            IF @c_FullCTN = 0 AND @n_LooseQty <> 0
            BEGIN
               SET @n_Packqty = @n_LooseQty
               INSERT INTO #TempPackList003 (OrderKey, BuyerPO, SKU, SDESCR, PackQty, CTNNo)
               VALUES (@c_Orderkey, @c_BuyerPO, @c_SKU, @c_Sdescr, @n_Packqty, @n_startcnt)

               SET @n_startcnt = @n_startcnt + 1
            END
         END --@c_FullCTN <> 0
      END

      FETCH NEXT FROM CUR_RESULT
      INTO @c_BuyerPO
         , @c_SKU
         , @c_Sdescr
         , @n_PQTY
         , @n_Casecnt
         , @c_FullCTN
         , @n_LooseQty
   END
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT

   SELECT OrderKey
        , SKU
        , SDESCR
        , PackQty
        , CTNNo
        , BuyerPO
        , Group1 = TRIM(ISNULL(Orderkey,'')) + TRIM(ISNULL(SKU,''))
                 + TRIM(ISNULL(SDESCR,'')) + CAST(ISNULL(PackQty,0) AS NVARCHAR)
                 + CAST(ISNULL(CTNNo,0) AS NVARCHAR)  + TRIM(ISNULL(BuyerPO,''))
        , @c_Title_1 AS Title_1
        , @c_Title_2 AS Title_2
        , @c_Title_3 AS Title_3
        , @c_Title_4 AS Title_4
        , @c_Title_5 AS Title_5
   FROM #TempPackList003
   WHERE OrderKey = @c_Orderkey
   ORDER BY SKU
          , CTNNo
   
   IF OBJECT_ID('tempdb..#TempPackList003') IS NOT NULL
      DROP TABLE #TempPackList003
END

GO