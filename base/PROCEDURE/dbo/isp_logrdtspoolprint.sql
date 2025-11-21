SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_LogRDTSpoolPrint                                    */
/* Creation Date: 29-Jan-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
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
/************************************************************************/
CREATE PROC [dbo].[isp_LogRDTSpoolPrint]
      @n_JobID          BIGINT
   ,  @c_Notes          NVARCHAR(500)
   ,  @b_Success        INT            = 1   OUTPUT
   ,  @n_Err            INT            = 0   OUTPUT
   ,  @c_ErrMsg         NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END


   BEGIN TRAN

   INSERT INTO RDT.RDTSPOOLERLOG (JobId, Notes)
   VALUES (@n_JobID, @c_Notes)
     
      
   SET @n_Err = @@ERROR
      
   IF @n_Err  <> 0
   BEGIN
      SET @n_Continue = 3
      SET @c_ErrMsg =  CONVERT(CHAR(5), @n_Err) 
      SET @n_Err = 62820
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Insert record Into RDT.RDTPRINTJOB_LOG Fail. (isp_LogRDTSpoolPrint)'
                     + '(' + @c_ErrMsg + ')'
      GOTO QUIT_SP
   END  
      
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_LogRDTSpoolPrint'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT <  @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO