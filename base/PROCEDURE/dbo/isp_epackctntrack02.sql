SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_EPackCtnTrack02                                         */
/* Creation Date: 13-JUN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2306 - CN-Nike SDC WMS ECOM Packing CR                  */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */ 
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-Sep-2017 TLTING   1.1   Call new assign tracking number           */
/* 03-Jul-2018 SPChin   1.2   INC0251468 - Change To ispAsgnTNo         */
/* 09-APR-2021 Wan01    1.3   WMS-16026 - PB-Standardize TrackingNo     */
/************************************************************************/
CREATE PROC [dbo].[isp_EPackCtnTrack02]
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
         
         , @n_RowRef       BIGINT
         , @c_Orderkey     NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)

         , @c_Shipperkey   NVARCHAR(10)
         , @c_ShipperName  NVARCHAR(250)
         
         , @c_TrackingNo   NVARCHAR(40)   = ''           --(Wan01)

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

   IF EXISTS ( SELECT 1
               FROM ORDERS WITH (NOLOCK)
               WHERE Orderkey = @c_Orderkey
               AND Type = 'COD'
             )
   BEGIN
      GOTO QUIT_SP
   END
                       
   --IF EXISTS ( SELECT 1                                --(Wan01) 
   --            FROM PACKINFO WITH (NOLOCK)
   --            WHERE PickSlipNo = @c_PickSlipNo
   --            AND  RefNo = @c_CTNTrackNo        
   --            AND  CartonNo = @n_CartonNo
   --)
   
   SELECT @c_TrackingNo = CASE WHEN ISNULL(TrackingNo,'') <> '' THEN TRIM(TrackingNo) ELSE ISNULL(RTRIM(RefNo),'') END   --(Wan01)
   FROM PACKINFO WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND  CartonNo = @n_CartonNo
   
   IF @c_TrackingNo =  @c_CTNTrackNo                       --(Wan01)     
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_CTNTrackNo = ''
   EXEC ispAsgnTNo   --INC0251468
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
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Empty Tracking #. (isp_EPackCtnTrack02)' 
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
      SET TrackingNo = @c_CTNTrackNo            --(Wan01) 
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
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKINFO Table. (isp_EPackCtnTrack02)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      INSERT INTO PACKINFO 
            (  PickSlipNo
            ,  CartonNo
            --,  RefNo                          --(Wan01) 
            ,  Weight
            ,  Cube
            ,  Height
            ,  Length
            ,  Width
            ,  TrackingNo                       --(Wan01)      
            )
      VALUES(  @c_PickSlipNo
            ,  @n_CartonNo
            --,  @c_CTNTrackNo                  --(Wan01)
            ,  0.00
            ,  0.00
            ,  0.00
            ,  0.00
            ,  0.00 
            ,  @c_CTNTrackNo                    --(Wan01)             
            )
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60030  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert PACKINFO Table. (isp_EPackCtnTrack02)' 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackCtnTrack02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO