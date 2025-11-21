SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPOIQC02                                                  */
/* Creation Date: 02-Jul-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17352 - [TW] StorerConfig for IQC Finialized Trigger    */      
/*                                                                      */
/* Called By: ispPostFinalizeIQCWrapper                                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 15-Jul-2021  WLChooi   1.1 Fix nspg_getkeys do not return result set */
/*                            (WL01)                                    */
/************************************************************************/
CREATE PROC [dbo].[ispPOIQC02]
            @c_qc_key         NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt            INT
         , @n_Continue             INT 
         , @c_NewWOKey             NVARCHAR(10)
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   --Header
   IF @n_continue IN(1,2)
   BEGIN
      EXEC nspg_GetKey
         @KeyName     = 'WorkOrder',
         @fieldlength = 10,
         @keystring   = @c_NewWOKey OUTPUT,
         @b_Success   = @b_Success  OUTPUT,
         @n_err       = @n_Err,
         @c_errmsg    = @c_ErrMsg,
         @b_resultset = 0,   --WL01
         @n_batch     = 1 	 
      
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65500
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspg_GetKey. (ispPOIQC02)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END    
         
      INSERT INTO WorkOrder(WorkOrderKey, ExternWorkOrderKey, StorerKey, Facility, ExternStatus, [Type]
                          , WkOrdUdef1, WkOrdUdef2, WkOrdUdef3, WkOrdUdef4, WkOrdUdef5
                          , WkOrdUdef6, WkOrdUdef7, WkOrdUdef8, WkOrdUdef9, WkOrdUdef10)
      SELECT TOP 1 @c_NewWOKey, IQC.Refno, IQC.StorerKey, IQC.to_facility, '2', IQC.Reason
                 , IQC.UserDefine01, IQC.UserDefine02, IQC.UserDefine03, IQC.UserDefine04, IQC.UserDefine05
                 , IQC.UserDefine06, IQC.UserDefine07, IQC.UserDefine08, IQC.UserDefine09, IQC.UserDefine10
      FROM InventoryQC IQC (NOLOCK) 
      WHERE IQC.QC_Key = @c_qc_key
      AND IQC.Reason = 'A2A'

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65505
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting WorkOrder. (ispPOIQC02)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END  
   END

   --Detail
   IF @n_continue IN(1,2)
   BEGIN
      IF EXISTS (SELECT 1 FROM WorkOrder WO (NOLOCK) WHERE WO.WorkOrderKey = @c_NewWOKey)  
      BEGIN
         INSERT INTO WorkOrderDetail(WorkOrderKey, WorkOrderLineNumber
                                   , ExternLineNo, Unit
                                   , Qty, Price, WkOrdUdef6, WkOrdUdef10
                                   , StorerKey, Sku, [Type])
         SELECT @c_NewWOKey, RIGHT('00000' + CAST((Row_Number() OVER (PARTITION BY IQD.QC_Key Order By IQD.QC_Key, CAST(IQD.QCLineNo AS INT))) AS NVARCHAR(5)), 5)
              , IQD.QCLineNo, IQD.UOM
              , IQD.Qty, IQD.UserDefine01, IQD.UserDefine06, IQD.UserDefine10
              , IQD.StorerKey, IQD.SKU, IQC.Reason
         FROM InventoryQCDetail IQD (NOLOCK)
         JOIN InventoryQC IQC (NOLOCK) ON IQC.QC_Key = IQD.QC_Key
         WHERE IQD.QC_Key = @c_qc_key AND IQC.Reason = 'A2A'   --WL01
         ORDER BY IQD.QC_Key, CAST(IQD.QCLineNo AS INT)

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65510
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting WorkOrderDetail. (ispPOIQC02)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOIQC02'
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