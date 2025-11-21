SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGetStockTakeSheet_ph_06                         */  
/* Creation Date: 22-MAY-2020                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHO                                                    */  
/*                                                                      */  
/* Purpose: WMS-13466 [PH] - Adidas Normal Countsheet                   */  
/*                                                                      */ 
/* Input Parameters:  @c_CCkey_Start      , @c_CCkey_End                */
/*                   ,@c_SKU_Start        , @c_SKU_End                  */  
/*                   ,@c_ItemClass_Start  , @c_ItemClass_End            */
/*                   ,@c_StorerKey_Start  , @c_StorerKey_End            */
/*                   ,@c_LOC_Start        , @c_LOC_End                  */
/*                   ,@c_Zone_Start       , @c_Zone_End                 */
/*                   ,@c_CCSheetNo_Start  , @c_CCSheetNo_End            */
/*                   ,@c_WithQty          , @c_CountNo                  */
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
/* Called By: r_dw_stocktake_ph_06                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE PROC [dbo].[ispGetStockTakeSheet_ph_06] 
    @c_CCkey_Start      NVARCHAR(10), @c_CCkey_End     NVARCHAR(10)    
   ,@c_SKU_Start        NVARCHAR(20), @c_SKU_End       NVARCHAR(20)
   ,@c_ItemClass_Start  NVARCHAR(10), @c_ItemClass_End NVARCHAR(10)
   ,@c_StorerKey_Start  NVARCHAR(15), @c_StorerKey_End NVARCHAR(15)
   ,@c_LOC_Start        NVARCHAR(10), @c_LOC_End       NVARCHAR(10)
   ,@c_Zone_Start       NVARCHAR(10), @c_Zone_End      NVARCHAR(10)
   ,@c_CCSheetNo_Start  NVARCHAR(10), @c_CCSheetNo_End NVARCHAR(10)
   ,@c_WithQty          NVARCHAR(10), @c_CountNo          NVARCHAR(10)
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

   SET @n_Continue = 1
   SET @n_Err      = 0
   SET @b_Success  = 1
   SET @c_ErrMsg   = ''
   
   SET @c_Storerkey= ''
   SET @c_Configkey= 'VarianceReport_LotxIDxLoc'
   SET @c_SValue   = '0'

   CREATE TABLE #Var_STSPH_06 ( 
           CCKey        NVARCHAR(10)   NULL  
         , CCSheetNo    NVARCHAR(10)    NULL    
         , Storerkey    NVARCHAR(15)    NULL
         , Sku          NVARCHAR(20)    NULL
         , SystemQty    INT             NULL
         , Lottable01   NVARCHAR(18)    NULL
         , Lottable02   NVARCHAR(18)    NULL
         , Lottable03   NVARCHAR(18)    NULL
         , CCDetailKey  NVARCHAR(10)    NULL
         , Lottable10   NVARCHAR(30)    NULL
         , FinalizeFlag NVARCHAR(1)     NULL
         , CCLogicalLoc NVARCHAR(18)    NULL
         , Loc          NVARCHAR(10)    NULL
         , Addwho       NVARCHAR(256)   NULL
         , Facility     NVARCHAR(10)    NULL
         , PrintFlag    NVARCHAR(1)     NULL      )

   SELECT @c_Storerkey = ISNULL(RTRIM(Storerkey),'') 
   FROM StockTakeSheetParameters WITH (NOLOCK)
   WHERE StockTakeKey = @c_CCkey_Start

   EXECUTE dbo.nspGetRight NULL                 -- facility
                        ,  @c_Storerkey         -- Storerkey
                        ,  NULL                 -- Sku
                        ,  @c_Configkey         -- Configkey
                        ,  @b_success      OUTPUT
                        ,  @c_SValue       OUTPUT
                        ,  @n_err          OUTPUT
                        ,  @c_errmsg       OUTPUT
   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3 
      SET @n_Err = 31301
      SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err) 
                    + ': Error Getting StorerCongfig for Storer: ' + RTRIM(@c_Storerkey)
                    + '. (ispGetStockTakeSheet_03)' 
      GOTO QUIT
   END 

   INSERT INTO #Var_STSPH_06 (
                 CCKey
               , CCSheetNo              
               , Storerkey
               , Sku
               , SystemQty
               , Lottable01
               , Lottable02
               , Lottable03
               , CCDetailKey
               , Lottable10
               , FinalizeFlag   
               , CCLogicalLoc
               , Loc
               , Addwho
               , Facility
               , PrintFlag )
   SELECT CCDetail.CCKey,   
         CCDetail.CCSheetNo,     
         CCDetail.Storerkey,   
         substring (CCdetail.SKU,1,6),        
         1  as SystemQty,     
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable01 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable01
                              WHEN '2' THEN CCDetail.Lottable01_Cnt2
                              WHEN '3' THEN CCDetail.Lottable01_Cnt3
                          END
         END As Lottable01,   
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable02 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable02
                              WHEN '2' THEN CCDetail.Lottable02_Cnt2
                              WHEN '3' THEN CCDetail.Lottable02_Cnt3
                          END
         END As Lottable02,   
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable03 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable03
                              WHEN '2' THEN CCDetail.Lottable03_Cnt2
                              WHEN '3' THEN CCDetail.Lottable03_Cnt3
                          END
         END As Lottable03,   
         CCDetail.CCDetailKey,   
         CCDetail.Lottable10,   
         CCDetail.FinalizeFlag,     
         LOC.CCLogicalLoc,      
         CCDetail.Loc,  
         CCDetail.Addwho,
         LOC.Facility,
         'N'        
    FROM CCDetail (NOLOCK)   
         LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   ISNULL(SKU.ItemClass,'') Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                            END
   AND   CCDETAIL.SystemQty > 0
  UNION
  SELECT CCDetail.CCKey,   
         CCDetail.CCSheetNo,     
         CCDetail.Storerkey,   
         substring (CCdetail.SKU,1,6),    
         1  as SystemQty,   
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable01 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable01
                              WHEN '2' THEN CCDetail.Lottable01_Cnt2
                              WHEN '3' THEN CCDetail.Lottable01_Cnt3
                          END
         END As Lottable01,   
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable02 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable02
                              WHEN '2' THEN CCDetail.Lottable02_Cnt2
                              WHEN '3' THEN CCDetail.Lottable02_Cnt3
                          END
         END As Lottable02,   
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable03 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable03
                              WHEN '2' THEN CCDetail.Lottable03_Cnt2
                              WHEN '3' THEN CCDetail.Lottable03_Cnt3
                          END
         END As Lottable03,   
         CCDetail.CCDetailKey,   
         CCDetail.Lottable10,   
         CCDetail.FinalizeFlag,   
         LOC.CCLogicalLoc,     
         CCDetail.Loc,  
         CCDetail.Addwho,
         LOC.Facility,
         'N'      
    FROM CCDetail (NOLOCK)   
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                            END
   AND   CCDETAIL.SystemQty = 0
   ORDER BY CCDetail.CCSheetNo 


   QUIT:

      SELECT  DISTINCT
                 CCKey
               , CCSheetNo               
               , Storerkey
               , Sku
               , SystemQty
               , Lottable01
               , Lottable02
               , Lottable03
               , MAX(CCDetailKey) as CCDetailKey
               , Lottable10
               , FinalizeFlag
               , CCLogicalLoc
               , Loc
               , Addwho
               , Facility
               , PrintFlag
      FROM #Var_STSPH_06
      GROUP BY     CCKey
               , CCSheetNo               
               , Storerkey
               , Sku
               , SystemQty
               , Lottable01
               , Lottable02
               , Lottable03
             --  , CCDetailKey
               , Lottable10
               , FinalizeFlag
               , CCLogicalLoc
               , Loc
               , Addwho
               , Facility
               , PrintFlag
      ORDER BY   CCKey
               , CCSheetNo 
               , CCLogicalLoc
              ,  Lottable10
   
   DROP TABLE #Var_STSPH_06      
END

GO