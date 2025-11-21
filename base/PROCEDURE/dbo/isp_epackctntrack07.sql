SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_EPackCtnTrack07                                         */
/* Creation Date: 02-JUL-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17424 - CN Coach ECOM Packing get tracking no           */
/*        :                                                             */
/* Called By: n_cst_packcarton_ecom                                     */
/*          : ue_getcartontrackno                                       */
/*        :                                                             */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_EPackCtnTrack07]
         @c_PickSlipNo  NVARCHAR(10) 
      ,  @n_CartonNo    INT
      ,  @c_CTNTrackNo  NVARCHAR(40)         OUTPUT
      ,  @b_Success     INT = 0              OUTPUT   -- 0:Fail, 1:Success 2:Success with Track # is lock
      ,  @n_err         INT = 0              OUTPUT 
      ,  @c_errmsg      NVARCHAR(255) = ''   OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt    INT
         , @n_Continue     INT
         
         , @n_Cnt          INT
         , @n_RowRef       BIGINT
         , @c_Orderkey     NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Shipperkey   NVARCHAR(10)
         , @c_ShipperName  NVARCHAR(250)         
         , @c_TrackingNo   NVARCHAR(40) = ''

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @n_CartonNo = 1 
   BEGIN
      GOTO UPDATE_PACKINFO
   END

   SET @c_Orderkey = ''
   SELECT @c_Orderkey = Orderkey 
         ,@c_Storerkey= Storerkey
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END   

   SELECT @c_Shipperkey = ShipperKey   
   FROM ORDERS WITH (NOLOCK)       
   WHERE OrderKey = @c_Orderkey  

   IF @c_Shipperkey <> 'SF'       
   BEGIN    
      GOTO QUIT_SP    
   END  
   
   SET @n_Cnt = 0    
     
   SELECT @c_TrackingNo = CASE WHEN ISNULL(PI.TrackingNo,'') <> '' THEN RTRIM(PI.TrackingNo) ELSE ISNULL(RTRIM(PI.RefNo),'') END  
   FROM dbo.PackInfo AS PI WITH (NOLOCK)
   WHERE PI.PickSlipNo = @c_PickSlipNo
   AND  CartonNo = @n_CartonNo
   
   IF @c_CTNTrackNo = @c_TrackingNo AND EXISTS
         (  SELECT 1 FROM CARTONTRACK CT WITH (NOLOCK)
            WHERE CT.TrackingNo = @c_TrackingNo
            AND LabelNo = @c_Orderkey
         )                                               
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_CTNTrackNo = ''
   EXEC ispAsgnTNo2
     @c_OrderKey    = @c_OrderKey   
   , @c_LoadKey     = ''
   , @b_Success     = @b_Success    OUTPUT      
   , @n_Err         = @n_Err        OUTPUT      
   , @c_ErrMsg      = @c_ErrMsg     OUTPUT      
   , @b_ChildFlag   = 1
   , @c_TrackingNo  = @c_CTNTrackNo OUTPUT 

   IF ISNULL(RTRIM(@c_CTNTrackNo),'') = ''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60010  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Empty Tracking #. (isp_EPackCtnTrack07)' 
      GOTO QUIT_SP
   END

   UPDATE_PACKINFO:
   IF EXISTS ( SELECT 1
               FROM PACKINFO WITH (NOLOCK)
               WHERE PickSlipNo = @c_PickSlipNo
               AND CartonNo = @n_CartonNo
              )
   BEGIN
      IF @n_CartonNo = 1
      BEGIN
         SET @b_Success = 1
         GOTO QUIT_SP
      END

      UPDATE PACKINFO WITH (ROWLOCK)
      SET TrackingNo = @c_CTNTrackNo     
         ,TrafficCop = NULL
         ,EditWho = SUSER_SNAME()
         ,EditDate= GETDATE()
      WHERE PickSlipNo = @c_PickSlipNo
      AND CartonNo = @n_CartonNo

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60020  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKINFO Table. (isp_EPackCtnTrack07)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      INSERT INTO PACKINFO 
            (  PickSlipNo
            ,  CartonNo
            ,  Weight
            ,  Cube
            ,  Height
            ,  Length
            ,  Width 
            ,  TrackingNo                    
            )
      VALUES(  @c_PickSlipNo
            ,  @n_CartonNo
            ,  0.00
            ,  0.00
            ,  0.00
            ,  0.00
            ,  0.00  
            ,  @c_CTNTrackNo                 
            )
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60030  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert PACKINFO Table. (isp_EPackCtnTrack07)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END
   END
   SET @b_Success = 2

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      ROLLBACK TRAN

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackCtnTrack07'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO