SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: ispGetStockTakeSheet_PH_07                         */
/* Creation Date: 10-Nov-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15630 - [PH] Unilever_Barcoded_CountSheet               */
/*                                                                      */
/* Input Parameters:  @c_CCkey_Start      , @c_CCkey_End                */
/*                   ,@c_SKU_Start        , @c_SKU_End                  */
/*                   ,@c_ItemClass_Start  , @c_ItemClass_End            */
/*                   ,@c_StorerKey_Start  , @c_StorerKey_End            */
/*                   ,@c_LOC_Start        , @c_LOC_End                  */
/*                   ,@c_Zone_Start       , @c_Zone_End                 */
/*                   ,@c_CCSheetNo_Start  , @c_CCSheetNo_End            */
/*                   ,@c_WithQty                                        */
/*                   ,@c_CountNo                                        */
/*                   ,@c_FinalizeFlag                                   */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_stocktake_ph_07                                      */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 28-JUL-2022  MINGLE   1.1  WMS-20325 Change ID to fit 15 char(ML01)  */
/************************************************************************/

CREATE PROC [dbo].[ispGetStockTakeSheet_PH_07]
    @c_CCkey_Start      NVARCHAR(10), @c_CCkey_End     NVARCHAR(10)
   ,@c_SKU_Start        NVARCHAR(20), @c_SKU_End       NVARCHAR(20)
   ,@c_ItemClass_Start  NVARCHAR(10), @c_ItemClass_End NVARCHAR(10)
   ,@c_StorerKey_Start  NVARCHAR(15), @c_StorerKey_End NVARCHAR(15)
   ,@c_LOC_Start        NVARCHAR(10), @c_LOC_End       NVARCHAR(10)
   ,@c_Zone_Start       NVARCHAR(10), @c_Zone_End      NVARCHAR(10)
   ,@c_CCSheetNo_Start  NVARCHAR(10), @c_CCSheetNo_End NVARCHAR(10)
   ,@c_WithQty          NVARCHAR(10)
   ,@c_CountNo          NVARCHAR(10)
   ,@c_FinalizeFlag     NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT
         , @n_Err       INT
         , @b_Success   INT
         , @c_ErrMsg    NVARCHAR(255)

   DECLARE @c_Storerkey NVARCHAR(15)
         , @c_Configkey NVARCHAR(30)
         , @c_SValue    NVARCHAR(10)

         , @c_Facility     NVARCHAR(5)
         , @c_Stocktakekey NVARCHAR(10)
         , @c_CCSheetNo    NVARCHAR(10)
         , @c_LocAisle     NVARCHAR(10)
         , @c_Company      NVARCHAR(45)
         , @c_LOC          NVARCHAR(10)
         , @c_ID           NVARCHAR(250)

         , @c_ID1          NVARCHAR(15)	--ML01
         , @c_ID2          NVARCHAR(15)	--ML01
         , @c_CCDetailKey  NVARCHAR(10)

   SET @n_Continue = 1
   SET @n_Err      = 0
   SET @b_Success  = 1
   SET @c_ErrMsg   = ''

   CREATE TABLE #TMP_CCSHEET07_Final (
      Facility       NVARCHAR(5)  NULL
    , Stocktakekey   NVARCHAR(10) NULL
    , CCSheetNo      NVARCHAR(10) NULL
    , Storerkey      NVARCHAR(15) NULL
    , LocAisle       NVARCHAR(10) NULL
    , Company        NVARCHAR(45) NULL
    , LOC            NVARCHAR(10) NULL
    , ID1            NVARCHAR(15) NULL	--ML01
    , ID2            NVARCHAR(15) NULL	--ML01
    , CCDetailKey    NVARCHAR(10) NULL
   )

   SELECT Stocktakesheetparameters.facility,
          Stocktakesheetparameters.Stocktakekey,
          CCDetail.CCSheetNo,
          Stocktakesheetparameters.Storerkey,
          LOC.LocAisle,
          STORER.Company,
          --(SELECT MIN(CCD.loc)
          --FROM CCDETAIL CCD WITH (NOLOCK)
          --WHERE CCD.CCDetailKey = MIN(CCDetail.CCDetailKey)) AS LocStart,
          --(SELECT MAX(CCD.loc)
          --FROM CCDETAIL CCD WITH (NOLOCK)
          --WHERE CCD.CCDetailKey = MAX(CCDetail.CCDetailKey)) AS LocEnd
          CCDetail.Loc AS Loc,
          CCDetail.ID AS ID,
          (SELECT MIN(CCD.CCDetailKey)
           FROM CCDETAIL CCD (NOLOCK)
           WHERE CCD.CCSheetNo = CCDETAIL.CCSheetNo
           AND CCD.CCKey = Stocktakesheetparameters.Stocktakekey
           AND CCD.LOC = MIN(CCDETAIL.LOC)) AS CCDetailKey
   INTO #TMP_CCSHEET07
   FROM CCDetail (NOLOCK)
   LEFT JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
   --LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey )
   LEFT JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )
   --LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone )
   LEFT JOIN Stocktakesheetparameters (NOLOCK) ON (Stocktakesheetparameters.Stocktakekey = CCDetail.CCkey)
   LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = Stocktakesheetparameters.StorerKey )
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND  CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
	AND  CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
	AND  CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
	AND  ISNULL(SKU.ItemClass,'') Between @c_ItemClass_Start AND @c_ItemClass_End
	AND  LOC.LOC Between @c_LOC_Start AND @c_LOC_End
	AND  LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End
	AND  @c_FinalizeFlag = CASE @c_CountNo
                             WHEN '1' THEN CCDETAIL.FinalizeFlag
                             WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                             WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                          END
	--AND   CCDETAIL.SystemQty > 0
   GROUP BY Stocktakesheetparameters.facility,
            Stocktakesheetparameters.Stocktakekey,
            CCDetail.CCSheetNo,
            Stocktakesheetparameters.Storerkey,
            LOC.LocAisle,
            STORER.Company,
            CCDetail.Loc,
            CCDetail.ID
   --ORDER BY Stocktakesheetparameters.Stocktakekey,
   --         LOC.LocAisle, CCDETAIL.CCSheetNo, CCDetail.Loc
   --SELECT * FROM #TMP_CCSHEET07

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          Facility,
          Stocktakekey,
          CCSheetNo,
          Storerkey,
          LocAisle,
          Company,
          LOC,
          CAST(STUFF((SELECT TOP 2 '|' + RTRIM(ID) FROM #TMP_CCSHEET07
                      WHERE facility = t.facility
                      AND Stocktakekey = t.Stocktakekey
                      AND CCSheetNo = t.CCSheetNo
                      AND Storerkey = t.Storerkey
                      AND LocAisle = t.LocAisle
                      AND Company = t.Company
                      AND LOC = t.LOC
                      AND CCDetailKey = t.CCDetailKey
                      ORDER BY ID
                      FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS ID,
          CCDetailKey
   FROM #TMP_CCSHEET07 t

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Facility
                               , @c_Stocktakekey
                               , @c_CCSheetNo
                               , @c_Storerkey
                               , @c_LocAisle
                               , @c_Company
                               , @c_LOC
                               , @c_ID
                               , @c_CCDetailKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ID1 = ''
      SET @c_ID2 = ''

   	SELECT @c_ID1 = ColValue FROM dbo.fnc_delimsplit ('|',@c_ID) WHERE SeqNo = 1
   	SELECT @c_ID2 = ColValue FROM dbo.fnc_delimsplit ('|',@c_ID) WHERE SeqNo = 2

      INSERT INTO #TMP_CCSHEET07_Final
      (
      	Facility,
      	Stocktakekey,
      	CCSheetNo,
      	Storerkey,
      	LocAisle,
      	Company,
      	LOC,
      	ID1,
      	ID2,
      	CCDetailKey
      )
      VALUES
      (
      	@c_Facility,
      	@c_Stocktakekey,
      	@c_CCSheetNo,
      	@c_Storerkey,
      	@c_LocAisle,
      	@c_Company,
      	@c_LOC,
      	@c_ID1,
      	@c_ID2,
      	@c_CCDetailKey
      )

   	FETCH NEXT FROM CUR_LOOP INTO @c_Facility
                                  , @c_Stocktakekey
                                  , @c_CCSheetNo
                                  , @c_Storerkey
                                  , @c_LocAisle
                                  , @c_Company
                                  , @c_LOC
                                  , @c_ID
                                  , @c_CCDetailKey
   END

   SELECT Facility
        , Stocktakekey
        , CCSheetNo
        , Storerkey
        , LocAisle
        , Company
        , LOC
        , ID1
        , ID2
   FROM #TMP_CCSHEET07_Final
   ORDER BY Stocktakekey, LocAisle, CCSheetNo, CCDetailKey

QUIT:
   IF OBJECT_ID('tempdb..#TMP_CCSHEET07') IS NOT NULL
      DROP TABLE #TMP_CCSHEET07

   IF OBJECT_ID('tempdb..#TMP_CCSHEET07_Final') IS NOT NULL
      DROP TABLE #TMP_CCSHEET07_Final

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

END

GO