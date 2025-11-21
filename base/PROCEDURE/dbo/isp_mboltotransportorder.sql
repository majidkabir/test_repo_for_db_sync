SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_MBOLToTransportOrder                                */
/* Creation Date: 2021-12-13                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3249 - UAT RG  Dock door booking backend + SP          */
/*        :                                                             */
/* Called By: ispFinalizeMBOL                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-12-13  Wan      1.0   Created.                                  */
/* 2021-12-13  Wan      1.0   DevOps Combine Script.                    */
/************************************************************************/
CREATE PROC [dbo].[isp_MBOLToTransportOrder]
           @c_MbolKey            NVARCHAR(10) = ''
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         
         , @c_VehicleNo       NVARCHAR(150)  = ''
      
   DECLARE @t_ShipmentKey     TABLE (  ShipmentGID    NVARCHAR(50)   NOT NULL DEFAULT ('')
                                    ,  MBOLkey        NVARCHAR(10)   NOT NULL DEFAULT ('') )       

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

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
   OUTPUT INSERTED.ShipmentGID, @c_MBOLKey INTO @t_ShipmentKey 
   SELECT
          ShipmentGID = CASE WHEN m.ExternMbolKey <> '' THEN m.ExternMbolKey ELSE m.MBOLKey END         
       ,  VehicleLPN  = @c_VehicleNo         
       ,  EquipmentID = ISNULL(m.Equipment,'')          
       ,  DriveName   = ISNULL(m.DriverName,'') 
       ,  ShipmentPlannedStartDate =  m.LoadingDate    
       ,  ShipmentPlannedEndDate   =  GETDATE()           
       ,  [Route]     =  ISNULL(m.[Route],'')
       ,  ServiceProviderID  = ISNULL(m.Carrierkey,'')                  
       ,  ShipmentVolume      =  ISNULL(m.[Cube],0.00)         
       ,  ShipmentWeight      =  ISNULL(m.[Weight],0.00)          
       ,  ShipmentCartonCount =  ISNULL(m.CaseCnt,0)         
       ,  ShipmentPalletCount =  ISNULL(m.PalletCnt,0)  
       ,  OTMShipmentStatus   =  ''
   FROM dbo.MBOL AS m WITH (NOLOCK)
   WHERE m.MBOLKey = @c_MBOLKey;
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66110
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_Shipment. (isp_MBOLToTransportOrder) '
                    + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
      GOTO QUIT_SP
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
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_ShipmentTransOrderLink. (isp_MBOLToTransportOrder) '
                    + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
      GOTO QUIT_SP
   END

   INSERT INTO TMS_TransportOrder
      (
         ProvShipmentID
      ,  OrderReleaseID
      ,  OrderSourceID
      ,  ClientReferenceID
      ,  Loadkey
      ,  MBOLkey
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
      ,  OrderCartonCount
      ,  OrderPalletCount
      ,  PickPriority
      ,  ErrorCode
      )
   SELECT 
         ProvShipmentID = tsk.ShipmentGID
      ,  OrderReleaseID = ''
      ,  OrderSourceID  = m.Orderkey
      ,  ClientReferenceID= ISNULL(m.ExternOrderKey,'')
      ,  Loadkey        = m.Loadkey
      ,  MBOLkey        = m.MBOLkey 
      ,  ParentSourceID = ''
      ,  SplitFlag      = ''
      ,  Principal      = o.StorerKey
      ,  Country        = ''
      ,  FacilityID     = o.Facility
      ,  StopSeq        = ''
      ,  IOIndicator    = N'O'
      ,  StopServiceTime= ''
      ,  OrderVolume    = ISNULL(m.[Cube],0.00)
      ,  OrderWeight    = ISNULL(m.[Weight],0.00)
      ,  OrderCartonCount= ISNULL(m.TotalCartons,0.)
      ,  OrderPalletCount= 0
      ,  PickPriority   = ''
      ,  ErrorCode      = ''
   FROM @t_ShipmentKey AS tsk
   JOIN dbo.MBOLDETAIL AS m WITH (NOLOCK) ON m.MbolKey = tsk.MbolKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.Orderkey = m.Orderkey

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66130
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_Transorder. (isp_MBOLToTransportOrder) '
                    + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_MBOLToTransportOrder'
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