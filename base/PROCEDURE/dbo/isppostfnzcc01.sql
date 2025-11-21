SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPostGenCC01                                          */
/* Creation Date: 2021-11-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-18332 - [TW]LOR_CycleCount_CR                           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-11-12  Wan      1.0   Created.                                  */
/* 2021-11-12  Wan      1.0   DevOps Combine Script.                    */
/************************************************************************/
CREATE PROC [dbo].[ispPostFnzCC01]
           @c_StockTakeKey NVARCHAR(10)
         , @n_CountNo      INT
         , @b_Success      INT = 1              OUTPUT
         , @n_Err          INT = 0              OUTPUT
         , @c_ErrMsg       NVARCHAR(255) = ''   OUTPUT        
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
            
         , @c_Loc             NVARCHAR(10)  = ''

         , @CUR_LOC           CURSOR
   
   IF @n_CountNo <> 1
   BEGIN
      GOTO QUIT_SP
   END
       
   BEGIN TRAN  
       
   SET @CUR_LOC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT cd.Loc
   FROM dbo.CCDetail AS cd WITH (NOLOCK) 
   WHERE cd.CCKey = @c_StockTakeKey 
   AND cd.FinalizeFlag = 'Y'   
   GROUP BY cd.Loc  
   ORDER BY cd.Loc 
   
   OPEN @CUR_LOC
   
   FETCH NEXT FROM @CUR_LOC INTO @c_Loc 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS (
                  SELECT 1 FROM dbo.INVENTORYHOLD AS i WITH (NOLOCK) 
                  WHERE i.Loc =  @c_Loc
                  AND i.Remark=  @c_StockTakeKey
                  AND i.Hold = '1'
                  )
      BEGIN
         EXEC nspInventoryHoldWrapper    
                  @c_Lot         = ''              -- lot    
               ,  @c_Loc         = @c_Loc          -- loc    
               ,  @c_ID          = ''              -- id    
               ,  @c_StorerKey   = ''              -- storerkey    
               ,  @c_SKU         = ''              -- sku    
               ,  @c_Lottable01  = ''              -- lottable01    
               ,  @c_Lottable02  = ''              -- lottable02    
               ,  @c_Lottable03  = ''              -- lottable03    
               ,  @dt_Lottable04 = '1900-01-01'    -- lottable04    
               ,  @dt_Lottable05 = '1900-01-01'    -- lottable05    
               ,  @c_Lottable06  = ''              -- lottable06    
               ,  @c_Lottable07  = ''              -- lottable07    
               ,  @c_Lottable08  = ''              -- lottable08    
               ,  @c_Lottable09  = ''              -- lottable09    
               ,  @c_Lottable10  = ''              -- lottable10    
               ,  @c_Lottable11  = ''              -- lottable11    
               ,  @c_Lottable12  = ''              -- lottable12    
               ,  @dt_Lottable13 = '1900-01-01'    -- lottable13    
               ,  @dt_Lottable14 = '1900-01-01'    -- lottable14     
               ,  @dt_Lottable15 = '1900-01-01'    -- lottable15     
               ,  @c_Status      = 'CCHold'
               ,  @c_Hold        = '0'
               ,  @b_success     = @b_success   OUTPUT  
               ,  @n_Err         = @n_Err       OUTPUT  
               ,  @c_Errmsg      = @c_Errmsg    OUTPUT  
               ,  @c_Remark      = @c_StockTakeKey 
              
         IF @b_success = 0 
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END 
      END              
      FETCH NEXT FROM @CUR_LOC INTO @c_Loc   
   END
   CLOSE @CUR_LOC
   DEALLOCATE @CUR_LOC
   
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPostFnzCC01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO