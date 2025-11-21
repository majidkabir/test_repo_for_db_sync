SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: isp_EPackRVCtnTrack06                                       */  
/* Creation Date: 12-FEB-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-15244 - [CN] NIKE_O2_Ecom_packing_RFID_CR               */         
/*        :                                                             */ 
/*        :                                                             */  
/* Called By: Redo                                                      */  
/*          :                                                           */  
/*        :                                                             */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2020-03-11  Wan01    1.1   WMS-12330 - CN IKEA NormalPacking for SN  */
/*                            order CR                                  */
/************************************************************************/  
CREATE PROC [dbo].[isp_EPackRVCtnTrack06]
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

   DECLARE @n_StartTCnt    INT          = @@TRANCOUNT
         , @n_Continue     INT          = 1
         
         , @n_RowRef       BIGINT       = 0
         , @c_Orderkey     NVARCHAR(10) = ''
         , @c_RefNo        NVARCHAR(40) = ''

         , @c_TrackingNo   NVARCHAR(40) = '' 
         , @c_UserDefine04 NVARCHAR(40) = '' 
         , @c_Shipperkey   NVARCHAR(15) = ''
         , @c_CarrierRef1  NVARCHAR(15) = ''
         
         , @CUR_CTNTRCK    CURSOR

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Orderkey = ''
   SELECT @c_Orderkey = Orderkey 
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo 

   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END 

   SELECT @c_RefNo        = ISNULL(TrackingNo,'')
         ,@c_UserDefine04 = ISNULL(UserDefine04,'')
         ,@c_Shipperkey   = ISNULL(ShipperKey,'')
   FROM ORDERS WITH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey

   SET @c_CarrierRef1 = @c_Orderkey + CONVERT(NVARCHAR(5), @n_CartonNo)
   
   -- Delete SubTrackingNo By Orders as OPS may request new tracking # when New CartonNo and REDO without packing to New Carton
   SET @CUR_CTNTRCK = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT  RowRef
          ,TrackingNo
   FROM CARTONTRACK WITH (NOLOCK)
   WHERE LabelNo    = @c_Orderkey
   AND   Carriername= @c_Shipperkey
   AND   CarrierRef1 LIKE  @c_Orderkey + '%'
   AND   Keyname='NIKEO2SUB'
  
   OPEN @CUR_CTNTRCK
   
   FETCH NEXT FROM @CUR_CTNTRCK INTO @n_RowRef, @c_TrackingNo 
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_TrackingNo = @c_RefNo OR @c_TrackingNo = @c_UserDefine04
      BEGIN
         GOTO QUIT_SP
      END
  
      DELETE FROM CARTONTRACK
      WHERE RowRef = @n_RowRef
   
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @n_err = 60010  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete table CARTONTRACK fail. (isp_EPackRVCtnTrack06) '
                      + RTRIM(@c_ErrMsg) 
         GOTO QUIT_SP
      END
      FETCH NEXT FROM @CUR_CTNTRCK INTO @n_RowRef, @c_TrackingNo 
   END
   CLOSE @CUR_CTNTRCK
   DEALLOCATE @CUR_CTNTRCK
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackRVCtnTrack06'
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