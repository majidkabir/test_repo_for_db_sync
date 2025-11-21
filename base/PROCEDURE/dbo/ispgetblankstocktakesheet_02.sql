SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Stored Procedure: ispGetBlankStockTakeSheet_02                       */        
/* Creation Date: 18-Dec-2019                                           */        
/* Copyright: LFL                                                       */        
/* Written by: WLChooi                                                  */        
/*                                                                      */        
/* Purpose: WMS-11524 - [PH] UNILEVER Blank Count Sheet                 */        
/*                                                                      */       
/* Input Parameters:  @c_StockTakeKey, @c_Type                          */         
/*                                                                      */    
/*                                                                      */    
/*                                                                      */      
/* Output Parameters:  None                                             */      
/*                                                                      */      
/* Return Status:  None                                                 */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Local Variables:                                                     */      
/*                                                                      */       
/* Called By: r_dw_blank_countsheet_02                                  */        
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
      
CREATE PROC [dbo].[ispGetBlankStockTakeSheet_02]      
    @c_StockTakeKey  NVARCHAR(10),
    @c_Type          NVARCHAR(10) = ''
      
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
     
   IF @c_Type = 'H1'  
   BEGIN  
      SELECT @c_StockTakeKey 
      GOTO QUIT  
   END      
       
   SELECT CCDetail.CCSheetNo,
          CCDetail.StorerKey,
          Loc=UPPER(CCDetail.Loc),
          LOC.LocAisle,
          LOC.LocLevel,
          CCDetail.cckey,
          StockTakeSheetParameters.facility,
          Storer.Company
   FROM CCDetail (nolock) 
   JOIN StockTakeSheetParameters (NOLOCK) ON ( CCDetail.CCKEY = StockTakeSheetParameters.StockTakeKey)     
   LEFT OUTER JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
   LEFT OUTER JOIN Storer (nolock) ON ( CCDetail.Storerkey = Storer.Storerkey )
   WHERE ( CCDETAIL.CCKEY = @c_StockTakeKey ) 
   GROUP BY CCDetail.CCSheetNo,
            CCDetail.StorerKey,
            UPPER(CCDetail.Loc),
            LOC.LocAisle,
            LOC.LocLevel,         
            CASE StockTakeSheetParameters.BlankCSheetHideLoc
               WHEN 'Y' THEN CCDetail.CCDetailkey
               ELSE ''
            END,
            CASE StockTakeSheetParameters.BlankCSheetLineByMaxPLT
              WHEN 'Y' THEN CCDetail.CCDetailkey
              ELSE ''
            END,
            CCDetail.CCKey,
            StockTakeSheetParameters.facility,
            Storer.Company    

   QUIT:      
            
END


GO