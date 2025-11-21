SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_EPackCtnTrack03                                         */
/* Creation Date: 12-DEC-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-1816 - CN_DYSON_Exceed_ECOM PACKING                     */
/*        :                                                             */
/* Called By: isp_GenLabelNo_Wrapper                                    */
/*        :                                                             */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-01-26  Wan01    1.1   Fixed to get Orderkey from PICKHEADER     */
/*                            due to empty orderkey/no packheader       */
/* 2018-01-26  Wan02    1.1   Log Tracking # issue &                    */
/* 2019-04-08  James    1.2   Add rdtIsRDT (james01)                    */
/* 2021-04-12  Wan03    1.3   WMS-16026 - PB-Standardize TrackingNo     */
/************************************************************************/
CREATE PROC [dbo].[isp_EPackCtnTrack03]
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
         , @c_DocType         NVARCHAR(10)
         , @c_TrackingNo_ORD  NVARCHAR(40)                           --(Wan03)

         , @c_OrigCartonNo NVARCHAR(10)                              --(Wan02)                                   

   DECLARE @n_IsRDT        INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   -- if it is from RDT, no need commit tran here else 
   -- RDT will return error in its own transaction block
   IF @n_IsRDT <> 1
      BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   END

   SET @c_OrigCartonNo = CONVERT(NVARCHAR(10), @n_CartonNo)          --(Wan02)

   SET @c_Orderkey = ''
   --(Wan01) - START
   --SELECT @c_Orderkey = Orderkey 
   --      ,@c_Storerkey= Storerkey
   --FROM PACKHEADER WITH (NOLOCK)
   --WHERE PickSlipNo = @c_PickSlipNo
   
   SELECT @c_Orderkey = Orderkey 
         ,@c_Storerkey= Storerkey
   FROM PICKHEADER WITH (NOLOCK)
   WHERE PickHeaderkey = @c_PickSlipNo
   --(Wan01) - END

   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END   

   SET @c_DocType = ''
   SELECT @c_DocType = OH.Doctype
         ,@c_TrackingNo_ORD = CASE WHEN ISNULL(RTRIM(OH.TrackingNo),'') <> '' THEN OH.TrackingNo ELSE ISNULL(RTRIM(OH.UserDefine04),'') END  --Wan03
   FROM ORDERS OH WITH(NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey
                  
   IF @C_Doctype <> 'E'
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_CartonNo = @n_CartonNo + 1 -- Packing Screen - New Carton will pass in existing CartonNo
   IF EXISTS ( SELECT 1 
               FROM PACKDETAIL WITH (NOLOCK)
               WHERE PickSlipNo = @c_PickSlipNo
               AND CartonNo = @n_CartonNo
               AND LabelNo <> ''
               )
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_CTNTrackNo = @c_TrackingNo_ORD                                                                                                     --(Wan03)
   IF @c_CTNTrackNo <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 
                     FROM PACKDETAIL WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo
                    )
      BEGIN
         GOTO QUIT_SP
      END

      IF @n_CartonNo = 1
      BEGIN
         GOTO QUIT_SP
      END
   END

   BEGIN TRAN
   SET @c_CTNTrackNo = ''
   EXEC ispAsgnTNo
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
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Empty Tracking #. (isp_EPackCtnTrack03)' 
      GOTO QUIT_SP
   END

   QUIT_SP:

   --(Wan03) - START
   --INSERT INTO TRACEINFO (TraceName, TimeIn, TimeOut,Step1, Step2, Step3, Step4, Step5, col1, col2)
   --VALUES ('isp_EPackCtnTrack03', GETDATE(), GETDATE(), @c_PickSlipNo, @c_OrigCartonNo, @c_Orderkey, @c_DocType, @c_CTNTrackNo, @c_TrackingNo_ORD, @c_Storerkey)
   --(Wan03) - END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackCtnTrack03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END    
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure


GO