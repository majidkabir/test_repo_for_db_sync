SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_EPackRVCtnTrack03                                       */
/* Creation Date: 28-NOV-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WAN                                                      */
/*                                                                      */
/* Purpose: WMS-3486 - CR_Nike Korea ECOM Exceed Packing Module         */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
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
CREATE PROC [dbo].[isp_EPackRVCtnTrack03]
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

   DECLARE @n_StartTCnt    INT
         , @n_Continue     INT
         
         , @n_RowRef       BIGINT
         , @c_Storerkey    NVARCHAR(10)
         , @c_Orderkey     NVARCHAR(10)
         , @c_TrackingNo   NVARCHAR(30)
         , @c_UserDefine04 NVARCHAR(20)
         , @c_RefNo        NVARCHAR(20)
         , @c_CLRTrackNo   NVARCHAR(30)

         , @CUR_CLR        CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''


   SET @c_Orderkey = ''
   SET @c_Storerkey= ''
   SELECT @c_Orderkey = Orderkey
         ,@c_Storerkey= Storerkey 
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END 
   
   SET @c_RefNo = ''
   SELECT TOP 1 @c_RefNo = ISNULL(RTRIM(LabelNo),'')
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND   CartonNo = @n_CartonNo 
 
   IF @c_RefNo = ''
   BEGIN
      GOTO QUIT_SP
   END 

   SELECT @c_TrackingNo   = ISNULL(RTRIM(TrackingNo),'')
         ,@c_UserDefine04 = ISNULL(RTRIM(UserDefine04),'')
   FROM ORDERS WITH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey

   IF @c_TrackingNo = @c_RefNo OR @c_UserDefine04 = @c_RefNo
   BEGIN
      GOTO QUIT_SP
   END               

   -- Lock Track #
   --EXEC ispClearAsgnTNo
   --      @c_TrackingNo  = @c_RefNo
   --   ,  @c_OrderKey    = @c_Orderkey  
   --   ,  @b_ChildFlag   = 1 
   --   ,  @b_Success     = @b_Success   OUTPUT      
   --   ,  @n_Err         = @n_Err       OUTPUT        
   --   ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT

   SELECT TOP 1 
         @n_RowRef = RowRef
   FROM CARTONTRACK WITH (NOLOCK)
   WHERE TrackingNo = @c_RefNo
   AND   LabelNo = @c_Orderkey
    
   -- UnLock Track #
   UPDATE CARTONTRACK WITH (ROWLOCK)
   SET LabelNo = ''
    ,  CarrierRef2 = ''
    ,  EditWho = SUSER_SNAME()          
    ,  EditDate= GETDATE()             
    ,  ArchiveCop = NULL               
   WHERE RowRef = @n_RowRef

   IF @b_Success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60010  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE Table CARTONTRACK Fail. '
                   + RTRIM(@c_ErrMsg) + ' (isp_EPackRVCtnTrack03)' 
      GOTO QUIT_SP
   END
   /*
   CLEAR_UNSAVETRACKNO:
   SET @CUR_CLR = CURSOR FAST_FORWARD READ_ONLY FOR      
   SELECT CT.RowRef
         ,CT.TrackingNo
   FROM CARTONTRACK CT WITH (NOLOCK)
   WHERE CT.LabelNo = @c_Orderkey
   AND   CT.KeyName = @c_Storerkey  
   AND   CT.CarrierRef2 = 'GET'
   AND   NOT EXISTS ( SELECT 1
                      FROM PACKDETAIL PD WITH (NOLOCK)
                      WHERE PD.PickSlipNo = @c_PickSlipNo  
                      AND   PD.LabelNo = CT.TrackingNo
                     )

   OPEN @CUR_CLR
   
   FETCH NEXT FROM @CUR_CLR INTO @n_RowRef
                              ,  @c_CLRTrackNo  

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @c_TrackingNo = @c_CLRTrackNo OR @c_UserDefine04 = @c_CLRTrackNo
      BEGIN
         GOTO NEXT_TRACKNO
      END 

      -- UnLock Track #
      UPDATE CARTONTRACK WITH (ROWLOCK)
      SET LabelNo = ''
       ,  CarrierRef2 = ''
       ,  EditWho = SUSER_SNAME()          
       ,  EditDate= GETDATE()             
       ,  ArchiveCop = NULL               
      WHERE RowRef = @n_RowRef

      IF @b_Success = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60015  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE Table CARTONTRACK Fail. '
                      + RTRIM(@c_ErrMsg) + ' (isp_EPackRVCtnTrack03)' 
         GOTO QUIT_SP
      END

      NEXT_TRACKNO:
      FETCH NEXT FROM @CUR_CLR INTO @n_RowRef
                                 ,  @c_CLRTrackNo  
   END 
   */
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackRVCtnTrack03'
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