SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_stocktake_report_01c                       */
/* Creation Date: 03-Sep-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: L'Oreal Stocktake Variance Report                            */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_stocktake_report_01c        */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 21/11/2019   ML       1.1  Add Variance Filter 3=SKUxLOCxID           */
/* 20/11/2019   ML       1.2  Remove DMQA Zone Filter                    */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_stocktake_report_01c] (
       @as_storerkey       NVARCHAR(15)
     , @as_cckey           NVARCHAR(10)
     , @as_countno         NVARCHAR(50)
     , @as_facility        NVARCHAR(4000) = ''
     , @as_sku             NVARCHAR(4000) = ''
     , @as_withqty         NVARCHAR(10) = ''
     , @as_dmqazone        NVARCHAR(10) = ''
     , @as_expect_dmqazone NVARCHAR(10) = ''
     , @as_var_filter      NVARCHAR(10) = ''     -- 1=SKU, 2=SKUxLOC, 3=SKUxLOCxID
     , @as_cntsht_bysku    NVARCHAR(10) = ''
     , @as_expect_bysku    NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_DataWindow       NVARCHAR(40)
         , @c_Storerkey        NVARCHAR(15)
         , @c_DMQA_Facility    NVARCHAR(5)
         , @c_DMQA_Zones       NVARCHAR(MAX)
         , @c_ErrMsg           NVARCHAR(250)
         , @c_CountDesc        NVARCHAR(50)

   SET @c_DataWindow   = 'r_hk_stocktake_report_01'

   IF OBJECT_ID('tempdb..#TEMP_CCDETAIL') IS NOT NULL
      DROP TABLE #TEMP_CCDETAIL
   IF OBJECT_ID('tempdb..#TEMP_CCDETAIL2') IS NOT NULL
      DROP TABLE #TEMP_CCDETAIL2
   IF OBJECT_ID('tempdb..#TEMP_CONTROLSHEET') IS NOT NULL
      DROP TABLE #TEMP_CONTROLSHEET

   SET @c_CountDesc = LTRIM(RTRIM(SUBSTRING(@as_countno, 2, LEN(@as_countno))))
   SET @as_countno  = LEFT(@as_countno, 1)

   IF ISNULL(@as_countno,'') = ''
   BEGIN
     SELECT @as_countno = CASE WHEN PopulateStage >= 2 THEN PopulateStage ELSE 1 END
       FROM dbo.StockTakeSheetParameters (NOLOCK)
      WHERE StockTakeKey = @as_cckey
   END


   SELECT Storerkey           = ISNULL( RTRIM( CC.Storerkey ), '' )
        , Facility            = ISNULL( RTRIM( LOC.Facility ), '' )
        , CCKey               = ISNULL( RTRIM( CC.CCKey ), '' )
        , CCSheetNo           = ISNULL( RTRIM( CC.CCSheetNo ), '' )
        , CCDetailKey         = ISNULL( RTRIM( CC.CCDetailKey ), '' )
        , PutawayZone         = ISNULL( RTRIM( LOC.PutawayZone ), '' )
        , [Floor]             = ISNULL( RTRIM( LOC.[Floor] )+IIF(TRY_PARSE(ISNULL(LOC.[Floor],'') AS INT) IS NOT NULL, '/F', ''), '' )
        , Loc                 = ISNULL( RTRIM( CC.Loc ), '' )
        , Sku                 = ISNULL( RTRIM( CC.Sku ), '' )
        , SystemQty           = ISNULL( CC.SystemQty, 0 )
        , Qty                 = ISNULL( CC.Qty      , 0 )
        , Qty_Cnt2            = ISNULL( CC.Qty_Cnt2 , 0 )
        , Qty_Cnt3            = ISNULL( CC.Qty_Cnt3 , 0 )
        , ID                  = ISNULL( RTRIM( CC.ID ), '' )
        , Lottable01          = ISNULL( RTRIM( CC.Lottable01 ), '' )
        , Lottable02          = ISNULL( RTRIM( CC.Lottable02 ), '' )
        , Lottable03          = ISNULL( RTRIM( CC.Lottable03 ), '' )
        , Lottable04          = CC.Lottable04
        , Lottable01_Cnt2     = ISNULL( RTRIM( CC.Lottable01_Cnt2 ), '' )
        , Lottable02_Cnt2     = ISNULL( RTRIM( CC.Lottable02_Cnt2 ), '' )
        , Lottable03_Cnt2     = ISNULL( RTRIM( CC.Lottable03_Cnt2 ), '' )
        , Lottable04_Cnt2     = CC.Lottable04_Cnt2
        , Lottable01_Cnt3     = ISNULL( RTRIM( CC.Lottable01_Cnt3 ), '' )
        , Lottable02_Cnt3     = ISNULL( RTRIM( CC.Lottable02_Cnt3 ), '' )
        , Lottable03_Cnt3     = ISNULL( RTRIM( CC.Lottable03_Cnt3 ), '' )
        , Lottable04_Cnt3     = CC.Lottable04_Cnt3
        , CCLogicalLoc        = LOC.CCLogicalLoc
        , SeqNo               = ROW_NUMBER() OVER(PARTITION BY CC.CCKey, CC.CCSheetNo ORDER BY CC.CCDetailKey)
   INTO #TEMP_CCDETAIL
   FROM dbo.StockTakeSheetParameters STP(NOLOCK)
   JOIN dbo.CCDETAIL  CC(NOLOCK) ON STP.StockTakeKey=CC.CCKey
   LEFT JOIN dbo.LOC LOC(NOLOCK) ON (CC.Loc=LOC.Loc)
   WHERE CC.Storerkey = @as_storerkey
     AND CC.CCKey = @as_cckey
     AND @as_countno IN ('1', '2', '3')
     AND @as_countno <= STP.FinalizeStage+1
     AND ( ISNULL(@as_facility,'')='' OR LOC.Facility IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',',replace(@as_facility,char(13)+char(10),',')) WHERE ColValue<>'') )
     AND ( ISNULL(@as_sku,'')='' OR CC.Sku IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',',replace(@as_sku,char(13)+char(10),',')) WHERE ColValue<>'') )
