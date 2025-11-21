SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Store Procedure:  ispPopulateStkTakeCount                            */  
/* Creation Date: 28-Dec-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose:  Pupulate Count from 1 to another                           */  
/*                                                                      */  
/* Called By:  PowerBuilder                                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 01-Mar-2011  Shong     Skip Count 2 If System Qty = Counted Qty      */  
/* 27-May-2014  TKLIM     Added Lottables 06-15                         */
/* 13-Apr-2021  NJOW01    Fix retrieve storerkey and facility           */
/* 19-Oct-2022  NJOW02    Fix OnlyCountLocWithVariance for popoulate    */
/*                        count 3                                       */
/* 19/10/2022   NJOW03    WMS-20991 TH Finalize stocktake by count sheet*/
/* 19/10/2022   NJOW03    DEVOPS Combine script                         */
/* 08/06/2023   JIHHAUR01 JSM-155038 3rd Cycle Count not exclude Variance*/  
/* 08-JUN-2024  CLVN01    INC6952977 Update Qty_Cnt2 & Qty_Cnt3 = 0 if   */  
/*                        SystemQty <> PreviousCount                     */  
/*************************************************************************/    
  
CREATE   PROCEDURE [dbo].[ispPopulateStkTakeCount]  
      @c_StockTakeKey NVARCHAR(10),   
      @n_CountNo INT,
      @c_CountSheets NVARCHAR(MAX) = ''  --NJOW03  
