SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPREALKIT01                                         */
/* Creation Date: 22-AUG-2019                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-10084 CN/SG Logitech kit allocation checking               */
/*                                                                         */
/* Called By: isp_PreKitAllocation_Wrapper: PreKitAllocation_SP            */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPREALKIT01]  
(     @c_Kitkey      NVARCHAR(10)   
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
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   DECLARE @c_LabelNo  NVARCHAR(20),
           @c_Orderkey NVARCHAR(10),
           @n_RowRef   BIGINT   
    
    IF EXISTS(SELECT 1 
              FROM KIT (NOLOCK)
              WHERE (Status <> '0'
                 OR Actionflag NOT IN('N','U'))
              AND Kitkey = @c_Kitkey
             )
    BEGIN
       SELECT @n_Continue = 3 
	     SELECT @n_Err = 38010
	     SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Only kit with status 0 and actionflag N,U is allowed to allocate. (ispPREALKIT01)'
    END             
      
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPREALKIT01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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