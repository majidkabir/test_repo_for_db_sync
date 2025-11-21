SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGetStockTakeSheet_ph_08                         */  
/* Creation Date: 07-JAN-2021                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHO                                                    */  
/*                                                                      */  
/* Purpose: WMS-15942 [PH] - Adidas Ecom - Cycle Count Sheet            */  
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
/* Called By: r_dw_stocktake_ph_08                                      */  
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

CREATE PROC [dbo].[ispGetStockTakeSheet_ph_08] 
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

   CREATE TABLE #Var_STSPH_08 ( 
           CCKey        NVARCHAR(10)   NULL  
         , CCSheetNo    NVARCHAR(10)    NULL    
         , Storerkey    NVARCHAR(15)    NULL
         , Sku          NVARCHAR(20)    NULL
         , SystemQty    INT             NULL
         , Style        NVARCHAR(20)    NULL
         , SDescr       NVARCHAR(120)   NULL
         , CCDID        NVARCHAR(18)    NULL
         , Hostwhcode   NVARCHAR(20)    NULL
         , STCompany    NVARCHAR(45)    NULL
         , Loc          NVARCHAR(10)    NULL
         , Addwho       NVARCHAR(256)   NULL
         , Facility     NVARCHAR(10)    NULL  
         , CCAddDate    NVARCHAR(11)    NULL    )

   SELECT @c_Storerkey = ISNULL(RTRIM(Storerkey),'') 
   FROM StockTakeSheetParameters WITH (NOLOCK)
   WHERE StockTakeKey = @c_CCkey_Start

   --EXECUTE dbo.nspGetRight NULL                 -- facility
   --                     ,  @c_Storerkey         -- Storerkey
   --                     ,  NULL                 -- Sku
   --                     ,  @c_Configkey         -- Configkey
   --                     ,  @b_success      OUTPUT
   --                     ,  @c_SValue       OUTPUT
   --                     ,  @n_err          OUTPUT
   --                     ,  @c_errmsg       OUTPUT
   --IF @b_success <> 1  
   --BEGIN  
   --   SET @n_continue = 3 
   --   SET @n_Err = 31301
   --   SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err) 
   --                 + ': Error Getting StorerCongfig for Storer: ' + RTRIM(@c_Storerkey)
   --                 + '. (ispGetStockTakeSheet_08)' 
   --   GOTO QUIT
   --END 

   INSERT INTO #Var_STSPH_08 (
                 CCKey
               , CCSheetNo              
               , Storerkey
               , Sku
               , SystemQty
               , Style
               , SDescr
               , CCDID
               , Hostwhcode
               , STCompany
               , Loc
               , Addwho
               , Facility
               , CCAddDate )
   SELECT DISTINCT CCDetail.CCKey,   
         CCDetail.CCSheetNo,     
         CCDetail.Storerkey,   
         CCdetail.SKU,        
         CCdetail.SystemQty  as SystemQty,  
         SKU.Style,
         SKU.DESCR,
         CCDETAIL.id,  
         LOC.Hostwhcode AS Hostwhcode,  
         ST.Company,    
         CCDetail.Loc,  
         CCDetail.Addwho,
         LOC.Facility,
         REPLACE(CONVERT(NVARCHAR(11),CCDetail.AddDate,106),' ' ,'-')        
    FROM CCDetail (NOLOCK) --ON CCDetail.cckey = CC.CCKey   
         JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = CCDetail.Storerkey
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
         CCdetail.SKU,        
         CCdetail.SystemQty  as SystemQty,  
         '' as style,
         '' as sdescr,
         CCDETAIL.id,  
         LOC.Hostwhcode AS Hostwhcode,  
         '' as STCompany,    
         CCDetail.Loc,  
         CCDetail.Addwho,
         LOC.Facility,
         REPLACE(CONVERT(NVARCHAR(11),CCDetail.AddDate,106),' ' ,'-')      
    FROM CCDetail (NOLOCK)   
   -- JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )      
    JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
  -- JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = CCDetail.Storerkey
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
               , SUM(SystemQty) as SystemQty
               , Style
               , SDescr
               , CCDID
               , Hostwhcode
               , STCompany
               , Loc
               , Addwho
               , Facility
               , CCAddDate
               ,RIGHT('00000' + CAST(ROW_NUMBER() OVER (ORDER BY CCKey,CCSheetNo) as NVARCHAR(5)),5) as LineNum
      FROM #Var_STSPH_08
      GROUP BY   CCKey
               , CCSheetNo              
               , Storerkey
               , Sku
               , Style
               , SDescr
               , CCDID
               , Hostwhcode
               , STCompany
               , Loc
               , Addwho
               , Facility
               , CCAddDate
      ORDER BY   CCKey
               , CCSheetNo 
               
   
   DROP TABLE #Var_STSPH_08      
END

GO