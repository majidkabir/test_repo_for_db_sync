SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF21                                            */
/* Creation Date: 27-Apr-2023                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-22306 - TW Pack confirm create transmitlog2 for REPACK only*/
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 27-APR-2023  NJOW    1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPAKCF21]  
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
         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_TransmitlogKey  NVARCHAR(10)
         , @c_TableName       NVARCHAR(30)
    
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   

   IF @@TRANCOUNT = 0
      BEGIN TRAN 
   
   IF @n_Continue IN(1,2)
   BEGIN
      SELECT @c_Orderkey = Orderkey
   	  FROM PACKHEADER (NOLOCK)
   	  WHERE Pickslipno = @c_Pickslipno
   	  AND PackStatus = 'REPACK'   	
   	     	     	  
   	  IF ISNULL(@c_Orderkey,'') <> ''
   	  BEGIN
         EXECUTE nspg_getkey  
           'TransmitlogKey2'  
           , 10  
           , @c_TransmitlogKey   OUTPUT  
           , @b_success          OUTPUT  
           , @n_err              OUTPUT  
           , @c_errmsg           OUTPUT  
        
         IF NOT @b_success = 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 64300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                              + ': Unable to Obtain transmitlogkey. (ispPAKCF21) ( SQLSvr MESSAGE='   
                                + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END     	     

         SET @c_Tablename = 'WSMSSFPAKCFM'   
      
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)  
         VALUES (@c_TransmitlogKey, @c_TableName, @c_PickSlipNo, '', @c_StorerKey, '0', '') 
         
         IF @@ERROR <> 0          
         BEGIN          
            SET @n_continue = 3  
            SET @c_errmsg = ERROR_MESSAGE()        
            SET @n_err = 64310          
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                          + ': Insert into TRANSMITLOG2 Failed. (ispPAKCF21) '
                          + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF21'
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