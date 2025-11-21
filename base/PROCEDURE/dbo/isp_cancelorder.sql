SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_CancelOrder                                    */  
/* Creation Date: 05-Oct-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#249056:Unpickpack Orders                                */  
/*          Storerconfig UnpickpackORD_SP={SPName} to enable Cancel     */
/*          Order Process                                               */
/*                                                                      */  
/* Called By: RCM Unpickpack Orders At Unpickpack Orders screen         */    
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_CancelOrder]  
      @c_OrderKey       NVARCHAR(10) 
   ,  @b_Success        INT          OUTPUT 
   ,  @n_Err            INT          OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue        INT
         , @n_StartTCnt       INT
         , @c_MBOLKey         NVARCHAR(10)
         , @c_LoadKey         NVARCHAR(10)
         , @c_Wavekey         NVARCHAR(10)
         , @c_LoadStatus      NVARCHAR(10)

   SET @n_err           = 0
   SET @b_success       = 1
   SET @c_errmsg        = ''

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT

   SET @c_MBOLKey       = ''
   SET @c_LoadKey       = ''
   SET @c_Wavekey       = ''
   SET @c_LoadStatus    = ''

   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   SELECT @c_MBOLKey = ISNULL(RTRIM(MBOLKey),'')
         ,@c_Loadkey = ISNULL(RTRIM(LoadKey),'')
         ,@c_Wavekey = ISNULL(RTRIM(UserDefine09),'')
   FROM ORDERS WITH (NOLOCK)
   WHERE ORderkey = @c_OrderKey

   BEGIN TRAN
   -- Remove Orderkey from MBOL, Loadplan, Wave
   DELETE FROM MBOLDETAIL WITH (ROWLOCK)
   WHERE MBOLKey = @c_MBOLKey
   AND   Orderkey= @c_OrderKey

   IF @@Error <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63321
      SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Order from MBOLDETAIL Fail. (isp_CancelOrder)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'
      GOTO QUIT_SP
   END

   DELETE FROM LOADPLANDETAIL WITH (ROWLOCK)
   WHERE Loadkey = @c_Loadkey
   AND   Orderkey= @c_OrderKey

   IF @@Error <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63322
      SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Order from LOADPLANDETAIL Fail. (isp_CancelOrder)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'
      GOTO QUIT_SP
   END

   SELECT @c_LoadStatus = MAX(Status)
   FROM LOADPLANDETAIL WITH (NOLOCK)
   WHERE Loadkey = @c_Loadkey

   UPDATE LOADPLAN WITH (ROWLOCK)
   SET Status = @c_LoadStatus
     , Trafficcop = NULL
     , EditWho = SUSER_NAME()
     , EditDate= GETDATE()
   WHERE Loadkey = @c_Loadkey

   IF @@Error <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63323
      SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update LOAD Status on LOADPLAN Fail. (isp_CancelOrder)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'
      GOTO QUIT_SP
   END
                    
   DELETE FROM WAVEDETAIL WITH (ROWLOCK)
   WHERE Wavekey = @c_Wavekey
   AND   Orderkey= @c_OrderKey

   IF @@Error <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63324
      SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Order Status from WAVEDETAIL Fail. (isp_CancelOrder)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'
      GOTO QUIT_SP
   END

   UPDATE ORDERS WITH (ROWLOCK)
   SET  Status   = 'CANC'
      , SOStatus = 'CANC'  
      , Trafficcop = NULL
      , EditWho = SUser_Name()
      , EditDate = GetDate()
   WHERE Orderkey = @c_OrderKey

   IF @@Error <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63325
      SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update Cancel status to ORDERS fail. (isp_CancelOrder)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      GOTO QUIT_SP
   END

   QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_CancelOrder'
      --RAISERROR @n_err @c_errmsg
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