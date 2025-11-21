SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Inventoryhold_Wrapper                          */  
/* Creation Date: 06-Apr-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Inventory hold                                              */  
/*                                                                      */  
/* Called By: Inventory hold screen                                     */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2020-11-30  Wan01    1.1   Add Big Outer Begin Try..End Try to enable*/
/*                            Revert when Raise error                   */
/* 2021-01-15  Wan02    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Inventoryhold_Wrapper]
     @c_StorerKey   NVARCHAR(15)
    ,@c_SKU         NVARCHAR(20)
    ,@c_lot         NVARCHAR(10)
    ,@c_Loc         NVARCHAR(10)
    ,@c_ID          NVARCHAR(18)
    ,@c_lottable01  NVARCHAR(18)
    ,@c_lottable02  NVARCHAR(18)
    ,@c_lottable03  NVARCHAR(18) 
    ,@dt_lottable04 DATETIME
    ,@dt_lottable05 DATETIME 
    ,@c_lottable06  NVARCHAR(30)
    ,@c_lottable07  NVARCHAR(30)
    ,@c_lottable08  NVARCHAR(30)
    ,@c_lottable09  NVARCHAR(30)
    ,@c_lottable10  NVARCHAR(30)
    ,@c_lottable11  NVARCHAR(30)
    ,@c_lottable12  NVARCHAR(30)
    ,@dt_lottable13 DATETIME
    ,@dt_lottable14 DATETIME
    ,@dt_lottable15 DATETIME
    ,@c_Status      NVARCHAR(10)
    ,@c_Hold        CHAR(1)
    ,@c_Remark      NVARCHAR(255)
   ,@b_Success     INT = 1 OUTPUT 
   ,@n_Err         INT = 0 OUTPUT
   ,@c_ErrMsg      NVARCHAR(250) = '' OUTPUT
   ,@c_UserName    NVARCHAR(128) = ''
AS
BEGIN 
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF
    
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                   --(Wan02) - END
    
        
    DECLARE @n_Continue              INT
           ,@n_starttcnt             INT

    SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1

    BEGIN TRY     --(Wan01) - START
       IF @n_continue IN(1,2)
       BEGIN      
          SET @c_Lottable01 = ISNULL(@c_Lottable01,'')
          SET @c_Lottable02 = ISNULL(@c_Lottable02,'')
          SET @c_Lottable03 = ISNULL(@c_Lottable03,'')
          IF @dt_Lottable04 IS NULL
             SET @dt_Lottable04 = CONVERT(DATETIME, '1900-01-01')
          IF @dt_Lottable05 IS NULL
             SET @dt_Lottable05 = CONVERT(DATETIME, '1900-01-01')
          SET @c_Lottable06 = ISNULL(@c_Lottable06,'')
          SET @c_Lottable07 = ISNULL(@c_Lottable07,'')
          SET @c_Lottable08 = ISNULL(@c_Lottable08,'')
          SET @c_Lottable09 = ISNULL(@c_Lottable09,'')
          SET @c_Lottable10 = ISNULL(@c_Lottable10,'')
          SET @c_Lottable11 = ISNULL(@c_Lottable11,'')
          SET @c_Lottable12 = ISNULL(@c_Lottable12,'')
          IF @dt_Lottable13 IS NULL
             SET @dt_Lottable13 = CONVERT(DATETIME, '1900-01-01')
          IF @dt_Lottable14 IS NULL
             SET @dt_Lottable14 = CONVERT(DATETIME, '1900-01-01')
          IF @dt_Lottable15 IS NULL
             SET @dt_Lottable15 = CONVERT(DATETIME, '1900-01-01')
          SET @c_Storerkey = ISNULL(@c_Storerkey,'')
          SET @c_Sku = ISNULL(@c_Sku,'')
          IF @c_Lot = ''
             SET @c_Lot = NULL
          IF @c_Loc = ''
             SET @c_Loc = NULL
          IF @c_Id = ''
             SET @c_Id = NULL
          SET @c_Remark = REPLACE(@c_Remark,'''','"')
       
          BEGIN TRY
             EXECUTE dbo.nspInventoryHoldResultSet 
                 @c_lot = @c_Lot, 
                 @c_Loc = @c_Loc, 
                 @c_ID = @c_ID ,
                  @c_StorerKey = @c_Storerkey, 
                  @c_SKU = @c_Sku, 
                  @c_lottable01 = @c_Lottable01, 
                  @c_lottable02 = @c_Lottable02, 
                  @c_lottable03 = @c_Lottable03, 
                  @dt_lottable04 = @dt_Lottable04,
                  @dt_lottable05 = @dt_Lottable05, 
                  @c_lottable06 = @c_Lottable06, 
                  @c_lottable07 = @c_Lottable07, 
                  @c_lottable08 = @c_Lottable08,
                  @c_lottable09 = @c_Lottable09, 
                  @c_lottable10 = @c_Lottable10, 
                  @c_lottable11 = @c_Lottable11,
                  @c_lottable12 = @c_Lottable12,
                  @dt_lottable13 = @dt_Lottable13,
                  @dt_lottable14 = @dt_Lottable14,
                  @dt_lottable15 = @dt_Lottable15,
                  @c_Status = @c_Status, 
                  @c_Hold = @c_Hold, 
                  @b_Success = @b_Success OUTPUT,
                  @n_err = @n_err OUTPUT, 
                  @c_errmsg = @c_errmsg OUTPUT, 
                  @c_remark = @c_Remark                  

             IF @b_success <> 1
             BEGIN
                SELECT @n_continue = 3  
             END       
           END TRY
          BEGIN CATCH
             IF @n_err = 0 
             BEGIN
                 SET @n_continue = 3
                 SELECT @n_err = ERROR_NUMBER(), 
                        @c_ErrMsg = ERROR_MESSAGE()
             END
          END CATCH                
        END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Inventory Hold fail. (lsp_Inventoryhold_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH   --(Wan01) - END
      
   EXIT_SP: 
   --REVERT    --(Wan01)
    
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Inventoryhold_Wrapper'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      --RETURN --(Wan01) to Revert 
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      --RETURN --(Wan01) to Revert
   END
   REVERT             
END

GO