AS  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue  INT,   
           @c_StorerKey NVARCHAR(15),   
           @c_Facility  NVARCHAR(5),  
           @c_OnlyCountLocWithVariance NVARCHAR(1),   
           @b_Success   INT,  
           @n_ErrNo     INT,  
           @c_ErrMsg    NVARCHAR(215),
           @c_StockTakeFinalizeByCountSheet NVARCHAR(30), --NJOW03
           @c_AllCSheetPopulated NVARCHAR(5), --NJOW03            
           @c_CCSheetNo NVARCHAR(10), --NJOW03  
           @c_ResetCntQtyIfVariance NVARCHAR(1) --CLVN01  
                                           
   SET @c_AllCSheetPopulated = 'Y'  --NJOW03

   SELECT @n_Continue = 1  
  
   -- Do nothing is count no no equal 2 and 3  
   IF @n_CountNo <> 2 AND @n_CountNo <> 3   
      SELECT @n_Continue = 4  
  
   IF OBJECT_ID('tempdb..#RECNT_LOC') IS NOT NULL  
      DROP TABLE #RECNT_LOC  
   
   CREATE TABLE #RECNT_LOC (LOC NVARCHAR(10))    
     
   IF OBJECT_ID('tempdb..#RECNT_LINE') IS NOT NULL  --CLVN01  
   DROP TABLE #RECNT_LINE                           --CLVN01  
     
   CREATE TABLE #RECNT_LINE (LOC NVARCHAR(10))      --CLVN01  
    
   SELECT TOP 1     
      @c_StorerKey = CCDETAIL.StorerKey,   
      @c_Facility  = LOC.Facility     
   FROM CCDETAIL WITH (NOLOCK)      
   JOIN LOC WITH (NOLOCK) ON CCDETAIL.LOC = LOC.LOC    --NJOW01
   WHERE CCDETAIL.CCKEY = @c_StockTakeKey   
     AND CCDETAIL.StorerKey > ''   
     AND CCDETAIL.LOC > ''    
        
   SET @c_OnlyCountLocWithVariance = '0'  
   EXEC nspGetRight    
         @c_Facility   = @c_Facility ,     
         @c_StorerKey  = @c_StorerKey,     
         @c_sku        = '',     
         @c_ConfigKey  = 'SkipCountLocWithZeroVariance',     
         @b_Success    = @b_Success OUTPUT,     
         @c_authority  = @c_OnlyCountLocWithVariance  OUTPUT,     
         @n_err        = @n_ErrNo   OUTPUT,    
         @c_errmsg     = @c_ErrMsg  OUTPUT    

   --NJOW03
   SET @c_StockTakeFinalizeByCountSheet = ''  
   EXEC nspGetRight    
         @c_Facility   = @c_Facility ,     
         @c_StorerKey  = @c_StorerKey,     
         @c_sku        = '',     
         @c_ConfigKey  = 'StockTakeFinalizeByCountSheet',     
         @b_Success    = @b_Success OUTPUT,     
         @c_authority  = @c_StockTakeFinalizeByCountSheet  OUTPUT,     
         @n_err        = @n_ErrNo   OUTPUT,    
         @c_errmsg     = @c_ErrMsg  OUTPUT    
       
    --CLVN01  
    SET @c_ResetCntQtyIfVariance = ''  
    EXEC nspGetRight      
         @c_Facility   = @c_Facility ,       
         @c_StorerKey  = @c_StorerKey,       
         @c_sku        = '',       
         @c_ConfigKey  = 'ResetCntQtyIfVariance',       
         @b_Success    = @b_Success OUTPUT,       
         @c_authority  = @c_ResetCntQtyIfVariance  OUTPUT,       
         @n_err        = @n_ErrNo   OUTPUT,      
         @c_errmsg     = @c_ErrMsg  OUTPUT    

   IF @n_CountNo = 2  
   BEGIN  
   	  IF @c_StockTakeFinalizeByCountSheet = '1'  --NJOW03
   	  BEGIN
   	     SELECT TOP 1 @c_CCSheetNo = CCSheetNo
   	     FROM CCDETAIL (NOLOCK)
   	     WHERE FinalizeFlag <> 'Y'
   	     AND CCKey = @c_StockTakeKey 
   	     AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))   	
   	     ORDER BY CCSheetNo   
   	     
   	     IF ISNULL(@c_CCSheetNo,'') <> ''
   	     BEGIN
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = 'Populate Count 2 is Not Allowed. Count Sheet ''' + RTRIM(@c_CCSheetNo) + ''' Not Yet Finalize. (ispPopulateStkTakeCount).'
            RAISERROR (@c_ErrMsg, 16, 1)  
            RETURN
         END     	       
   	  END
   	  
      BEGIN TRAN  

      UPDATE CCDETAIL  
         SET Qty_Cnt2 = Qty, 
             Lottable01_Cnt2 = ISNULL(Lottable01, ''),  
             Lottable02_Cnt2 = ISNULL(Lottable02, ''),  
             Lottable03_Cnt2 = ISNULL(Lottable03, ''),  
             Lottable04_Cnt2 = Lottable04,  
             Lottable05_Cnt2 = Lottable05,
             Lottable06_Cnt2 = ISNULL(Lottable06, ''),
             Lottable07_Cnt2 = ISNULL(Lottable07, ''),
             Lottable08_Cnt2 = ISNULL(Lottable08, ''),
             Lottable09_Cnt2 = ISNULL(Lottable09, ''),
             Lottable10_Cnt2 = ISNULL(Lottable10, ''),
             Lottable11_Cnt2 = ISNULL(Lottable11, ''),
             Lottable12_Cnt2 = ISNULL(Lottable12, ''),
             Lottable13_Cnt2 = Lottable13,      
             Lottable14_Cnt2 = Lottable14,
             Lottable15_Cnt2 = Lottable15
      WHERE CCKEY = @c_StockTakeKey  
      AND (CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
           OR @c_StockTakeFinalizeByCountSheet <> '1')
      
      IF @@ERROR <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         RAISERROR ('Error Found Populate Stock Take ispPopulateStkTakeCount.', 16, 1)  
         ROLLBACK TRAN  
         RETURN  
      END  
      ELSE  
         COMMIT TRAN  
  
      IF @c_OnlyCountLocWithVariance = '1'  
      BEGIN  
         INSERT INTO #RECNT_LOC        
         SELECT DISTINCT c.LOC   
         FROM CCDetail c WITH (NOLOCK)   
         WHERE CCKEY = @c_StockTakeKey   
         AND (CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
             OR @c_StockTakeFinalizeByCountSheet <> '1')
               
         GROUP BY c.StorerKey, c.Sku, c.LOC, 
                  c.Lottable01, c.Lottable02, c.Lottable03, c.Lottable04,
                  c.Lottable06, c.Lottable07, c.Lottable08, c.Lottable09, c.Lottable10, 
                  c.Lottable11, c.Lottable12, c.Lottable13, c.Lottable14, c.Lottable15
         HAVING SUM(c.SystemQty - C.Qty) <> 0   

         BEGIN TRAN                  
         UPDATE CC   
         SET Counted_Cnt2='1', EditDate_Cnt2 = GETDATE(), EditWho_Cnt2 = 'IC_SKIP'  
         FROM CCDETAIL CC   
         WHERE CC.Counted_Cnt2 = '0'  
            AND CC.CCKEY = @c_StockTakeKey
            AND NOT EXISTS(SELECT 1 FROM #RECNT_LOC SLOC WHERE SLOC.LOC = CC.LOC)     
         AND (CC.CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
           OR @c_StockTakeFinalizeByCountSheet <> '1')
       
         --CLVN01 START--  
         IF @c_ResetCntQtyIfVariance = '1'  
         BEGIN  
     	 
           INSERT INTO #RECNT_LINE          
           SELECT DISTINCT LOC     
           FROM CCDetail WITH (NOLOCK)     
           WHERE CCKEY = @c_StockTakeKey     
           AND SYSTEMQTY <> QTY  
     	 
           UPDATE CCDETAIL SET QTY_CNT2 = '0'  
           WHERE CCKEY = @c_StockTakeKey  
           AND LOC IN (SELECT LOC FROM #RECNT_LINE)  
		   
         END       
         --CLVN01 END--  
                     
       IF @@ERROR <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          RAISERROR ('Update CCDETAIL Failed - ispPopulateStkTakeCount.', 16, 1)  
          ROLLBACK TRAN  
          RETURN  
       END  
       ELSE  
         COMMIT TRAN    
      END         
      
      IF @c_StockTakeFinalizeByCountSheet = '1' --NJOW03
      BEGIN
         IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK) 
                   WHERE CCKEY = @c_StockTakeKey
                   GROUP BY CCSheetNo 
                   HAVING SUM(Qty_Cnt2) = 0)
         BEGIN              
            SET @c_AllCSheetPopulated = 'N'
         END
      END              
   END  
   ELSE IF @n_CountNo = 3  
   BEGIN  
   	  IF @c_StockTakeFinalizeByCountSheet = '1'  --NJOW03 
   	  BEGIN
   	     SELECT TOP 1 @c_CCSheetNo = CCSheetNo
   	     FROM CCDETAIL (NOLOCK)
   	     WHERE FinalizeFlag_Cnt2 <> 'Y'
   	     AND CCKey = @c_StockTakeKey 
   	     AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))   	   
   	     ORDER BY CCSheetNo
   	     
   	     IF ISNULL(@c_CCSheetNo,'') <> ''
   	     BEGIN
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = 'Populate Count 3 is Not Allowed. Count Sheet ''' + RTRIM(@c_CCSheetNo) + ''' Not Yet Finalize. (ispPopulateStkTakeCount).'
            RAISERROR (@c_ErrMsg, 16, 1)  
            RETURN
         END     	       
   	  END
   	
      BEGIN TRAN  
  
      UPDATE CCDETAIL  
         SET Qty_Cnt3 = Qty_Cnt2,  
             Lottable01_Cnt3 = ISNULL(Lottable01_Cnt2, ''),  
             Lottable02_Cnt3 = ISNULL(Lottable02_Cnt2, ''),  
             Lottable03_Cnt3 = ISNULL(Lottable03_Cnt2, ''),  
             Lottable04_Cnt3 = Lottable04_Cnt2,  
             Lottable05_Cnt3 = Lottable05_Cnt2,
             Lottable06_Cnt3 = ISNULL(Lottable06_Cnt2, ''),  
             Lottable07_Cnt3 = ISNULL(Lottable07_Cnt2, ''),  
             Lottable08_Cnt3 = ISNULL(Lottable08_Cnt2, ''),  
             Lottable09_Cnt3 = ISNULL(Lottable09_Cnt2, ''),  
             Lottable10_Cnt3 = ISNULL(Lottable10_Cnt2, ''),  
             Lottable11_Cnt3 = ISNULL(Lottable11_Cnt2, ''),  
             Lottable12_Cnt3 = ISNULL(Lottable12_Cnt2, ''),  
             Lottable13_Cnt3 = Lottable13_Cnt2,  
             Lottable14_Cnt3 = Lottable14_Cnt2,  
             Lottable15_Cnt3 = Lottable15_Cnt2  
      WHERE CCKEY = @c_StockTakeKey
      AND (CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
           OR @c_StockTakeFinalizeByCountSheet <> '1')
      
      
      IF @@ERROR <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         RAISERROR ('Error Found Populate Stock Take ispPopulateStkTakeCount.', 16, 1)  
         ROLLBACK TRAN  
         RETURN  
      END  
      ELSE  
         COMMIT TRAN  
  
      IF @c_OnlyCountLocWithVariance = '1'  
      BEGIN  
         INSERT INTO #RECNT_LOC        
         SELECT DISTINCT c.LOC   
         FROM CCDetail c WITH (NOLOCK)   
         WHERE CCKEY = @c_StockTakeKey   
         AND (CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
              OR @c_StockTakeFinalizeByCountSheet <> '1')               
         GROUP BY c.StorerKey, c.Sku, c.LOC, 
                  c.Lottable01, c.Lottable02, c.Lottable03,  c.Lottable04,
                  c.Lottable06, c.Lottable07, c.Lottable08, c.Lottable09, c.Lottable10, 
                  c.Lottable11, c.Lottable12, c.Lottable13, c.Lottable14, c.Lottable15
         HAVING SUM(c.SystemQty - C.Qty_Cnt2) <> 0     /*JIHHAUR01*/  
         /*UNION  --NJOW02  --JIHHAUR01  
         SELECT DISTINCT c.LOC       
         FROM CCDetail c WITH (NOLOCK)       
         WHERE CCKEY = @c_StockTakeKey               
         AND (CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03    
              OR @c_StockTakeFinalizeByCountSheet <> '1')                    
         AND c.EditWho_Cnt2 = 'IC_SKIP'     */        /*JIHHAUR01*/        

         BEGIN TRAN                  
         UPDATE CC   
         SET Counted_Cnt3='1', EditDate_Cnt3 = GETDATE(), EditWho_Cnt3 = 'IC_SKIP'  
         FROM CCDETAIL CC       
         WHERE CC.Counted_Cnt3 = '0'  
         AND CC.CCKEY = @c_StockTakeKey 
         AND NOT EXISTS(SELECT 1 FROM #RECNT_LOC SLOC WHERE SLOC.LOC = CC.LOC)    
         AND (CC.CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
              OR @c_StockTakeFinalizeByCountSheet <> '1')
               
         --CLVN01 START--  
         IF @c_ResetCntQtyIfVariance = '1'  
         BEGIN  
     
           INSERT INTO #RECNT_LINE          
           SELECT DISTINCT LOC     
           FROM CCDetail WITH (NOLOCK)     
           WHERE CCKEY = @c_StockTakeKey     
           AND SYSTEMQTY <> QTY_CNT2  
     
           UPDATE CCDETAIL SET QTY_CNT3 = '0'  
           WHERE CCKEY = @c_StockTakeKey  
           AND LOC IN (SELECT LOC FROM #RECNT_LINE) 
		   
         END      
         --CLVN01 END--  
         
         IF @@ERROR <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            RAISERROR ('Update CCDETAIL Failed - ispPopulateStkTakeCount.', 16, 1)  
            ROLLBACK TRAN  
            RETURN  
         END  
         ELSE  
            COMMIT TRAN  
      END   
      
      IF @c_StockTakeFinalizeByCountSheet = '1' --NJOW03
      BEGIN
         IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK) 
                   WHERE CCKEY = @c_StockTakeKey
                   GROUP BY CCSheetNo 
                   HAVING SUM(Qty_Cnt3) = 0)
         BEGIN              
            SET @c_AllCSheetPopulated = 'N'
         END
      END                    
   END   
  
   IF (@n_continue = 1 OR @n_continue = 2)
      AND @c_AllCSheetPopulated = 'Y'  --NJOW03
   BEGIN  
      BEGIN TRAN  
  
      UPDATE StockTakeSheetParameters  
      SET PopulateStage = @n_CountNo  
      WHERE StockTakeKey = @c_StockTakeKey  
    
      IF @@ERROR <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         RAISERROR ('Error Found when updaing StockTakeSheetParameters.', 16, 1)  
         ROLLBACK TRAN  
         RETURN  
      END  
      ELSE  
         COMMIT TRAN  
   END     


GO