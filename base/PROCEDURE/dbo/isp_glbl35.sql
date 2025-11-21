SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL35                                          */
/* Creation Date: 31-Mar-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21958 - [TW] HKB_Add Trigger_SP in                      */ 
/*                      StorerConfigure_TrackingNoAllocate_New          */
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 31-Mar-2023  WLChooi 1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_GLBL35] ( 
         @c_PickSlipNo   NVARCHAR(10)
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20) OUTPUT
      ,  @c_DropID       NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_debug              INT       
         , @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)

   DECLARE @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Shipperkey         NVARCHAR(50)   = ''
         , @n_RowRef             BIGINT
         , @c_Sourcekey          NVARCHAR(10)   = ''
         , @c_Keyname            NVARCHAR(30)   = 'ORDERS'

   SET @b_debug            = 0
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   SET @c_LabelNo          = ''

   SELECT @c_Storerkey  = OH.Storerkey
        , @c_Shipperkey = OH.Shipperkey
        , @c_Sourcekey  = OH.OrderKey
   FROM PICKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   WHERE PH.PickHeaderKey = @c_PickSlipNo

   IF ISNULL(@c_Shipperkey,'') = ''
   BEGIN
      SELECT @c_Storerkey  = OH.Storerkey
           , @c_Shipperkey = OH.Shipperkey
           , @c_Sourcekey  = LPD.LoadKey
      FROM PICKHEADER PH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LoadKey = LPD.LoadKey
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      WHERE PH.PickHeaderKey = @c_PickSlipNo
   END

   IF TRIM(@c_Shipperkey) = 'SF'
   BEGIN
      SELECT TOP 1 @c_LabelNo = CTP.TrackingNo
                 , @n_RowRef  = CTP.RowRef
      FROM dbo.CartonTrack_Pool CTP (NOLOCK)
      WHERE CTP.KeyName = @c_Keyname
      AND CTP.CarrierName = @c_Shipperkey
      ORDER BY CTP.TrackingNo

      IF ISNULL(@c_LabelNo,'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60050 
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to get new Tracking# from CartonTrack_Pool. (isp_GLBL35)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      END
      ELSE
      BEGIN
         --Add into CartonTrack and delete from CartonTrack_Pool
         INSERT INTO dbo.CartonTrack (TrackingNo, CarrierName, KeyName, LabelNo)
         SELECT @c_LabelNo, @c_Shipperkey, @c_Keyname, @c_Sourcekey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60051 
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error inserting CartonTrack for Track# ' + @c_LabelNo + '. (isp_GLBL35)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         END

         DELETE FROM dbo.CartonTrack_Pool
         WHERE RowRef = @n_RowRef

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60052 
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error deleting from CartonTrack_Pool for Track# ' + @c_LabelNo + '. (isp_GLBL35)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         END
      END
   END
   ELSE   --Shipperkey <> SF, generate 10 digits labelno   
   BEGIN
      EXECUTE nspg_GetKey 'PACKNO'
                        , 10
                        , @c_LabelNo OUTPUT
                        , @b_Success OUTPUT
                        , @n_Err OUTPUT
                        , @c_ErrMsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60060 
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspg_GetKey. (isp_GLBL35)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      END
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0     
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GLBL35'
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