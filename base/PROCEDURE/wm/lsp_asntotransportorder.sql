SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_ASNToTransportOrder                                 */
/* Creation Date: 2023-01-06                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3900 - ASN Insert into Transport Order                 */
/*        :                                                             */
/* Called By: ANS Insert Trigger and SCE ASN button                     */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-12-13  Wan-v0   1.0   Created & DevOps Combine Script.          */
/* 2024-07-02  Inv Team 1.1   UWP-17135 - Migrate Inbound Door booking  */
/************************************************************************/
CREATE   PROC WM.lsp_ASNToTransportOrder
  @c_Receiptkey         NVARCHAR(10) = ''
, @b_Success            INT          = 1  OUTPUT
, @n_Err                INT          = 0  OUTPUT
, @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
, @c_UserName           NVARCHAR(128)= ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Revert          BIT = 0                                               --(Wan-v0)
      
   DECLARE @t_ShipmentKey     TABLE (  ShipmentGID    NVARCHAR(50)   NOT NULL DEFAULT ('')
                                    ,  ReceiptKey     NVARCHAR(10)   NOT NULL DEFAULT ('') 
                                    )       

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   BEGIN TRY
      IF SUSER_SNAME() <> @c_UserName AND @c_UserName <> ''
      BEGIN
         EXEC [WM].[lsp_SetUser] 
               @c_UserName = @c_UserName  OUTPUT
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
         IF @n_Err <> 0 
         BEGIN
            GOTO EXIT_SP
         END
    
         EXECUTE AS LOGIN = @c_UserName
         SET @b_Revert = 1                                                          --(Wan-v0)
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPT AS r WITH (NOLOCK)
                  WHERE r.ReceiptKey = @c_ReceiptKey
                  AND r.ASNStatus NOT IN ('0')
      )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 66110
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': ASN Status Not in Open.'
                       + ' Disallow to Create TMS_Shipment for Door Booking. (lsp_ASNToTransportOrder) '
         GOTO EXIT_SP
      END   
      
      IF EXISTS ( SELECT 1 FROM dbo.TMS_TransportOrder AS tto WITH (NOLOCK)
                  WHERE tto.OrderSourceID = @c_ReceiptKey
                  AND tto.IOIndicator = 'I'
      )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 66110
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': ASN found in TMS_TransportOrder. (lsp_ASNToTransportOrder) '
         GOTO EXIT_SP
      END   
    
      INSERT INTO dbo.TMS_Shipment
          (
             ShipmentGID
          ,  VehicleLPN
          ,  EquipmentID
          ,  DriveName
          ,  ShipmentPlannedStartDate
          ,  ShipmentPlannedEndDate
          ,  [Route]
          ,  ServiceProviderID
          ,  ShipmentVolume
          ,  ShipmentWeight
          ,  ShipmentCartonCount
          ,  ShipmentPalletCount
          ,  OTMShipmentStatus
          )
      OUTPUT INSERTED.ShipmentGID, @c_ReceiptKey INTO @t_ShipmentKey 
      SELECT
             ShipmentGID = CASE WHEN r.ExternReceiptKey <> '' THEN r.ExternReceiptKey ELSE r.ReceiptKey END         
          ,  VehicleLPN  = r.VehicleNumber         
          ,  EquipmentID = ''          
          ,  DriveName   = '' 
          ,  ShipmentPlannedStartDate =  r.ReceiptDate 
          ,  ShipmentPlannedEndDate   =  '1900-01-01'         
          ,  [Route]     =  ''
          ,  ServiceProviderID   =  ISNULL(r.Carrierkey,'')                  
          ,  ShipmentVolume      =  ISNULL(r.[Cube],0.00)         
          ,  ShipmentWeight      =  ISNULL(r.[Weight],0.00)          
          ,  ShipmentCartonCount =  0       
          ,  ShipmentPalletCount =  0 
          ,  OTMShipmentStatus   = ''
      FROM dbo.RECEIPT AS r WITH (NOLOCK)
      WHERE r.ReceiptKey = @c_ReceiptKey;
   
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 66110
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_Shipment. (lsp_ASNToTransportOrder) '
                       + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
         GOTO EXIT_SP
      END
   
      INSERT INTO dbo.TMS_ShipmentTransOrderLink
          (
              ProvShipmentID
          ,   ShipmentGID
          )
      SELECT TOP 1
              ProvShipmentID = tsk.ShipmentGID
          ,   ShipmentGID    = tsk.ShipmentGID
      FROM @t_ShipmentKey AS tsk

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 66120
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_ShipmentTransOrderLink. (lsp_ASNToTransportOrder) '
                       + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
         GOTO EXIT_SP
      END

      INSERT INTO TMS_TransportOrder
         (
            ProvShipmentID
         ,  OrderReleaseID
         ,  OrderSourceID
         ,  ClientReferenceID
         ,  Loadkey
         ,  MBOLKey
         ,  ParentSourceID
         ,  SplitFlag
         ,  Principal
         ,  Country
         ,  FacilityID
         ,  StopSeq
         ,  IOIndicator
         ,  StopServiceTime
         ,  OrderVolume
         ,  OrderWeight
         )
      SELECT 
            ProvShipmentID = tsk.ShipmentGID
         ,  OrderReleaseID = ''
         ,  OrderSourceID  = r.ReceiptKey
         ,  ClientReferenceID= ISNULL(r.ExternReceiptKey,'')
         ,  Loadkey        = ''
         ,  MBOLKey        = ''
         ,  ParentSourceID = ''
         ,  SplitFlag      = ''
         ,  Principal      = r.StorerKey
         ,  Country        = f.ISOCntryCode
         ,  FacilityID     = r.Facility
         ,  StopSeq        = ''
         ,  IOIndicator    = N'I'
         ,  StopServiceTime= ''
         ,  OrderVolume    = ISNULL(r.[Cube],0.00)
         ,  OrderWeight    = ISNULL(r.[Weight],0.00)
      FROM @t_ShipmentKey AS tsk
      JOIN dbo.RECEIPT AS r WITH (NOLOCK) ON tsk.Receiptkey = r.ReceiptKey
      JOIN dbo.FACILITY AS f WITH (NOLOCK) ON f.Facility = r.Facility

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 66130
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_Transorder. (lsp_ASNToTransportOrder) '
                       + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
         GOTO EXIT_SP
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
   END CATCH   
EXIT_SP:
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASNToTransportOrder'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   IF @b_Revert = 1  REVERT                                                         --(Wan-v0)
END -- procedure

GO