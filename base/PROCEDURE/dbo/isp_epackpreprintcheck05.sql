SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_EPACKPrePrintCheck05                                */
/* Creation Date: 15-Dec-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15873 - Only Print UCCLabel if Shipperkey = 'SFHK1'     */
/*                                                                      */
/* Called By: isp_EPACKPrePrintCheck_Wrapper                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_EPACKPrePrintCheck05]
           @c_PickSlipNo      NVARCHAR(10)
         , @c_CartonNoStart   NVARCHAR(10)
         , @c_CartonNoEnd     NVARCHAR(10)
         , @c_ReportType      NVARCHAR(30)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000) 
         , @c_SQLArgument     NVARCHAR(4000) 

         , @n_RecCnt          INT
         , @n_QtyPacked       INT

         , @c_Orderkey        NVARCHAR(10)   
         , @c_ECOMFlag        NVARCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @n_err       = 0
   SET @c_errmsg    = ''
   SET @c_Orderkey  = ''
   SET @b_Success  = ISNULL(@b_Success, 1) 

   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END
     
   IF(@c_ReportType = 'UCCLabel')
   BEGIN
      SELECT @c_Orderkey = Orderkey
      FROM PACKHEADER (NOLOCK)
      WHERE PICKSLIPNO = @c_PickSlipNo
   
      --0 = Fail, 1 = Print, 2 = Not To Print 
      IF NOT EXISTS( SELECT 1
                     FROM ORDERS O (NOLOCK)
                     WHERE O.ORDERKEY =  @c_Orderkey
                     AND O.Shipperkey = 'SFHK1')
      BEGIN
	      SET @n_continue = 2
	      SET @b_Success  = 2
	      GOTO QUIT_SP      	
      END
      ELSE 
      BEGIN
      	SET @b_Success  = 1 
      	GOTO QUIT_SP
      END                	
   END -- IF(@c_ReportType = 'UCCLabel')
   ELSE 
   BEGIN
      GOTO QUIT_SP
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPACKPrePrintCheck05'
   END
   ELSE
   BEGIN
      SET @b_Success = @n_Continue
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