--     AND IIF(ISNULL(@as_dmqazone,'')='Y','Y','N') = IIF(ISNULL(@as_expect_dmqazone,'')='Y','Y','N')
     AND @as_var_filter IN ('1', '2', '3')
     AND ( IIF(ISNULL(@as_cntsht_bysku,'')='','N',@as_cntsht_bysku) = IIF(ISNULL(@as_expect_bysku,'')='','N',@as_expect_bysku) )



   -- Storerkey Loop
/*
   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_CCDETAIL
    WHERE Storerkey<>''
    ORDER BY 1

   OPEN C_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_DMQA_Facility = ''
           , @c_DMQA_Zones    = ''

      SELECT TOP 1
             @c_DMQA_Facility = ISNULL((select top 1 LTRIM(RTRIM(b.ColValue))
                                from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                where a.SeqNo=b.SeqNo and a.ColValue='DMQA_Facility'), '')
           , @c_DMQA_Zones    = ISNULL((select top 1 LTRIM(RTRIM(b.ColValue))
                                from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                where a.SeqNo=b.SeqNo and a.ColValue='DMQA_Zone'), '')
      FROM dbo.CodeLkup (NOLOCK)
      WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y' AND Storerkey = @c_Storerkey
      ORDER BY Code2

      IF ISNULL(@as_dmqazone,'')='Y'
      BEGIN
         DELETE FROM #TEMP_CCDETAIL
          WHERE Storerkey = @c_Storerkey
            AND NOT (Facility = @c_DMQA_Facility
                 AND PutawayZone IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(LEFT(@c_DMQA_Zones,1),SUBSTRING(@c_DMQA_Zones,2,LEN(@c_DMQA_Zones))) WHERE ColValue<>'') )
      END
      ELSE
      BEGIN
         DELETE FROM #TEMP_CCDETAIL
          WHERE Storerkey = @c_Storerkey
            AND (Facility = @c_DMQA_Facility
                 AND PutawayZone IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(LEFT(@c_DMQA_Zones,1),SUBSTRING(@c_DMQA_Zones,2,LEN(@c_DMQA_Zones))) WHERE ColValue<>'') )
      END
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY
*/


   SELECT Z.*
        , PageNo = SUM( IIF((SeqNo-1)%15=0, 1, 0) ) OVER(ORDER BY CCKey, CCSheetNo, CCDetailKey)
   INTO #TEMP_CCDETAIL2
   FROM (
      SELECT Y.*
           , SeqNo = ROW_NUMBER() OVER(PARTITION BY CCKey, CCSheetNo ORDER BY CCDetailKey)
      FROM (
         SELECT X.*
              , Cnt2_Filter_SKU        = IIF(X.WMS_Qty_by_SKU         <> X.Cnt1_Qty_by_SKU       , 'Y', '')
              , Cnt2_Filter_SKUxLOC    = IIF(X.WMS_Qty_by_SKUxLOC     <> X.Cnt1_Qty_by_SKUxLOC   , 'Y', '')
              , Cnt2_Filter_SKUxLOCxID = IIF(X.WMS_Qty_by_SKUxLOCxID  <> X.Cnt1_Qty_by_SKUxLOCxID, 'Y', '')
              , Cnt3_Filter_SKU        = IIF(X.Cnt1_Qty_by_SKU        <> X.Cnt2_Qty_by_SKU        AND X.WMS_Qty_by_SKU        <> X.Cnt2_Qty_by_SKU       , 'Y', '')
              , Cnt3_Filter_SKUxLOC    = IIF(X.Cnt1_Qty_by_SKUxLOC    <> X.Cnt2_Qty_by_SKUxLOC    AND X.WMS_Qty_by_SKUxLOC    <> X.Cnt2_Qty_by_SKUxLOC   , 'Y', '')
              , Cnt3_Filter_SKUxLOCxID = IIF(X.Cnt1_Qty_by_SKUxLOCxID <> X.Cnt2_Qty_by_SKUxLOCxID AND X.WMS_Qty_by_SKUxLOCxID <> X.Cnt2_Qty_by_SKUxLOCxID, 'Y', '')
              , FinalAdj_Filter        = IIF(X.WMS_Qty <> Cnt3_Qty, 'Y', 'N')
              , CountNo                = UPPER( ISNULL( @as_countno, '' ) )
              , CountDesc              = ISNULL( @c_CountDesc,'' )
              , WithQty                = UPPER( ISNULL( @as_withqty, '' ) )
         FROM (
            SELECT Storerkey              = CC.Storerkey
                 , Company                = ISNULL( RTRIM( ST.Company ), '' )
                 , Facility               = CC.Facility
                 , CCKey                  = CC.CCKey
                 , CCSheetNo              = CC.CCSheetNo
                 , CCDetailKey            = CC.CCDetailKey
                 , PutawayZone            = CC.PutawayZone
                 , [Floor]                = CC.[Floor]
                 , Loc                    = CC.Loc
                 , Div                    = ISNULL( RTRIM( BRD.Long ), '' )
                 , Brand                  = ISNULL( RTRIM( CAST( BRD.Notes AS NVARCHAR(50) ) ), '' )
                 , ProductType            = ISNULL( RTRIM( SKU.BUSR10 ), '' )
                 , Sku                    = CC.Sku
                 , DESCR                  = ISNULL( RTRIM( SKU.DESCR ), '' )
                 , UPC                    = ISNULL( RTRIM( SKU.ALTSKU ), '' )
                 , WMS_Qty                = CC.SystemQty
                 , Cnt1_Qty               = CC.Qty
                 , Cnt2_Qty               = CC.Qty_Cnt2
                 , Cnt3_Qty               = CC.Qty_Cnt3
                 , ID                     = CC.ID
                 , Lottable01             = CC.Lottable01
                 , Lottable02             = CC.Lottable02
                 , Lottable03             = CC.Lottable03
                 , Lottable04             = CC.Lottable04
                 , Lottable01_Cnt2        = CC.Lottable01_Cnt2
                 , Lottable02_Cnt2        = CC.Lottable02_Cnt2
                 , Lottable03_Cnt2        = CC.Lottable03_Cnt2
                 , Lottable04_Cnt2        = CC.Lottable04_Cnt2
                 , Lottable01_Cnt3        = CC.Lottable01_Cnt3
                 , Lottable02_Cnt3        = CC.Lottable02_Cnt3
                 , Lottable03_Cnt3        = CC.Lottable03_Cnt3
                 , Lottable04_Cnt3        = CC.Lottable04_Cnt3
                 , WMS_Qty_by_SKU         = SUM(CC.SystemQty) OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku)
                 , Cnt1_Qty_by_SKU        = SUM(CC.Qty)       OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku)
                 , Cnt2_Qty_by_SKU        = SUM(CC.Qty_Cnt2)  OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku)
                 , Cnt3_Qty_by_SKU        = SUM(CC.Qty_Cnt3)  OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku)
                 , WMS_Qty_by_SKUxLOC     = SUM(CC.SystemQty) OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc)
                 , Cnt1_Qty_by_SKUxLOC    = SUM(CC.Qty)       OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc)
                 , Cnt2_Qty_by_SKUxLOC    = SUM(CC.Qty_Cnt2)  OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc)
                 , Cnt3_Qty_by_SKUxLOC    = SUM(CC.Qty_Cnt3)  OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc)
                 , WMS_Qty_by_SKUxLOCxID  = SUM(CC.SystemQty) OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc, CC.ID)
                 , Cnt1_Qty_by_SKUxLOCxID = SUM(CC.Qty)       OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc, CC.ID)
                 , Cnt2_Qty_by_SKUxLOCxID = SUM(CC.Qty_Cnt2)  OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc, CC.ID)
                 , Cnt3_Qty_by_SKUxLOCxID = SUM(CC.Qty_Cnt3)  OVER (PARTITION BY CC.Storerkey, CC.CCKey, CC.Sku, CC.Loc, CC.ID)
                 , CCLogicalLoc           = CC.CCLogicalLoc
                 , MovableUnit            = IIF( CC.Facility IN ('1173', '1176'), ISNULL(RTRIM(CC.ID),''), '')
                 , Lot1                   = IIF( CC.Facility='1175', ISNULL(RTRIM(CC.Lottable01),''), '')
                 , Manufacturing          = CC.Lottable02
                 , Warrant                = IIF( CC.Facility='1175', ISNULL(RTRIM(CC.Lottable03),''), '')
                 , ExpiryDate             = CASE WHEN BRD.Long='ACD' THEN CC.Lottable04 END
            FROM #TEMP_CCDETAIL     CC
            LEFT JOIN dbo.STORER    ST(NOLOCK) ON (CC.StorerKey=ST.Storerkey)
            LEFT JOIN dbo.SKU      SKU(NOLOCK) ON (CC.Storerkey=SKU.StorerKey AND CC.Sku=SKU.Sku)
            LEFT JOIN dbo.CODELKUP BRD(NOLOCK) ON (BRD.Listname='LORBRAND' AND SKU.Storerkey=BRD.Storerkey AND SKU.Class=BRD.Description)
         ) X
      ) Y
   ) Z

   DROP TABLE #TEMP_CCDETAIL


RESULTS:
   SELECT Storerkey    = CC.Storerkey
        , CCKey        = CC.CCKey
        , CountNo      = CC.CountNo
        , Facility     = MAX(CC.Facility)
        , Div          = MAX(CC.Div)
        , Brand        = MAX(CC.Brand)
        , ProductType  = MAX(CC.ProductType)
        , Sku          = CC.Sku
        , DESCR        = MAX(CC.DESCR)
        , Loc          = CC.Loc
        , ID           = CC.ID
        , Lottable02   = CC.Lottable02
        , WMS_Qty      = SUM(CC.WMS_Qty )
        , Cnt1_Qty     = SUM(CC.Cnt1_Qty)
        , Cnt2_Qty     = CASE WHEN CC.CountNo>='2' THEN SUM(CC.Cnt2_Qty) END
        , Cnt3_Qty     = CASE WHEN CC.CountNo>='3' THEN SUM(CC.Cnt3_Qty) END
        , Cnt1_Var_Qty = SUM(CC.Cnt1_Qty - CC.WMS_Qty)
        , Cnt2_Var_Qty = CASE WHEN CC.CountNo>='2' THEN SUM(CC.Cnt2_Qty - CC.WMS_Qty) END
        , Cnt3_Var_Qty = CASE WHEN CC.CountNo>='3' THEN SUM(CC.Cnt3_Qty - CC.WMS_Qty) END
        , CountDesc    = ISNULL( @c_CountDesc,'' )
        , Var_Filter   = @as_var_filter
   FROM #TEMP_CCDETAIL2 CC
   WHERE ISNULL(CASE CountNo
            WHEN '1' THEN (CASE @as_var_filter WHEN '1' THEN Cnt2_Filter_SKU WHEN '2' THEN Cnt2_Filter_SKUxLOC WHEN '3' THEN Cnt2_Filter_SKUxLOCxID END)
            WHEN '2' THEN (CASE @as_var_filter WHEN '1' THEN Cnt3_Filter_SKU WHEN '2' THEN Cnt3_Filter_SKUxLOC WHEN '3' THEN Cnt3_Filter_SKUxLOCxID END)
            WHEN '3' THEN (CASE WHEN CC.Cnt3_Qty<>CC.WMS_Qty THEN 'Y' END)
         END, 'N') = 'Y'
   GROUP BY CC.Storerkey
          , CC.CCKey
          , CC.CountNo
          , CC.Sku
          , CC.Loc
          , CC.ID
          , CC.Lottable02
   HAVING CountNo<='2' OR SUM(CC.Cnt3_Qty)<>SUM(CC.WMS_Qty)
   ORDER BY Div, Brand, ProductType, Sku, Loc, ID, Lottable02

QUIT:
END

GO