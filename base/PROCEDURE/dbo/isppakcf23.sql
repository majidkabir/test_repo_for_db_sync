SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF23                                            */
/* Creation Date: 01-AUG-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-23238 - SG LIXIL Pack confirm update packdetail and orders */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 01-AUG-2023  NJOW    1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPAKCF23]  
(     @c_PickSlipNo  NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT = 0
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
         , @c_Refno2          NVARCHAR(30)
         , @c_Orderkey        NVARCHAR(10)
    
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   

   IF @@TRANCOUNT = 0
      BEGIN TRAN 
   
   IF @n_Continue IN(1,2) AND EXISTS(SELECT 1 
                                     FROM PACKHEADER PH (NOLOCK)
                                     JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
                                     JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND O.M_Company = CL.UDF01
                                     WHERE CL.ListName = 'CUSTPARAM'
                                     AND CL.Code = 'AUTOGENTRACKINGID'
                                     AND PH.PickslipNo = @c_PickSlipNo)
   BEGIN
   	  SELECT @c_Orderkey = O.Orderkey,
   	         @c_RefNo2 = RTRIM(ISNULL(O.C_Country,'')) + LTRIM(ISNULL(O.M_Company,''))
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      WHERE PH.PickslipNo = @c_PickSlipNo
                                        	  
      UPDATE PACKDETAIL WITH (ROWLOCK)
      SET RefNo = LabelNo,
          RefNo2 = @c_RefNo2,
          ArchiveCop = NULL 
      WHERE PickslipNo = @c_PickSlipNo
      
      SET @n_err = @@ERROR
      
      IF @n_err <> 0 
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 64300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                           + ': Update Packdetail Table Failed. (ispPAKCF23) ( SQLSvr MESSAGE='   
                             + @c_errmsg + ' ) ' 
         GOTO QUIT_SP                     
      END     	        	  
                 
   	  UPDATE ORDERS WITH (ROWLOCK)
   	  SET SOStatus = '5'
   	  WHERE Orderkey = @c_Orderkey
      
   	  SET @n_err = @@ERROR
   	  
      IF @n_err <> 0 
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 64310   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                           + ': Update Order Table Failed. (ispPAKCF23) ( SQLSvr MESSAGE='   
                             + @c_errmsg + ' ) ' 
         GOTO QUIT_SP                     
      END     	        	     
   END

QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF23'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO