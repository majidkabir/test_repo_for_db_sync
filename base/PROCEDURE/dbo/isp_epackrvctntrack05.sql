SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: isp_EPackRVCtnTrack05                                       */  
/* Creation Date: 12-FEB-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-12101 - CN IKEA Ecompacking for SN order CR             */  
/*        : Only SN Shipperkey to get from CartonTrack_pool             */ 
/*        : Modify from isp_EPackRVCtnTrack05                           */  
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
/* 2020-03-11  Wan01    1.1   WMS-12330 - CN IKEA NormalPacking for SN  */
/*                            order CR                                  */
/* 2021-04-12  Wan02    1.1   WMS-16026 - PB-Standardize TrackingNo     */
/************************************************************************/  
CREATE PROC [dbo].[isp_EPackRVCtnTrack05]
         @c_PickSlipNo  NVARCHAR(10) 
      ,  @n_CartonNo    INT
      ,  @b_Success     INT = 0              OUTPUT    
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
         
         , @n_RowRef          BIGINT
         , @c_Orderkey        NVARCHAR(10)
         , @c_TrackingNo_PI   NVARCHAR(40) = ''  --(Wan02)
         , @c_TrackingNo_ORD  NVARCHAR(40) = ''  --(Wan02)         

         , @c_TaskBatchNo     NVARCHAR(10) = '' --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Orderkey = ''
   SET @c_TaskBatchNo = ''                   --(Wan01)
   SELECT @c_Orderkey = Orderkey 
         ,@c_TaskBatchNo = TaskBatchNo       --(Wan01)
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo 

   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END 

   IF EXISTS (SELECT 1 FROM ORDERS O (NOLOCK) WHERE O.Orderkey = @c_Orderkey AND O.ShipperKey <> 'SN')
   BEGIN  
      GOTO QUIT_SP  
   END   
   
   SET @c_TrackingNo_PI = ''
   --(Wan01) - START
   IF @c_TaskBatchNo = ''
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM ORDERS O (NOLOCK)
                  WHERE O.Orderkey = @c_Orderkey
                  AND O.ShipperKey = 'SN'
                ) 
      BEGIN
         SELECT @c_TrackingNo_PI = PD.LabelNo
         FROM PACKDETAIL PD WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND   CartonNo = @n_CartonNo   
      END
   END
   ELSE
   BEGIN
      SET @c_TrackingNo_PI = ''
      SELECT @c_TrackingNo_PI = CASE WHEN ISNULL(TrackingNo,'') <> '' THEN RTRIM(TrackingNo) ELSE ISNULL(RTRIM(RefNo),'') END --(Wan01)
      FROM PACKINFO WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo = @n_CartonNo 
   END
   --(Wan01) - END

   IF @c_TrackingNo_PI = ''
   BEGIN
      GOTO QUIT_SP
   END 

    --(Wan02) - START 
   --IF EXISTS ( SELECT 1
   --            FROM ORDERS WITH (NOLOCK) 
   --            WHERE Orderkey = @c_Orderkey
   --            AND   (TrackingNo = @c_TrackingNo_PI OR UserDefine04 = @c_TrackingNo_PI)
   --          )
   --BEGIN
   --   GOTO QUIT_SP
   --END 
   
   SELECT @c_TrackingNo_ORD= CASE WHEN ISNULL(RTRIM(TrackingNo),'') <> ''        --(Wan02)     
                                  THEN TrackingNo     
                                  ELSE ISNULL(RTRIM(UserDefine04),'')     
                                  END                                     
   FROM ORDERS WITH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey    
   
   IF @c_TrackingNo_PI = @c_TrackingNo_ORD
   BEGIN
      GOTO QUIT_SP   
   END          
   --(Wan02) - END               

   SELECT TOP 1 
         @n_RowRef = RowRef
   FROM CARTONTRACK WITH (NOLOCK)
   WHERE TrackingNo = @c_TrackingNo_PI
   AND   LabelNo = @c_Orderkey
  
   EXEC ispClearAsgnTNo
         @c_TrackingNo  = @c_TrackingNo_PI
      ,  @c_OrderKey    = @c_Orderkey  
      ,  @b_ChildFlag   = 1 
      ,  @b_Success     = @b_Success   OUTPUT      
      ,  @n_Err         = @n_Err       OUTPUT        
      ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT   

   IF @b_Success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60010  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ispClearAsgnTNo. '
                   + RTRIM(@c_ErrMsg) + ' (isp_EPackRVCtnTrack05)' 
      GOTO QUIT_SP
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackRVCtnTrack05'
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