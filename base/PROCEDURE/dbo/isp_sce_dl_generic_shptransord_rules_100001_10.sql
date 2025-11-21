SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100001_10     */
/* Creation Date: 11-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform LoadPlan with TMS Shipment Mapping.                */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform LoadPlan with TMS Shipment Mapping.       */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100001_10] (
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

   DECLARE @n_RowRefNo                  INT
         , @c_ShipmentGID               NVARCHAR(50)
         , @dt_ShipmentPlannedStartDate DATETIME
         , @c_ServiceProviderID         NVARCHAR(50)
         , @c_ttlErrMsg                 NVARCHAR(250);

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
              , ISNULL(RTRIM(ShipmentGID), '')
         FROM dbo.SCE_DL_TMS_SHP_TORD_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1';

         OPEN C_CHK_CONF;
         FETCH NEXT FROM C_CHK_CONF
         INTO @n_RowRefNo
            , @c_ShipmentGID;


         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @c_ttlErrMsg = N'';

            IF @c_ShipmentGID = ''
            BEGIN
               SET @c_ttlErrMsg += N'AltReference known as ShipmentGID cannot be null';
            END;
            ELSE
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.LoadPlan WITH (NOLOCK)
               WHERE ExternLoadKey = @c_ShipmentGID
               )
               BEGIN
                  SET @c_ttlErrMsg += N'AltReference known as ShipmentGID (' + @c_ShipmentGID + N') not exists in LoadPlan table';
               END;
               ELSE
               BEGIN

                  UPDATE STG WITH (ROWLOCK)
                  SET STG.DriveName = ISNULL(RTRIM(LP.Driver), '')
                    , STG.ShipmentPlannedStartDate = COALESCE(STG.ShipmentPlannedStartDate, LP.PickupDate, '')
                    , STG.ShipmentPlannedEndDate = COALESCE(
                                                      STG.ShipmentPlannedEndDate, STG.ShipmentPlannedStartDate, LP.PickupDate, ''
                                                   )
                    , STG.[Route] = ISNULL(RTRIM(LP.[Route]), '')
                    , STG.ServiceProviderID = RTRIM(COALESCE(STG.ServiceProviderID, LP.CarrierKey, ''))
                    , STG.ShipmentVolume = ISNULL(LP.[Cube], 0)
                    , STG.ShipmentWeight = ISNULL(LP.[Weight], 0)
                    , STG.ShipmentCartonCount = ISNULL(LP.CaseCnt, 0)
                    , STG.ShipmentPalletCount = ISNULL(LP.PalletCnt, 0)
                    , STG.ProvShipmentID = RTRIM(COALESCE(LP.ExternLoadKey, LP.LoadKey))
                    , STG.Principal = ISNULL(RTRIM(OBJ.StorerKey), '')
                    , STG.IOIndicator = 'O'
                  --, STG.ClientReferenceID = ISNULL(RTRIM(OBJ.ExternOrderKey), '')
                  --, STG.OrderSourceID = ISNULL(RTRIM(OBJ.OrderKey), '')
                  --, STG.Loadkey = ISNULL(RTRIM(OBJ.LoadKey), '')
                  --, STG.MBOLKey = ISNULL(RTRIM(OBJ.MBOLKey), '')
                  --, STG.OrderPrincipal = ISNULL(RTRIM(OBJ.StorerKey), '')
                  --, STG.Country = ISNULL(RTRIM(OBJ.C_ISOCntryCode), '')
                  --, STG.FacilityID = ISNULL(RTRIM(OBJ.Facility), '')
                  --, STG.OrderVolume = ISNULL(OBJ.[Cube], 0)
                  --, STG.OrderWeight = ISNULL(OBJ.[Weight], 0)
                  --, STG.OrderCartonCount = ISNULL(OBJ.CaseCnt, 0)
                  FROM dbo.SCE_DL_TMS_SHP_TORD_STG STG
                  INNER JOIN dbo.LoadPlan          LP WITH (NOLOCK)
                  ON STG.ShipmentGID = LP.ExternLoadKey
                  INNER JOIN (
                  SELECT TOP (1) LPD.LoadKey
                               , ORD.StorerKey
                               , LPD.OrderKey
                               , LPD.ExternOrderKey
                               , ORD.MBOLKey
                               , ORD.C_ISOCntryCode
                               , ORD.Facility
                               , LPD.[Cube]
                               , LPD.[Weight]
                               , LPD.CaseCnt
                  FROM dbo.LoadPlan             LP2 WITH (NOLOCK)
                  INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK)
                  ON LPD.LoadKey  = LP2.LoadKey
                  INNER JOIN dbo.ORDERS         ORD WITH (NOLOCK)
                  ON ORD.OrderKey = LPD.OrderKey
                  WHERE LP2.ExternLoadKey = @c_ShipmentGID
                  ORDER BY LPD.LoadLineNumber ASC
                  )                                AS OBJ
                  ON LP.LoadKey      = OBJ.LoadKey
                  WHERE STG.RowRefNo = @n_RowRefNo;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68001;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Insert record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100001_10)';
                     ROLLBACK;
                     GOTO STEP_999_EXIT_SP;

                  END;
               END;
            END;

            IF @c_ttlErrMsg <> ''
            BEGIN

               UPDATE dbo.SCE_DL_TMS_SHP_TORD_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = @c_ttlErrMsg
               WHERE RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 68002;
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100001_10)';
                  ROLLBACK TRANSACTION;
                  GOTO STEP_999_EXIT_SP;
               END;

            END;

            FETCH NEXT FROM C_CHK_CONF
            INTO @n_RowRefNo
               , @c_ShipmentGID;
         END;

         CLOSE C_CHK_CONF;
         DEALLOCATE C_CHK_CONF;
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3;
         SET @n_ErrNo = ERROR_NUMBER();
         SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100001_10)';
      END CATCH;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SHPTRANSORD_RULES_100001_10] EXIT... ErrMsg : '
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