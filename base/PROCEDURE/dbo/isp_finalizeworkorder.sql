SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_FinalizeWorkOrder                                       */
/* Creation Date: 19-Sep-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2933 Finalize Work Order                                */
/*                                                                      */
/* Called By: nep_n_cst_workorder                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[isp_FinalizeWorkOrder]
               @c_WorkOrderKey   NVARCHAR(10)
,              @b_Success        INT       = 1  OUTPUT
,              @n_err            INT       = 0  OUTPUT
,              @c_ErrMsg         NVARCHAR(250) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue                INT,
           @n_StartTCnt               INT,        -- Holds the current transaction count
           @c_PreFinalizeWorkOrder_SP NVARCHAR(30),
           @c_Storerkey               NVARCHAR(15),
           @c_Facility                NVARCHAR(5)

   SELECT @n_StartTCnt=@@TRANCOUNT, @n_continue=1, @b_Success=0, @n_err=0, @c_ErrMsg=''
   
   SELECT @c_Storerkey = Storerkey,
          @c_Facility = Facility
   FROM WORKORDER(NOLOCK)
   WHERE WorkOrderkey = @c_WorkOrderkey
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @b_Success = 0
      SET @c_PreFinalizeWorkOrder_SP = ''
      EXEC nspGetRight  
            @c_Facility  = @c_Facility 
          , @c_StorerKey = @c_StorerKey 
          , @c_sku       = NULL
          , @c_ConfigKey = 'PreFinalizeWorkOrder_SP'  
          , @b_Success   = @b_Success                  OUTPUT  
          , @c_authority = @c_PreFinalizeWorkOrder_SP  OUTPUT   
          , @n_err       = @n_err                      OUTPUT   
          , @c_errmsg    = @c_errmsg                   OUTPUT  

      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreFinalizeWorkOrder_SP AND TYPE = 'P')
      BEGIN
         SET @b_Success = 0  
         EXECUTE dbo.isp_PreFinalizeWorkOrderWrapper 
                 @c_WorkOrderKey            = @c_WorkOrderkey
               , @c_PreFinalizeWorkOrder_SP = @c_PreFinalizeWorkOrder_SP
               , @b_Success                 = @b_Success     OUTPUT  
               , @n_Err                     = @n_err         OUTPUT   
               , @c_ErrMsg                  = @c_errmsg      OUTPUT  

         IF @n_err <> 0  
         BEGIN 
            SET @n_continue= 3 
         END 
      END 
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  UPDATE WORKORDERDETAIL WITH (ROWLOCK)
   	  SET Status = '9'
   	  WHERE WorkOrderkey = @c_WorkOrderkey
   	  AND Status <> '9'
   	  
      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WORKORDERDETAIL Failed! (isp_FinalizeWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END               	     	  
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  UPDATE WORKORDER WITH (ROWLOCK)
   	  SET Status = '9'
   	  WHERE WorkOrderkey = @c_WorkOrderkey   	
   	  AND STATUS <> '9'

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WORKORDER Failed! (isp_FinalizeWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END               	     	  
   END              
      
   QUIT_SP:
   
   /* #INCLUDE <SPIAM2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_FinalizeWorkOrder'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO