SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_LoadToTransportOrder                                */
/* Creation Date: 2021-12-13                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3249 - UAT RG  Dock door booking backend + SP          */
/*        :                                                             */
/* Called By: ispFinalizeLoadPlan                                       */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-12-13  Wan      1.0   Created.                                  */
/* 2021-12-13  Wan      1.0   DevOps Combine Script.                    */
/* 2022-09-19  Wan01    1.1   LFWM-3739 - PH - SCE Finalize Loadplan    */
/*                            Validation                                */
/************************************************************************/
CREATE PROC [dbo].[isp_LoadToTransportOrder]
           @c_LoadKey            NVARCHAR(10) = ''
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
           @n_StartTCnt                   INT   = @@TRANCOUNT
         , @n_Continue                    INT   = 1
         
         ,  @c_Facility                   NVARCHAR(5) = ''           --(Wan01)
         ,  @c_Storerkey                  NVARCHAR(15)= ''           --(Wan01)
         ,  @dt_PickupDate                DATETIME    = NULL         --(Wan01)
         
         ,  @c_LoadToTransportOrder_Opt5  NVARCHAR(1000) = ''        --(Wan01)
         ,  @c_DefPickUpdDateIfNull       NVARCHAR(30) = 'N'         --(Wan01)  
      
   DECLARE @t_ShipmentKey     TABLE (  ShipmentGID    NVARCHAR(50)   NOT NULL DEFAULT ('')
                                    ,  Loadkey        NVARCHAR(10)   NOT NULL DEFAULT ('') )       

   SET @n_err      = 0
   SET @c_errmsg   = ''

   --(Wan01) - START
   SELECT TOP 1 
          @c_facility = lp.facility
         ,@c_Storerkey= o.Storerkey
         ,@dt_PickupDate=lp.PickupDate
   FROM dbo.LoadPlan AS lp WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.LoadKey = lp.LoadKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON lpd.OrderKey = o.Orderkey  
   WHERE lp.LoadKey = @c_Loadkey
   ORDER BY lpd.LoadLineNumber

   IF @dt_PickupDate IS NULL
   BEGIN
      SELECT @c_LoadToTransportOrder_Opt5 = fgr.Option5
      FROM dbo.fnc_GetRight2( @c_facility, @c_Storerkey, '','LoadToTransportOrder') AS fgr
      WHERE fgr.Authority = '1'
      
      SELECT @c_DefPickUpdDateIfNull = dbo.fnc_GetParamValueFromString('@c_DefPickUpdDateIfNull', @c_LoadToTransportOrder_Opt5, @c_DefPickUpdDateIfNull)

      IF @c_DefPickUpdDateIfNull = 'Y'
      BEGIN
         UPDATE dbo.LoadPlan
            SET PickupDate = GETDATE()
         WHERE LoadKey = @c_Loadkey
         AND PickupDate IS NULL
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 65105
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Update Loadplan. (isp_LoadToTransportOrder) '
                          + ' ( SQLSvr MESSAGE = ' + ERROR_MESSAGE() + ')'
            GOTO QUIT_SP
         END
      END
   END
   --(Wan01) - END

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
   OUTPUT INSERTED.ShipmentGID, @c_LoadKey INTO @t_ShipmentKey 
   SELECT
          ShipmentGID = CASE WHEN lp.ExternLoadKey <> '' AND lp.ExternLoadKey IS NOT NULL THEN lp.ExternLoadKey ELSE lp.Loadkey END         
       ,  VehicleLPN = N''           
       ,  EquipmentID = N''           
       ,  lp.Driver    
       ,  lp.PickUpDate    
       ,  ShipmentPlannedEndDate = GETDATE()    
       ,  [Route]             = lp.[Route]           
       ,  ServiceProviderID   = ISNULL(lp.CarrierKey,'') 
       ,  ShipmentVolume      = ISNULL(lp.[Cube],0.00)         
       ,  ShipmentWeight      = ISNULL(lp.[Weight],0.00)           
       ,  ShipmentCartonCount = ISNULL(lp.CaseCnt,0)         
       ,  ShipmentPalletCount = ISNULL(lp.PalletCnt,0)         
       ,  OTMShipmentStatus   = N'' 
   FROM dbo.LoadPlan AS lp WITH (NOLOCK)
   WHERE lp.LoadKey = @c_LoadKey
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65110
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_Shipment. (isp_LoadToTransportOrder) '
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
      SET @n_Err = 65120
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_ShipmentTransOrderLink. (isp_LoadToTransportOrder) '
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
      ,  OrderSourceID  = lpd.Orderkey
      ,  ClientReferenceID = lpd.ExternOrderKey
      ,  Loadkey  = lpd.Loadkey
      ,  MBOLkey  = o.MBOLkey 
      ,  ParentSourceID = ''
      ,  SplitFlag   = ''
      ,  Principal   = o.StorerKey
      ,  Country     = ISNULL(o.C_ISOCntryCode,'')
      ,  FacilityID  = o.Facility
      ,  StopSeq     = ''
      ,  IOIndicator = N'O'
      ,  StopServiceTime= ''
      ,  OrderVolume = lpd.[Cube]
      ,  OrderWeight = lpd.[Weight]
      ,  OrderCartonCount= lpd.CaseCnt
      ,  OrderPalletCount= 0
      ,  PickPriority= ''
      ,  ErrorCode   = ''
   FROM @t_ShipmentKey AS tsk
   JOIN dbo.LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.LoadKey = tsk.Loadkey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65130
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Inserting Data into TMS_Transorder. (isp_LoadToTransportOrder) '
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_LoadToTransportOrder'
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