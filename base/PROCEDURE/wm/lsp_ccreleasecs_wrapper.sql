SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_CCReleaseCS_Wrapper                             */  
/* Creation Date: 09-MAR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-310 - Stored Procedures for Release 2 Feature ¿C         */
/*          Inventory  Cycle Count Release Cycle Count                   */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_CCReleaseCS_Wrapper]  
   @c_Storerkey      NVARCHAR(15)
,  @c_Sku            NVARCHAR(20)
,  @c_Loc            NVARCHAR(10)
,  @b_WithQty        BIT          = 0
,  @b_Success        INT          = 1   OUTPUT   
,  @n_Err            INT          = 0   OUTPUT
,  @c_Errmsg         NVARCHAR(255)= ''  OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Count           INT = 0 
         , @c_Facility        NVARCHAR(5)
         , @c_LocAisle        NVARCHAR(10)
         , @c_LocLevel        INT

         , @c_CCkey           NVARCHAR(10) = 'RELEASECC'
         , @c_CCDetailKey     NVARCHAR(10)
         , @c_CCSheetNo       NVARCHAR(10)

         , @c_Lot             NVARCHAR(10)         
         , @c_ID              NVARCHAR(18)
         , @c_Lottable01      NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @d_Lottable04      DATETIME    
         , @d_Lottable05      DATETIME    
         , @c_Lottable06      NVARCHAR(30)
         , @c_Lottable07      NVARCHAR(30)
         , @c_Lottable08      NVARCHAR(30)
         , @c_Lottable09      NVARCHAR(30)
         , @c_Lottable10      NVARCHAR(30)
         , @c_Lottable11      NVARCHAR(30)
         , @c_Lottable12      NVARCHAR(30)
         , @d_Lottable13      DATETIME    
         , @d_Lottable14      DATETIME    
         , @d_Lottable15      DATETIME    
         , @n_Qty             INT

         , @CUR_INV           CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
               @c_UserName = @c_UserName  OUTPUT 
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SET @c_Facility = ''
      SET @c_LocAisle = ''
      SET @c_LocLevel = ''

      SELECT @c_Facility = Facility
         ,   @c_LocAisle = ISNULL(RTRIM(LocAisle),'')
         ,   @c_LocLevel = ISNULL(LocLevel,0) 
      FROM LOC WITH (NOLOCK)
      WHERE Loc = @c_Loc

      SET @n_Count = 0
      SET @c_CCSheetNo = ''
      SELECT @n_Count = 1
            ,@c_CCSheetNo = CCD.CCSheetNo
      FROM CC       CC  WITH (NOLOCK)
      JOIN CCDETAIL CCD WITH (NOLOCK) ON (CC.CCkey = CCD.CCkey)
      JOIN LOC      LOC WITH (NOLOCK) ON (CCD.Loc = LOC.Loc)
      WHERE CC.CCkey = @c_CCKey
      AND LOC.Facility = @c_Facility   
      AND LOC.LocAisle = @c_LocAisle
      AND LOC.LocLevel = @c_LocLevel
      AND CC.Status = '0'

      IF @n_Count = 0
      BEGIN
         -- GEt CCSheetNo
         SET @b_success = 1  
         BEGIN TRY      
            EXECUTE nspg_getkey        
            'CCSheetNo'        
            , 10        
            , @c_CCSheetNo OUTPUT        
            , @b_success   OUTPUT        
            , @n_err       OUTPUT        
            , @c_errmsg    OUTPUT        
         END TRY

         BEGIN CATCH
            SET @n_err = 550401
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspg_getkey - CCSheetNo. (lsp_CCReleaseCS_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    
                   
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END        
      END

      SET @CUR_INV = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Lot
               ,LLI.ID
               ,LLI.Qty
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         WHERE LLI.Storerkey = @c_Storerkey
         AND   LLI.Sku = @c_Sku
         AND   LLI.Loc = @c_Loc
         AND   LLI.Qty > 0
      
      OPEN @CUR_INV

      FETCH NEXT FROM @CUR_INV INTO @c_Lot
                                 ,  @c_ID
                                 ,  @n_Qty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT 
               @c_Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')
            ,  @c_Lottable02 = ISNULL(RTRIM(LA.Lottable02),'')       
            ,  @c_Lottable03 = ISNULL(RTRIM(LA.Lottable03),'')
            ,  @d_Lottable04 = LA.Lottable04
            ,  @d_Lottable05 = LA.Lottable05
            ,  @c_Lottable06 = ISNULL(RTRIM(LA.Lottable06),'')
            ,  @c_Lottable07 = ISNULL(RTRIM(LA.Lottable07),'') 
            ,  @c_Lottable08 = ISNULL(RTRIM(LA.Lottable08),'')
            ,  @c_Lottable09 = ISNULL(RTRIM(LA.Lottable09),'') 
            ,  @c_Lottable10 = ISNULL(RTRIM(LA.Lottable10),'')
            ,  @c_Lottable11 = ISNULL(RTRIM(LA.Lottable11),'') 
            ,  @c_Lottable12 = ISNULL(RTRIM(LA.Lottable12),'')
            ,  @d_Lottable13 = LA.Lottable13 
            ,  @d_Lottable14 = LA.Lottable14
            ,  @d_Lottable15 = LA.Lottable15 
         FROM LOTATTRIBUTE LA WITH (NOLOCK)
         WHERE LA.Lot = @c_Lot

         IF @b_WithQty = 0
         BEGIN
            SET @n_Qty = 0
         END
   
         SET @b_success = 1  
         BEGIN TRY      
            EXECUTE nspg_getkey        
            'CCDetailKey'        
            , 10        
            , @c_CCDetailKey  OUTPUT        
            , @b_success      OUTPUT        
            , @n_err          OUTPUT        
            , @c_errmsg       OUTPUT        
         END TRY

         BEGIN CATCH
            SET @n_err = 550402
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                          + ': Error Executing nspg_getkey - CCDetailKey. (lsp_CCReleaseCS_Wrapper)'
                          + '( ' + @c_errmsg + ' )'
         END CATCH    
                   
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END        

         BEGIN TRY
            INSERT INTO CCDETAIL 
            (  CCKey
            ,  CCDetailKey
            ,  CCSheetNo
            ,  Storerkey
            ,  Sku
            ,  Lot
            ,  Loc
            ,  ID
            ,  Qty
            ,  Lottable01 
            ,  Lottable02 
            ,  Lottable03 
            ,  Lottable04 
            ,  Lottable05 
            ,  Lottable06 
            ,  Lottable07 
            ,  Lottable08 
            ,  Lottable09 
            ,  Lottable10 
            ,  Lottable11 
            ,  Lottable12 
            ,  Lottable13 
            ,  Lottable14 
            ,  Lottable15
            )
            VALUES
            (  @c_CCKey
            ,  @c_CCDetailKey
            ,  @c_CCSheetNo
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @c_Lot
            ,  @c_Loc
            ,  @c_ID
            ,  @n_Qty
            ,  @c_Lottable01 
            ,  @c_Lottable02 
            ,  @c_Lottable03 
            ,  @d_Lottable04 
            ,  @d_Lottable05 
            ,  @c_Lottable06 
            ,  @c_Lottable07 
            ,  @c_Lottable08 
            ,  @c_Lottable09 
            ,  @c_Lottable10 
            ,  @c_Lottable11 
            ,  @c_Lottable12 
            ,  @d_Lottable13 
            ,  @d_Lottable14 
            ,  @d_Lottable15 
            )

         END TRY

         BEGIN CATCH
            SET @n_err = 550403
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Insert Into CCDETAIL Fail. (lsp_CCReleaseCS_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END  
                   
         FETCH NEXT FROM @CUR_INV INTO @c_Lot
                                    ,  @c_ID
                                    ,  @n_Qty
      END
      CLOSE @CUR_INV
      DEALLOCATE @CUR_INV

   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END    
EXIT_SP:
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_CCReleaseCS_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   REVERT      
END  

GO