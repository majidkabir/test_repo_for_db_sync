SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF22                                            */
/* Creation Date: 15-May-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-22580 - SG AESOP Update tracking no                        */
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
/* 15-MAY-2023  NJOW    1.0   DevOps Combine Script                        */
/* 25-Jul-2023  NJOW01  1.1   Fix set archivecop = null                    */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPAKCF22]  
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
         , @c_TrackingNo      NVARCHAR(20)
    
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   

   IF @@TRANCOUNT = 0
      BEGIN TRAN 
   
   IF @n_Continue IN(1,2) AND EXISTS(SELECT 1 
                                     FROM PACKHEADER PH (NOLOCK)
                                     JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
                                     WHERE O.DocType = 'E')
   BEGIN
      SELECT @c_TrackingNo = O.TrackingNo
   	  FROM PACKHEADER PH (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   	  AND PH.PickslipNo = @c_Pickslipno
   	  
   	  IF ISNULL(@c_TrackingNo,'') <> ''
   	  BEGIN
   	     UPDATE PACKDETAIL WITH (ROWLOCK)
   	     SET RefNo = @c_TrackingNo,
   	         ArchiveCop = NULL  --NJOW01
   	     WHERE PickslipNo = @c_PickSlipNo
   	     
   	     SET @n_err = @@ERROR
   	     
         IF @n_err <> 0 
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 64300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                              + ': Update Packdetail Table Failed. (ispPAKCF22) ( SQLSvr MESSAGE='   
                                + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END     	        	     
   	     
   	     UPDATE PACKINFO WITH (ROWLOCK)
   	     SET TrackingNo = @c_TrackingNo,
   	         TrafficCop = NULL
   	     WHERE Pickslipno = @c_Pickslipno   	        	        	    

   	     SET @n_err = @@ERROR
   	     
         IF @n_err <> 0 
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 64310   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                              + ': Update PackInfo Table Failed. (ispPAKCF22) ( SQLSvr MESSAGE='   
                                + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END     	        	     
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF22'
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