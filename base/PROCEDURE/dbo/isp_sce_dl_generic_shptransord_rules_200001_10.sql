SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10     */
/* Creation Date: 11-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Insert into target table action.                   */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform Insert into target table action.          */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-Apr-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10] (
   @b_Debug       INT            = 0
 , @n_BatchNo     INT            = 0
 , @n_Flag        INT            = 0
 , @c_SubRuleJson NVARCHAR(MAX)
 , @c_STGTBL      NVARCHAR(250)  = ''
 , @c_POSTTBL     NVARCHAR(250)  = ''
 , @c_UniqKeyCol  NVARCHAR(1000) = ''
 , @c_Username    NVARCHAR(128)  = ''
 , @b_Success     INT            = 0 OUTPUT
 , @n_ErrNo       INT            = 0 OUTPUT
 , @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_WARNINGS OFF;

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT;

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60);
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo       INT
         , @c_ShipmentGID    NVARCHAR(50)
         , @c_ProvShipmentID NVARCHAR(50)
         , @n_ActionFlag     INT;

   --, @n_BookingNo       INT
   --, @c_ttlErrMsg        NVARCHAR(250);

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (
      SPName NVARCHAR(300) '$.SubRuleSP'
    , InParm1 NVARCHAR(60) '$.InParm1'
    , InParm2 NVARCHAR(60) '$.InParm2'
    , InParm3 NVARCHAR(60) '$.InParm3'
    , InParm4 NVARCHAR(60) '$.InParm4'
    , InParm5 NVARCHAR(60) '$.InParm5'
      )
   WHERE SPName = OBJECT_NAME(@@PROCID);

   SET @n_Continue = 1;

   SET @n_StartTCnt = @@TRANCOUNT;

   IF @c_InParm1 = '1'
   BEGIN

      BEGIN TRANSACTION;

      BEGIN TRY
         DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRefNo
              , ShipmentGID
              , ProvShipmentID
         FROM dbo.SCE_DL_TMS_SHP_TORD_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1';

         OPEN C_CHK_CONF;
         FETCH NEXT FROM C_CHK_CONF
         INTO @n_RowRefNo
            , @c_ShipmentGID
            , @c_ProvShipmentID;

         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @n_ActionFlag = 0;

            IF EXISTS (
            SELECT 1
            FROM dbo.TMS_Shipment WITH (NOLOCK)
            WHERE ShipmentGID = @c_ShipmentGID
            )
            BEGIN
               IF EXISTS (
               SELECT 1
               FROM dbo.TMS_Shipment WITH (NOLOCK)
               WHERE ShipmentGID                   = @c_ShipmentGID
               AND   (BookingNo IS NULL OR BookingNo = 0)
               )
               BEGIN
                  SET @n_ActionFlag = 1;

                  DELETE FROM dbo.TMS_Shipment
                  WHERE ShipmentGID                   = @c_ShipmentGID
                  AND   (BookingNo IS NULL OR BookingNo = 0);

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68002;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Update record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100002_10)';
                     ROLLBACK TRANSACTION;
                     GOTO STEP_999_EXIT_SP;
                  END;

                  DELETE FROM dbo.TMS_ShipmentTransOrderLink
                  WHERE ShipmentGID = @c_ShipmentGID;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68002;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Update record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100002_10)';
                     ROLLBACK TRANSACTION;
                     GOTO STEP_999_EXIT_SP;
                  END;

                  DELETE FROM dbo.TMS_TransportOrder
                  WHERE ProvShipmentID = @c_ShipmentGID;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68003;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Update record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100002_10)';
                     ROLLBACK TRANSACTION;
                     GOTO STEP_999_EXIT_SP;
                  END;
               END;
               ELSE
               BEGIN
                  UPDATE dbo.SCE_DL_TMS_SHP_TORD_STG WITH (ROWLOCK)
                  SET STG_Status = '5'
                    , STG_ErrMsg = 'Not Allow Insert! Record existed in TMS_Shipment table.'
                  WHERE RowRefNo = @n_RowRefNo;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68004;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Insert record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10)';
                     ROLLBACK;
                     GOTO STEP_999_EXIT_SP;

                  END;
                  GOTO NEXTITEM;
               END;
            END;
            ELSE
            BEGIN
               SET @n_ActionFlag = 1;
            END;

            IF @n_ActionFlag = 1
            BEGIN
               INSERT INTO dbo.TMS_Shipment
               (
                  ShipmentGID
                , VehicleLPN
                , EquipmentID
                , DriveName
                , ShipmentPlannedStartDate
                , ShipmentPlannedEndDate
                , [Route]
                , ServiceProviderID
                , ShipmentVolume
                , ShipmentWeight
                , ShipmentCartonCount
                , ShipmentPalletCount
                , OTMShipmentStatus
                , Banner
                , SubBanner
                , Wave
                , ShipmentGroupProfile
                , ShipmentGroup
                , AppointmentID
                , Principal
                , BookingNo
                , Addwho
                , Editwho
               )
               SELECT ShipmentGID
                    , ISNULL(RTRIM(VehicleLPN), '')
                    , ISNULL(RTRIM(EquipmentID), '')
                    , ISNULL(RTRIM(DriveName), '')
                    , ShipmentPlannedStartDate
                    , ShipmentPlannedEndDate
                    , ISNULL(RTRIM([Route]), '')
                    , ISNULL(RTRIM(ServiceProviderID), '')
                    , ISNULL(ShipmentVolume, 0)
                    , ISNULL(ShipmentWeight, 0)
                    , ISNULL(ShipmentCartonCount, 0)
                    , ISNULL(ShipmentPalletCount, 0)
                    , ISNULL(RTRIM(OTMShipmentStatus), '')
                    , ISNULL(RTRIM(Banner), '')
                    , ISNULL(RTRIM(SubBanner), '')
                    , ISNULL(RTRIM(Wave), '')
                    , ISNULL(RTRIM(ShipmentGroupProfile), '')
                    , ISNULL(RTRIM(ShipmentGroup), '')
                    , ISNULL(RTRIM(AppointmentID), '')
                    , ISNULL(RTRIM(Principal), '')
                    , BookingNo
                    , @c_Username
                    , @c_Username
               FROM dbo.SCE_DL_TMS_SHP_TORD_STG WITH (NOLOCK)
               WHERE RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 68001;
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Insert record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10)';
                  ROLLBACK;
                  GOTO STEP_999_EXIT_SP;

               END;

               INSERT INTO dbo.TMS_ShipmentTransOrderLink (ProvShipmentID, ShipmentGID)
               VALUES
               (@c_ProvShipmentID, @c_ShipmentGID);

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 68003;
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Insert record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10)';
                  ROLLBACK;
                  GOTO STEP_999_EXIT_SP;

               END;


               INSERT INTO dbo.TMS_TransportOrder
               (
                  ProvShipmentID
                , OrderReleaseID
                , OrderSourceID
                , ClientReferenceID
                , Loadkey
                , MBOLKey
                , ParentSourceID
                , SplitFlag
                , Principal
                , Country
                , FacilityID
                , StopSeq
                , IOIndicator
                , StopServiceTime
                , OrderVolume
                , OrderWeight
                , OrderCartonCount
                , OrderPalletCount
                , PickPriority
                , ErrorCode
                , Addwho
                , Editwho
               )
               SELECT STG.ProvShipmentID
                    , ISNULL(RTRIM(STG.OrderReleaseID), '')
                    , ISNULL(RTRIM(LPD.OrderKey), '')
                    , ISNULL(RTRIM(LPD.ExternOrderKey), '')
                    , ISNULL(RTRIM(LPD.LoadKey), '')
                    , ISNULL(RTRIM(ORD.MBOLKey), '')
                    , ISNULL(RTRIM(STG.ParentSourceID), '')
                    , ISNULL(RTRIM(STG.SplitFlag), '')
                    , ISNULL(RTRIM(STG.Principal), '')
                    , ISNULL(RTRIM(ORD.C_ISOCntryCode), '')
                    , ISNULL(RTRIM(ORD.Facility), '')
                    , ISNULL(STG.StopSeq, 0)
                    , ISNULL(RTRIM(STG.IOIndicator), '')
                    , ISNULL(STG.StopServiceTime, 0)
                    , ISNULL(LPD.[Cube], 0)
                    , ISNULL(LPD.[Weight], 0)
                    , ISNULL(LPD.CaseCnt, 0)
                    , ISNULL(STG.OrderPalletCount, 0)
                    , ISNULL(RTRIM(STG.PickPriority), '')
                    , ISNULL(RTRIM(STG.ErrorCode), '')
                    , @c_Username
                    , @c_Username
               FROM dbo.SCE_DL_TMS_SHP_TORD_STG STG WITH (NOLOCK)
               INNER JOIN dbo.LoadPlan          LP WITH (NOLOCK)
               ON STG.ShipmentGID = LP.ExternLoadKey
               INNER JOIN dbo.LoadPlanDetail    LPD WITH (NOLOCK)
               ON LPD.LoadKey     = LP.LoadKey
               INNER JOIN dbo.ORDERS            ORD WITH (NOLOCK)
               ON ORD.OrderKey    = LPD.OrderKey
               WHERE STG.RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 68002;
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Insert record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10)';
                  ROLLBACK;
                  GOTO STEP_999_EXIT_SP;

               END;
            END;


            UPDATE dbo.SCE_DL_TMS_SHP_TORD_STG WITH (ROWLOCK)
            SET STG_Status = '9'
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68004;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Insert record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;

            END;

            NEXTITEM:
            FETCH NEXT FROM C_CHK_CONF
            INTO @n_RowRefNo
               , @c_ShipmentGID
               , @c_ProvShipmentID;
         END;

         CLOSE C_CHK_CONF;
         DEALLOCATE C_CHK_CONF;
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3;
         SET @n_ErrNo = ERROR_NUMBER();
         SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10)';
      END CATCH;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   IF @n_Continue = 3
   BEGIN
      IF @n_ErrNo = 0
         SET @n_ErrNo = 11999;

      SET @b_Success = 0;
      IF  @@TRANCOUNT = 1
      AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN;
         END;
      END;
   END;
   ELSE
   BEGIN
      SET @b_Success = 1;
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN;
      END;
   END;
END;

GO