SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/        
/* Trigger: isp_EPackCtnTrack04                                         */        
/* Creation Date: 11-FEB-2020                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: KuanYee                                                  */        
/*                                                                      */        
/* Purpose: WMS-12101 - CN IKEA Ecompacking for SN order CR             */        
/*        :                                                             */        
/* Called By: n_cst_packcarton_ecom                                     */        
/*          : ue_getcartontrackno                                       */        
/*        :                                                             */        
/* PVCS Version: 1.2                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 2020-03-25  Wan01    1.1   Ikea Fixed Issue - Duplicate Tracking#    */
/* 2021-04-09  Wan02    1.2   WMS-16026 - PB-Standardize TrackingNo     */          
/************************************************************************/        
CREATE PROC [dbo].[isp_EPackCtnTrack04]        
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
        
   DECLARE @n_StartTCnt       INT        
         , @n_Continue        INT        
                 
         , @n_Cnt             INT        
         , @n_RowRef          BIGINT        
         , @c_Orderkey        NVARCHAR(10)        
         , @c_Storerkey       NVARCHAR(15)        
        
         , @c_Shipperkey      NVARCHAR(10)        
         , @c_ShipperName     NVARCHAR(250) 
         
         , @c_TrackingNo_ORD  NVARCHAR(40) = ''         --(Wan02)
         , @c_TrackingNo      NVARCHAR(40) = ''             --(Wan02)
        
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
         ,@c_TrackingNo_ORD = CASE WHEN ISNULL(RTRIM(TrackingNo),'') <> '' THEN TrackingNo ELSE ISNULL(RTRIM(UserDefine04),'') END   --(Wan02)      
   FROM ORDERS WITH (NOLOCK)       
   WHERE OrderKey = @c_Orderkey       
      
   IF @c_Shipperkey <> 'SN'       
   BEGIN    
      GOTO QUIT_SP    
   END  
  
   SET @n_Cnt = 0        
   
   IF @c_TrackingNo_ORD <> @c_CTNTrackNo              --(Wan02)--(Wan01)
   BEGIN
      --IF EXISTS ( SELECT 1                          --(Wan02)
      --            FROM PACKINFO PIF WITH (NOLOCK)        
      --            WHERE PIF.PickSlipNo = @c_PickSlipNo        
      --            AND  PIF.RefNo = @c_CTNTrackNo        
      --            AND  PIF.CartonNo = @n_CartonNo      
      --            AND  EXISTS (  SELECT 1 FROM CARTONTRACK CT WITH (NOLOCK)
      --                           WHERE CT.TrackingNo = PIF.RefNo
      --                           AND LabelNo = @c_Orderkey
      --                        )
      --          )   
      --          
      SELECT @c_TrackingNo = CASE WHEN ISNULL(PIF.TrackingNo,'') <> '' THEN RTRIM(PIF.TrackingNo) ELSE ISNULL(RTRIM(PIF.RefNo),'') END  --(Wan02)  
      FROM PACKINFO PIF WITH (NOLOCK)        
      WHERE PIF.PickSlipNo = @c_PickSlipNo        
      AND  PIF.CartonNo = @n_CartonNo   
   
      IF @c_TrackingNo = @c_CTNTrackNo AND EXISTS
         (  SELECT 1 FROM CARTONTRACK CT WITH (NOLOCK)
            WHERE CT.TrackingNo = @c_TrackingNo
            AND LabelNo = @c_Orderkey
         )                         
      BEGIN
         GOTO QUIT_SP        
      END
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
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Empty Tracking #. (isp_EPackCtnTrack04)'         
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
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKINFO Table. (isp_EPackCtnTrack04)'         
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '         
         GOTO QUIT_SP        
      END        
   END        
   ELSE        
   BEGIN        
      INSERT INTO PACKINFO         
            (  PickSlipNo        
            ,  CartonNo        
            --,  RefNo                          --(Wan02)
            ,  Weight        
            ,  Cube        
            ,  Height        
            ,  Length        
            ,  Width 
            ,  TrackingNo                       --(Wan02)                        
            )        
      VALUES(  @c_PickSlipNo        
            ,  @n_CartonNo        
            --,  @c_CTNTrackNo                  --(Wan02)
            ,  0.00        
            ,  0.00        
            ,  0.00        
            ,  0.00        
            ,  0.00 
            ,  @c_CTNTrackNo                    --(Wan02)                    
            )        
      SET @n_err = @@ERROR        
      IF @n_err <> 0        
      BEGIN        
         SET @n_continue = 3        
         SET @n_err = 60030          
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert PACKINFO Table. (isp_EPackCtnTrack04)'         
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
        
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackCtnTrack04'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
   END        
        
   WHILE @@TRANCOUNT < @n_StartTCnt        
   BEGIN        
      BEGIN TRAN        
   END        
END -- procedure 

GO