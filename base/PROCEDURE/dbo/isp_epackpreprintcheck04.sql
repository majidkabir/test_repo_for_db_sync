SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_EPACKPrePrintCheck04                                */
/* Creation Date: 14-Dec-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15848 - Only Print Packing List if Userdefine01 = 'VC30'*/
/*                                                                      */
/* Called By: isp_EPACKPrePrintCheck_Wrapper                            */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-Mar-2022 WLChooi  1.1   DevOps Combine Script                     */
/* 28-Mar-2022 WLChooi  1.1   WMS-19347 - Use Codelkup to store Brand   */
/*                            - UserDefine01 (WL01)                     */
/************************************************************************/
CREATE PROC [dbo].[isp_EPACKPrePrintCheck04]
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
     
   IF(@c_ReportType = 'PACKLIST')
   BEGIN
      SELECT @c_Orderkey = Orderkey
      FROM PACKHEADER (NOLOCK)
      WHERE PICKSLIPNO = @c_PickSlipNo
   
      --0 = Fail, 1 = Print, 2 = Not To Print 
      --WL01 S
      --IF NOT EXISTS( SELECT 1
      --               FROM ORDERS O (NOLOCK)
      --               WHERE O.ORDERKEY =  @c_Orderkey
      --               AND O.DocType = 'E' 
      --               AND O.UserDefine01 = 'VC30')
      IF NOT EXISTS( SELECT 1
                     FROM ORDERS O (NOLOCK)
                     JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'TNFBRAND' 
                                              AND CL.Storerkey = O.Storerkey
                                              AND CL.Code = O.UserDefine01
                                              AND CL.Short = 'Y'
                                              AND CL.Long = 'r_dw_packing_list_93_rdt'
                                              AND CL.code2 = O.DocType
                     WHERE O.ORDERKEY =  @c_Orderkey)
      --WL01 E
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
   END -- IF(@c_ReportType = 'PACKLIST')
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPACKPrePrintCheck04'
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