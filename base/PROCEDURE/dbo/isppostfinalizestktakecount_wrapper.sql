SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPostFinalizeStkTakeCount_Wrapper                     */
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
CREATE PROC [dbo].[ispPostFinalizeStkTakeCount_Wrapper]
           @c_StockTakeKey    NVARCHAR(10)
         , @n_CountNo         INT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         
         ,  @b_Success        INT = 1
         ,  @n_Err            INT = 0
         ,  @c_ErrMsg         NVARCHAR(255) = ''
            
         , @c_Facility        NVARCHAR(5)  = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         
         
         , @c_PostFnzCC_SP    NVARCHAR(30) = ''

         , @c_SQL             NVARCHAR(1000) = ''
         , @c_SQLParm         NVARCHAR(1000) = ''   
               
   SELECT @c_Facility = stsp.Facility
   FROM StockTakeSheetParameters AS stsp WITH (NOLOCK)
   WHERE stsp.StockTakeKey = @c_StockTakeKey
   
   SELECT TOP 1 @c_StorerKey = cd.Storerkey
   FROM dbo.CCDetail AS cd WITH (NOLOCK)
   WHERE cd.CCKey = @c_StockTakeKey
   
   SELECT @c_PostFnzCC_SP = RTRIM(fgr.Authority) 
   FROM dbo.fnc_GetRight2(@c_Facility, @c_StorerKey, '', 'PostFinalizeCycleCount_SP') AS fgr
      
   IF NOT EXISTS (SELECT 1 FROM sysobjects WHERE id = OBJECT_ID(@c_PostFnzCC_SP) AND TYPE = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_SQL = N'EXECUTE ' + @c_PostFnzCC_SP       
              + '  @c_StockTakeKey= @c_StockTakeKey '  
              + ', @n_CountNo     = @n_CountNo '  
              + ', @b_Success     = @b_Success     OUTPUT '  
              + ', @n_Err         = @n_Err         OUTPUT '
              + ', @c_ErrMsg      = @c_ErrMsg      OUTPUT '    
  
   SET @c_SQLParm = N'@c_StockTakeKey     NVARCHAR(10)'
                  + ',@n_CountNo          INT ' 
                  + ',@b_Success          INT            OUTPUT '  
                  + ',@n_Err              INT            OUTPUT '
                  + ',@c_ErrMsg           NVARCHAR(255)  OUTPUT '    
          
   EXEC sp_ExecuteSQL 
               @c_SQL
            ,  @c_SQLParm
            ,  @c_StockTakeKey
            ,  @n_CountNo 
            ,  @b_Success  OUTPUT
            ,  @n_Err      OUTPUT
            ,  @c_ErrMsg   OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
   END
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPostFinalizeStkTakeCount_Wrapper'
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