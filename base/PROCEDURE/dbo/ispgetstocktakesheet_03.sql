SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGetStockTakeSheet_03                            */  
/* Creation Date: 22-Nov-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#230489 - Stocktake Variance report                      */  
/*                                                                      */ 
/* Input Parameters:  @c_CCkey_Start      , @c_CCkey_End                */
/*                   ,@c_SKU_Start        , @c_SKU_End                  */  
/*                   ,@c_ItemClass_Start  , @c_ItemClass_End            */
/*                   ,@c_StorerKey_Start  , @c_StorerKey_End            */
/*                   ,@c_LOC_Start        , @c_LOC_End                  */
/*                   ,@c_Zone_Start       , @c_Zone_End                 */
/*                   ,@c_CCSheetNo_Start  , @c_CCSheetNo_End            */
/*                   ,@c_CountNo                                        */
/*                   ,@c_VarFor                                         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: r_dw_stocktake_my_03                                      */  
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

CREATE PROC [dbo].[ispGetStockTakeSheet_03] 
    @c_CCkey_Start      NVARCHAR(10), @c_CCkey_End     NVARCHAR(10)    
   ,@c_SKU_Start        NVARCHAR(20), @c_SKU_End       NVARCHAR(20)
   ,@c_ItemClass_Start  NVARCHAR(10), @c_ItemClass_End NVARCHAR(10)
   ,@c_StorerKey_Start  NVARCHAR(15), @c_StorerKey_End NVARCHAR(15)
   ,@c_LOC_Start        NVARCHAR(10), @c_LOC_End       NVARCHAR(10)
   ,@c_Zone_Start       NVARCHAR(10), @c_Zone_End      NVARCHAR(10)
   ,@c_CCSheetNo_Start  NVARCHAR(10), @c_CCSheetNo_End NVARCHAR(10)
   ,@c_CountNo          NVARCHAR(10)
   ,@c_VarFor           NVARCHAR(10)

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

   CREATE TABLE #Var_Data ( 
           CCKey        NVARCHAR(10)		NULL	
         , CCSheetNo    NVARCHAR(10)    NULL
         , CCDetailKey  NVARCHAR(10)    NULL
         , TagNo        NVARCHAR(10)    NULL
         , Storerkey    NVARCHAR(15)    NULL
         , Sku          NVARCHAR(20)    NULL
         , Lot          NVARCHAR(10)    NULL
         , ID           NVARCHAR(18)    NULL
         , SystemQty    INT            NULL
         , CountQty     INT            NULL
         , Lottable01   NVARCHAR(18)		NULL
         , Lottable02   NVARCHAR(18)    NULL
         , Lottable03   NVARCHAR(18)    NULL
         , Lottable04   DATETIME			NULL
         , Lottable05   DATETIME       NULL
         , FinalizeFlag NVARCHAR(1)			NULL
         , Company      NVARCHAR(45)   	NULL
         , Descr        NVARCHAR(60)   	NULL
         , PackKey      NVARCHAR(10)    NULL
         , CaseCnt      FLOAT				NULL
         , InnerPack    FLOAT          NULL
         , AreaKey      NVARCHAR(10)    NULL
         , Facility     NVARCHAR(5)     NULL
         , PutawayZone  NVARCHAR(10)    NULL
         , LocLevel     NVARCHAR(4)     NULL
         , CCLogicalLoc NVARCHAR(18)    NULL
         , LocAisle     NVARCHAR(10)    NULL
         , Loc          NVARCHAR(10)    NULL
         , CountNo      NVARCHAR(10)    NULL
         , VarFor       NVARCHAR(10)    NULL       )

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

   INSERT INTO #Var_Data (
                 CCKey
               , CCSheetNo
               , CCDetailKey
               , TagNo
               , Storerkey
               , Sku
               , Lot
               , ID
               , SystemQty
               , CountQty
               , Lottable01
               , Lottable02
               , Lottable03
               , Lottable04
               , Lottable05
               , FinalizeFlag
               , Company
               , Descr
               , PackKey
               , CaseCnt
               , InnerPack
               , AreaKey
               , Facility
               , PutawayZone
               , LocLevel
               , CCLogicalLoc
               , LocAisle
               , Loc
               , CountNo
               , VarFor )
   SELECT CCDetail.CCKey
         ,CCDetail.CCSheetNo
         ,CCDetail.CCDetailKey 
         ,CCDetail.TagNo
         ,CCDetail.Storerkey  
         ,CCDetail.Sku 
         ,CCDetail.Lot  
         ,CCDetail.Id  
         ,CCDetail.SystemQty  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.SystemQty 
            WHEN '1' THEN CCDetail.Qty 
            WHEN '2' THEN CCDETAIL.Qty_Cnt2 
            WHEN '3' THEN CCDETAIL.Qty_CNt3 
          END AS CountQty  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable01
            WHEN '1' THEN CCDetail.Lottable01
            WHEN '2' THEN CCDetail.Lottable01_Cnt2
            WHEN '3' THEN CCDetail.Lottable01_Cnt3
          END As Lottable01 
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable02
            WHEN '1' THEN CCDetail.Lottable02
            WHEN '2' THEN CCDetail.Lottable02_Cnt2
            WHEN '3' THEN CCDetail.Lottable02_Cnt3
          END As Lottable02  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable03
            WHEN '1' THEN CCDetail.Lottable03
            WHEN '2' THEN CCDetail.Lottable03_Cnt2
            WHEN '3' THEN CCDetail.Lottable03_Cnt3
          END As Lottable03  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable04
            WHEN '1' THEN CCDetail.Lottable04
            WHEN '2' THEN CCDetail.Lottable04_Cnt2
            WHEN '3' THEN CCDetail.Lottable04_Cnt3
          END As Lottable04
         ,CCDetail.Lottable05
         ,CCDetail.FinalizeFlag  
         ,STORER.Company
         ,SKU.DESCR
         ,PACK.PackKey  
         ,PACK.CaseCnt  
         ,PACK.InnerPack 
         ,AreaDetail.AreaKey
         ,LOC.Facility  
         ,LOC.PutawayZone  
         ,LOC.LocLevel 
         ,LOC.CCLogicalLoc  
         ,LOC.LocAisle  
         ,LOC.Loc
         ,@c_CountNo AS CountNo
         ,@c_VarFor  AS VarFor     
    FROM CCDetail WITH (NOLOCK)  
         LEFT JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CCDetail.StorerKey )    
         LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC  WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   CCDETAIL.SystemQty > 0
   AND   @c_VarFor = '0' 
	UNION
   SELECT CCDetail.CCKey  
         ,CCDetail.CCSheetNo
         ,CCDetail.CCDetailKey    
         ,CCDetail.TagNo  
         ,CCDetail.Storerkey  
         ,CCDetail.Sku  
         ,CCDetail.Lot  
         ,CCDetail.Id 
         ,CCDetail.SystemQty  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.SystemQty 
             WHEN '1' THEN CCDetail.Qty 
             WHEN '2' THEN CCDETAIL.Qty_Cnt2 
             WHEN '3' THEN CCDETAIL.Qty_CNt3 
          END AS CountQty  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable01
             WHEN '1' THEN CCDetail.Lottable01
             WHEN '2' THEN CCDetail.Lottable01_Cnt2
             WHEN '3' THEN CCDetail.Lottable01_Cnt3
          END As Lottable01  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable02
             WHEN '1' THEN CCDetail.Lottable02
             WHEN '2' THEN CCDetail.Lottable02_Cnt2
             WHEN '3' THEN CCDetail.Lottable02_Cnt3
          END As Lottable02  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable03
             WHEN '1' THEN CCDetail.Lottable03
             WHEN '2' THEN CCDetail.Lottable03_Cnt2
             WHEN '3' THEN CCDetail.Lottable03_Cnt3
          END As Lottable03  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable04
             WHEN '1' THEN CCDetail.Lottable04
             WHEN '2' THEN CCDetail.Lottable04_Cnt2
             WHEN '3' THEN CCDetail.Lottable04_Cnt3
          END As Lottable04
         ,CCDetail.Lottable05
         ,CCDetail.FinalizeFlag  
         ,'' As Company
         ,'' As Descr
         ,'' As PackKey  
         ,'' As CaseCnt  
         ,'' As InnerPack   
         ,AreaDetail.AreaKey
         ,LOC.Facility  
         ,LOC.PutawayZone 
         ,LOC.LocLevel 
         ,LOC.CCLogicalLoc  
         ,LOC.LocAisle 
         ,LOC.Loc 
         ,@c_CountNo AS CountNo
         ,@c_VarFor AS VarFor     
    FROM CCDetail WITH (NOLOCK)   
         JOIN LOC WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   CCDETAIL.SystemQty = 0
   AND   @c_VarFor = '0' 
	UNION
   SELECT CCDetail.CCKey  
         ,CCDetail.CCSheetNo
         ,CCDetail.CCDetailKey   
         ,CCDetail.TagNo  
         ,CCDetail.Storerkey   
         ,CCDetail.Sku  
         ,CCDetail.Lot  
         ,CCDetail.Id 
         ,CCDetail.SystemQty  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.SystemQty 
             WHEN '1' THEN CCDetail.Qty 
             WHEN '2' THEN CCDETAIL.Qty_Cnt2 
             WHEN '3' THEN CCDETAIL.Qty_CNt3 
          END AS CountQty  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable01
             WHEN '1' THEN CCDetail.Lottable01
             WHEN '2' THEN CCDetail.Lottable01_Cnt2
             WHEN '3' THEN CCDetail.Lottable01_Cnt3
          END As Lottable01  
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable02
             WHEN '1' THEN CCDetail.Lottable02
             WHEN '2' THEN CCDetail.Lottable02_Cnt2
             WHEN '3' THEN CCDetail.Lottable02_Cnt3
          END As Lottable02   
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable03
             WHEN '1' THEN CCDetail.Lottable03
         
             WHEN '2' THEN CCDetail.Lottable03_Cnt2
             WHEN '3' THEN CCDetail.Lottable03_Cnt3
          END As Lottable03 
         ,CASE @c_CountNo 
             WHEN '0' THEN CCDetail.Lottable04
             WHEN '1' THEN CCDetail.Lottable04
             WHEN '2' THEN CCDetail.Lottable04_Cnt2
             WHEN '3' THEN CCDetail.Lottable04_Cnt3
          END As Lottable04
         ,CCDetail.Lottable05
         ,CCDetail.FinalizeFlag
         ,STORER.Company 
         ,SKU.Descr 
         ,PACK.PackKey   
         ,PACK.CaseCnt  
         ,PACK.InnerPack  
         ,AreaDetail.AreaKey  
         ,LOC.Facility  
         ,LOC.PutawayZone 
         ,LOC.LocLevel  
         ,LOC.CCLogicalLoc   
         ,LOC.LocAisle 
         ,LOC.Loc
         ,@c_CountNo AS CountNo
         ,@c_VarFor AS VarFor     
    FROM CCDetail WITH (NOLOCK) 
         LEFT JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CCDetail.StorerKey )    
         LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   CCDetail.Qty <> CCDetail.SystemQty 
   AND   @c_VarFor = '1' 
	UNION
   SELECT CCDetail.CCKey  
         ,CCDetail.CCSheetNo    
         ,CCDetail.CCDetailKey    
         ,CCDetail.TagNo  
         ,CCDetail.Storerkey   
         ,CCDetail.Sku    
         ,CCDetail.Lot   
         ,CCDetail.Id   
         ,CCDetail.SystemQty   
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.SystemQty 
            WHEN '1' THEN CCDetail.Qty 
            WHEN '2' THEN CCDETAIL.Qty_Cnt2 
            WHEN '3' THEN CCDETAIL.Qty_CNt3 
          END AS CountQty  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable01
            WHEN '1' THEN CCDetail.Lottable01
            WHEN '2' THEN CCDetail.Lottable01_Cnt2
            WHEN '3' THEN CCDetail.Lottable01_Cnt3
          END As Lottable01   
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable02
            WHEN '1' THEN CCDetail.Lottable02
            WHEN '2' THEN CCDetail.Lottable02_Cnt2
            WHEN '3' THEN CCDetail.Lottable02_Cnt3
          END As Lottable02  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable03
            WHEN '1' THEN CCDetail.Lottable03
            WHEN '2' THEN CCDetail.Lottable03_Cnt2
            WHEN '3' THEN CCDetail.Lottable03_Cnt3
          END As Lottable03  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable04
            WHEN '1' THEN CCDetail.Lottable04
            WHEN '2' THEN CCDetail.Lottable04_Cnt2
            WHEN '3' THEN CCDetail.Lottable04_Cnt3
          END As Lottable04
         ,CCDetail.Lottable05  
         ,CCDetail.FinalizeFlag
         ,STORER.Company
         ,SKU.Descr
         ,PACK.PackKey 
         ,PACK.CaseCnt  
         ,PACK.InnerPack  
         ,AreaDetail.AreaKey
         ,LOC.Facility  
         ,LOC.PutawayZone  
         ,LOC.LocLevel 
         ,LOC.CCLogicalLoc  
         ,LOC.LocAisle  
         ,LOC.Loc
         ,@c_CountNo AS CountNo
         ,@c_VarFor AS VarFor     
    FROM CCDetail WITH (NOLOCK)  
         LEFT JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CCDetail.StorerKey )    
         LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   CCDetail.Qty_cnt2 <> CCDetail.SystemQty 
   AND   @c_VarFor = '2' 
	UNION
  	SELECT CCDetail.CCKey  
         ,CCDetail.CCSheetNo
         ,CCDetail.CCDetailKey    
         ,CCDetail.TagNo  
         ,CCDetail.Storerkey   
         ,CCDetail.Sku  
         ,CCDetail.Lot   
         ,CCDetail.Id   
         ,CCDetail.SystemQty 
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.SystemQty 
            WHEN '1' THEN CCDetail.Qty 
            WHEN '2' THEN CCDETAIL.Qty_Cnt2 
            WHEN '3' THEN CCDETAIL.Qty_CNt3 
          END AS CountQty  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable01
            WHEN '1' THEN CCDetail.Lottable01
            WHEN '2' THEN CCDetail.Lottable01_Cnt2
            WHEN '3' THEN CCDetail.Lottable01_Cnt3
          END As Lottable01   
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable02
            WHEN '1' THEN CCDetail.Lottable02
            WHEN '2' THEN CCDetail.Lottable02_Cnt2
            WHEN '3' THEN CCDetail.Lottable02_Cnt3
          END As Lottable02  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable03
            WHEN '1' THEN CCDetail.Lottable03

            WHEN '2' THEN CCDetail.Lottable03_Cnt2
            WHEN '3' THEN CCDetail.Lottable03_Cnt3
          END As Lottable03 
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable04
            WHEN '1' THEN CCDetail.Lottable04
            WHEN '2' THEN CCDetail.Lottable04_Cnt2
            WHEN '3' THEN CCDetail.Lottable04_Cnt3
          END As Lottable04
         ,CCDetail.Lottable05
         ,CCDetail.FinalizeFlag
         ,STORER.Company
         ,SKU.DESCR 
         ,PACK.PackKey   
         ,PACK.CaseCnt   
         ,PACK.InnerPack  
         ,AreaDetail.AreaKey 
         ,LOC.Facility  
         ,LOC.PutawayZone  
         ,LOC.LocLevel  
         ,LOC.CCLogicalLoc 
         ,LOC.LocAisle  
         ,LOC.Loc  
         ,@c_CountNo AS CountNo
         ,@c_VarFor AS VarFor     
    FROM CCDetail WITH (NOLOCK)   
         LEFT JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CCDetail.StorerKey )    
         LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   CCDetail.Qty_cnt2 <> CCDetail.Qty 
   AND   @c_VarFor = '3' 
	UNION
  	SELECT CCDetail.CCKey  
         ,CCDetail.CCSheetNo  
         ,CCDetail.CCDetailKey  
         ,CCDetail.TagNo  
         ,CCDetail.Storerkey  
         ,CCDetail.Sku  
         ,CCDetail.Lot   
         ,CCDetail.Id
         ,CCDetail.SystemQty  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.SystemQty 
            WHEN '1' THEN CCDetail.Qty 
            WHEN '2' THEN CCDETAIL.Qty_Cnt2 
            WHEN '3' THEN CCDETAIL.Qty_CNt3 
          END AS CountQty  
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable01
            WHEN '1' THEN CCDetail.Lottable01
            WHEN '2' THEN CCDetail.Lottable01_Cnt2
            WHEN '3' THEN CCDetail.Lottable01_Cnt3
          END As Lottable01   
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable02
            WHEN '1' THEN CCDetail.Lottable02
            WHEN '2' THEN CCDetail.Lottable02_Cnt2
            WHEN '3' THEN CCDetail.Lottable02_Cnt3
          END As Lottable02   
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable03
            WHEN '1' THEN CCDetail.Lottable03

            WHEN '2' THEN CCDetail.Lottable03_Cnt2
            WHEN '3' THEN CCDetail.Lottable03_Cnt3
          END As Lottable03   
         ,CASE @c_CountNo 
            WHEN '0' THEN CCDetail.Lottable04
            WHEN '1' THEN CCDetail.Lottable04
            WHEN '2' THEN CCDetail.Lottable04_Cnt2
            WHEN '3' THEN CCDetail.Lottable04_Cnt3
          END As Lottable04
         ,CCDetail.Lottable05
         ,CCDetail.FinalizeFlag  
         ,STORER.Company
         ,SKU.Descr
         ,PACK.PackKey  
         ,PACK.CaseCnt 
         ,PACK.InnerPack   
         ,AreaDetail.AreaKey
         ,LOC.Facility  
         ,LOC.PutawayZone  
         ,LOC.LocLevel 
         ,LOC.CCLogicalLoc  
         ,LOC.LocAisle  
         ,LOC.Loc
         ,@c_CountNo AS CountNo
         ,@c_VarFor AS VarFor     
    FROM CCDetail WITH (NOLOCK)  
         LEFT JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CCDetail.StorerKey )    
         LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
   AND   CCDetail.Qty_cnt2 <> CCDetail.Qty
   AND   CCDetail.Qty_cnt2 <> CCDetail.SystemQty  
   AND   @c_VarFor = '4' 


   QUIT:
   IF @c_SValue <> '1'
   BEGIN 
      SELECT     CCKey
               , CCSheetNo
               , CCDetailKey
               , TagNo
               , Storerkey
               , Sku
               , Lot
               , ID
               , SystemQty
               , CountQty
               , Lottable01
               , Lottable02
               , Lottable03
               , Lottable04
               , Lottable05
               , FinalizeFlag
               , Company
               , Descr
               , PackKey
               , CaseCnt
               , InnerPack
               , AreaKey
               , Facility
               , PutawayZone
               , LocLevel
               , CCLogicalLoc
               , LocAisle
               , Loc
               , CountNo
               , VarFor
               , @c_SValue
      FROM #Var_Data
      ORDER BY CCSheetNo
            ,  TagNo
            ,  LocAisle
            ,  LocLevel
            ,  CCLogicalLoc
            ,  Loc
   END 
   ELSE
   BEGIN

      INSERT INTO #Var_Data (
                    CCKey
                  , CCSheetNo
                  , CCDetailKey
                  , TagNo
                  , Storerkey
                  , Sku
                  , Lot
                  , ID
                  , SystemQty
                  , CountQty
                  , Lottable01
                  , Lottable02
                  , Lottable03
                  , Lottable04
                  , Lottable05
                  , FinalizeFlag
                  , Company
                  , Descr
                  , PackKey
                  , CaseCnt
                  , InnerPack
                  , AreaKey
                  , Facility
                  , PutawayZone
                  , LocLevel
                  , CCLogicalLoc
                  , LocAisle
                  , Loc
                  , CountNo
                  , VarFor )

      SELECT CCDetail.CCKey  
            ,CCDetail.CCSheetNo    
            ,CCDetail.CCDetailKey    
            ,CCDetail.TagNo  
            ,CCDetail.Storerkey   
            ,CCDetail.Sku    
            ,CCDetail.Lot   
            ,CCDetail.Id   
            ,CCDetail.SystemQty   
            ,CASE @c_CountNo 
               WHEN '0' THEN CCDetail.SystemQty 
               WHEN '1' THEN CCDetail.Qty 
               WHEN '2' THEN CCDETAIL.Qty_Cnt2 
               WHEN '3' THEN CCDETAIL.Qty_CNt3 
             END AS CountQty  
            ,CASE @c_CountNo 
               WHEN '0' THEN CCDetail.Lottable01
               WHEN '1' THEN CCDetail.Lottable01
               WHEN '2' THEN CCDetail.Lottable01_Cnt2
               WHEN '3' THEN CCDetail.Lottable01_Cnt3
             END As Lottable01   
            ,CASE @c_CountNo 
               WHEN '0' THEN CCDetail.Lottable02
               WHEN '1' THEN CCDetail.Lottable02
               WHEN '2' THEN CCDetail.Lottable02_Cnt2
               WHEN '3' THEN CCDetail.Lottable02_Cnt3
             END As Lottable02  
            ,CASE @c_CountNo 
               WHEN '0' THEN CCDetail.Lottable03
               WHEN '1' THEN CCDetail.Lottable03
               WHEN '2' THEN CCDetail.Lottable03_Cnt2
               WHEN '3' THEN CCDetail.Lottable03_Cnt3
             END As Lottable03  
            ,CASE @c_CountNo 
               WHEN '0' THEN CCDetail.Lottable04
               WHEN '1' THEN CCDetail.Lottable04
               WHEN '2' THEN CCDetail.Lottable04_Cnt2
               WHEN '3' THEN CCDetail.Lottable04_Cnt3
             END As Lottable04
            ,CCDetail.Lottable05  
            ,CCDetail.FinalizeFlag
            ,STORER.Company
            ,SKU.Descr
            ,PACK.PackKey 
            ,PACK.CaseCnt  
            ,PACK.InnerPack  
            ,AreaDetail.AreaKey
            ,LOC.Facility  
            ,LOC.PutawayZone  
            ,LOC.LocLevel 
            ,LOC.CCLogicalLoc  
            ,LOC.LocAisle  
            ,LOC.Loc
            ,@c_CountNo AS CountNo
            ,@c_VarFor AS VarFor     
      FROM #Var_Data tmp
      JOIN CCDetail WITH (NOLOCK) ON (CCDetail.Loc = tmp.Loc)
      LEFT JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CCDetail.StorerKey )    
      LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
      LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
      JOIN LOC WITH (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
      LEFT OUTER JOIN AreaDetail WITH (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
      WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCkey_End
      AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
      AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
      AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
      AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
      AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
      AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
      AND   CCDetail.Qty = CCDetail.SystemQty 
      AND   @c_VarFor = '1' 

      SELECT  CCKey
            , CCSheetNo
            , ''  AS CCDetailKey
            , ''  AS TagNo
            , Storerkey
            , Sku
            , '' AS Lot
            , ID
            , SUM(SystemQty) AS SystemQty
            , SUM(CountQty)  AS CountQty
            , '' AS Lottable01
            , Lottable02
            , '' AS Lottable03
            , Lottable04
            , CONVERT(DATETIME,'1900-01-01') AS Lottable05
            , FinalizeFlag
            , Company
            , Descr
            , PackKey
            , CaseCnt
            , InnerPack
            , AreaKey
            , Facility
            , PutawayZone
            , LocLevel
            , CCLogicalLoc
            , LocAisle
            , Loc
            , CountNo
            , VarFor
            , @c_SValue
      FROM #Var_Data
      GROUP BY CCKey
            , CCSheetNo
            , Storerkey
            , Sku
            --, Lot
            , ID
            --, Lottable01
            , Lottable02
            --, Lottable03
            , Lottable04
            --, Lottable05
            , FinalizeFlag
            , Company
            , Descr
            , PackKey
            , CaseCnt
            , InnerPack
            , AreaKey
            , Facility
            , PutawayZone
            , LocLevel
            , CCLogicalLoc
            , LocAisle
            , Loc
            , CountNo
            , VarFor 
      ORDER BY CCSheetNo
            , ID
            , LocAisle
            , LocLevel
            , CCLogicalLoc
            , Loc
   END
   DROP TABLE #Var_Data      
END

GO