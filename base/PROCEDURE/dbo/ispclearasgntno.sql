SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispClearAsgnTNo                                         */
/* Creation Date: 28-SEP-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Clear Tracking for order                                    */
/*        :                                                             */
/* Called By: isp_EPackRVCtnTrack01                                     */
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
CREATE PROC [dbo].[ispClearAsgnTNo]
            @c_TrackingNo  NVARCHAR(20) 
         ,  @c_OrderKey    NVARCHAR(10)   
         ,  @b_ChildFlag   INT = 0  
         ,  @b_Success     INT           OUTPUT      
         ,  @n_Err         INT           OUTPUT        
         ,  @c_ErrMsg      NVARCHAR(250) OUTPUT     
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Facility        NVARCHAR(5)
         , @c_StorerKey       NVARCHAR(15)
         , @c_OrderType       NVARCHAR(10)
         , @c_KeyName         NVARCHAR(30)  
         , @c_Shipperkey      NVARCHAR(15)  
         , @c_CarrierName     NVARCHAR(30)  

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   BEGIN TRAN

   SELECT @c_StorerKey  = o.StorerKey   
       ,  @c_ShipperKey = ISNULL(o.ShipperKey,'')   
       ,  @c_Facility   = o.Facility  
   FROM ORDERS o WITH (NOLOCK)  
   WHERE o.OrderKey = @c_OrderKey  
    
   IF @b_ChildFlag = 1
   BEGIN
      INSERT INTO CARTONTRACK_POOL 
            (  TrackingNo
            ,  CarrierName
            ,  KeyName
            )
      SELECT  TrackingNo
            , CarrierName
            , KeyName
      FROM CARTONTRACK WITH (NOLOCK)
      WHERE TrackingNo = @c_TrackingNo
      AND  CarrierName = @c_Shipperkey
      AND  LabelNo = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60010  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert CARTONTRACK_POOL Table. (ispClearAsgnTNo)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      DELETE CARTONTRACK WITH (ROWLOCK)
      WHERE TrackingNo = @c_TrackingNo
      AND  CarrierName = @c_Shipperkey
      AND  LabelNo = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60020  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete record from CARTONTRACK Table. (ispClearAsgnTNo)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispClearAsgnTNo'
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
END -- procedure

GO