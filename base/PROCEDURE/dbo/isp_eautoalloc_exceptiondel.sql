SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_ExceptionDel                             */
/* Creation Date: 30-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4406 - ECOM Auto Allocation Dashboard                   */
/*        :                                                             */
/* Called By: delete button click                                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_EAutoAlloc_ExceptionDel]
           @c_RowRefList   NVARCHAR(MAX)
         , @b_Success      INT            OUTPUT
         , @n_Err          INT            OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 
         , @n_RowRef             BIGINT

         , @cur_EXC              CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   
   SET @cur_EXC = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT RowRef = EXC.ColValue
   FROM fnc_DelimSplit ('|', @c_RowRefList) EXC 
   ORDER BY RowRef

   OPEN @cur_EXC
   
   FETCH NEXT FROM @cur_EXC INTO @n_RowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      BEGIN TRAN 
      DELETE AUTOALLOCBATCHDETAIL WITH (ROWLOCK)
      WHERE RowRef = @n_RowRef

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Delete AUTOALLOCBATCHDETAIL Fail. (isp_EAutoAlloc_ExceptionDel)'
         ROLLBACK TRAN
         GOTO EXIT_SP
      END
      COMMIT TRAN
   
      FETCH NEXT FROM @cur_EXC INTO @n_RowRef
   END
   CLOSE @cur_EXC
   DEALLOCATE @cur_EXC

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EAutoAlloc_ExceptionDel'
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

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO