SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_BatchSubmitQCMD                          */
/* Creation Date: 30-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4406 - ECOM Auto Allocation Dashboard                   */
/*        :                                                             */
/* Called By: Send To QCMD button click                                 */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-AUG-2018 Wan01    1.1   Retrieve AutoAllocbatch.status = '1'      */
/*                            as its status chaage to 1 at BackendAlloc */
/************************************************************************/
CREATE PROC [dbo].[isp_EAutoAlloc_BatchSubmitQCMD]
           @c_AllocBatchNoList   NVARCHAR(MAX)
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 
         , @n_AllocBatchNo       BIGINT

         , @cur_SBMBAT         CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
 
   SET @cur_SBMBAT = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT AllocBatchNo = EXC.ColValue
   FROM fnc_DelimSplit ('|', @c_AllocBatchNoList) EXC 
   JOIN AUTOALLOCBATCH AAB WITH (NOLOCK) ON (AAB.AllocBatchNo = EXC.ColValue)
   WHERE AAB.Status = '1'                 --(Wan01)
   ORDER BY AllocBatchNo

   OPEN @cur_SBMBAT
   
   FETCH NEXT FROM @cur_SBMBAT INTO @n_AllocBatchNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN 
      SET @b_Success = 1
      EXEC isp_QCmd_SubmitBackendAllocTask_2 
            @nAllocBatchNo = @n_AllocBatchNo    
         , @bSuccess      = @b_Success OUTPUT
         , @nErr          = @n_Err     OUTPUT
         , @cErrMsg       = @c_ErrMsg  OUTPUT   
       
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ERROR Executing isp_QCmd_SubmitBackendAllocTask_2.'
                        + '(isp_EAutoAlloc_BatchSubmitQCMD) << ' + @c_ErrMsg + ' >>'
         ROLLBACK TRAN
         GOTO EXIT_SP
      END

      COMMIT TRAN
      FETCH NEXT FROM @cur_SBMBAT INTO @n_AllocBatchNo
   END
   CLOSE @cur_SBMBAT
   DEALLOCATE @cur_SBMBAT

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EAutoAlloc_BatchSubmitQCMD'
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