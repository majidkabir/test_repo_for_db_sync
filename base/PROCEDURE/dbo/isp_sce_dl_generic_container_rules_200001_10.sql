SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CONTAINER_RULES_200001_10       */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into Container target table       */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore update           */
/*                           @c_InParm1 =  '1'  Update is allow         */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/* 01-Mar-2023  WLChooi   1.1   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CONTAINER_RULES_200001_10] (
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

   DECLARE @c_ContainerKey    NVARCHAR(20)
         , @c_PalletKey       NVARCHAR(30)
         , @c_WorkOrderKey    NVARCHAR(10)
         , @n_ActionFlag      INT
         , @n_ChkStatus       NVARCHAR(5)
         , @n_FoundExist      INT
         , @n_ContLineNoCount INT
         , @c_Facility        NVARCHAR(5)
         , @c_AdjustmentType  NVARCHAR(5)
         , @n_RowRefNo        INT
         , @c_AdjustmentKey   NVARCHAR(10)
         , @n_GetQty          INT
         , @c_UOM             NVARCHAR(10)
         , @c_Packkey         NVARCHAR(10)
         , @c_Sku             NVARCHAR(20)
         , @n_Qty             INT
         , @n_iNo             INT
         , @c_ttlMsg          NVARCHAR(250);

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

   BEGIN TRANSACTION;

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TRIM(ContainerKey)
   FROM dbo.SCE_DL_CONTAINER_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @c_ContainerKey;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_ChkStatus = N'';
      SET @n_FoundExist = 0;

      SELECT TOP (1) @n_RowRefNo  = RowRefNo
                   , @c_PalletKey = PalletKey
      FROM dbo.SCE_DL_CONTAINER_STG WITH (NOLOCK)
      WHERE STG_BatchNo       = @n_BatchNo
      AND   STG_Status          = '1'
      AND   TRIM(ContainerKey) = @c_ContainerKey
      ORDER BY STG_SeqNo ASC;

      IF EXISTS (
      SELECT 1
      FROM dbo.V_CONTAINERDETAIL WITH (NOLOCK)
      WHERE ContainerKey = @c_ContainerKey
      AND   PalletKey      = @c_PalletKey
      )
      BEGIN
         UPDATE dbo.SCE_DL_CONTAINER_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = 'Error:PalletKey( ' + @c_PalletKey + ') already exists.Insert Fail.'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
         GOTO NEXTITEM;
      END;

      SELECT @n_FoundExist = 1
           , @n_ChkStatus  = ISNULL(TRIM([Status]), '')
      FROM dbo.V_CONTAINER WITH (NOLOCK)
      WHERE ContainerKey = @c_ContainerKey;

      IF  @n_FoundExist = 1
      AND @n_ChkStatus = '9'
      BEGIN
         UPDATE dbo.SCE_DL_CONTAINER_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = 'Error:ContainerKey( ' + @c_ContainerKey + ') already status 9, update failed.'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
         GOTO NEXTITEM;
      END;

      IF @c_InParm1 = '1'
      BEGIN
         IF @n_FoundExist = 1
         BEGIN
            SET @n_ActionFlag = 1; -- UPDATE
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;
      ELSE IF @c_InParm1 = '0'
      BEGIN
         IF @n_FoundExist = 1
         BEGIN
            UPDATE dbo.SCE_DL_CONTAINER_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error:ContainerKey already exists.User not allow to update'
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
            GOTO NEXTITEM;
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;

      IF @n_ActionFlag = 0
      BEGIN
         INSERT INTO dbo.CONTAINER
         (
            ContainerKey
          , Status
          , Vessel
          , Voyage
          , CarrierKey
          , Carrieragent
          , ETA
          , ETADestination
          , BookingReference
          , OtherReference
          , Seal01
          , Seal02
          , Seal03
          , ContainerType
          , MBOLKey
          , ExternContainerKey
          , UserDefine01
          , UserDefine02
          , UserDefine03
          , UserDefine04
          , UserDefine05
          , AddWho
          , EditWho
         )
         SELECT ISNULL(TRIM(@c_ContainerKey), '')
              , ISNULL(TRIM(Status), '0')
              , ISNULL(TRIM(Vessel), '')
              , ISNULL(TRIM(Voyage), '')
              , ISNULL(TRIM(CarrierKey), '')
              , ISNULL(TRIM(Carrieragent), '')
              , ETA
              , ETADestination
              , ISNULL(TRIM(BookingReference), '')
              , ISNULL(TRIM(OtherReference), '')
              , ISNULL(TRIM(Seal01), '')
              , ISNULL(TRIM(Seal02), '')
              , ISNULL(TRIM(Seal03), '')
              , ISNULL(TRIM(ContainerType), '')
              , ISNULL(TRIM(MBOLKey), '')
              , ISNULL(TRIM(ExternContainerKey), '')
              , ISNULL(TRIM(HUserDefine01), '')
              , ISNULL(TRIM(HUserDefine02), '')
              , ISNULL(TRIM(HUserDefine03), '')
              , ISNULL(TRIM(HUserDefine04), '')
              , ISNULL(TRIM(HUserDefine05), '')
              , @c_Username
              , @c_Username
         FROM SCE_DL_CONTAINER_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;

      SET @n_iNo = 0;

      DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , TRIM(PalletKey)
      FROM dbo.SCE_DL_CONTAINER_STG WITH (NOLOCK)
      WHERE STG_BatchNo       = @n_BatchNo
      AND   STG_Status          = '1'
      AND   TRIM(ContainerKey) = @c_ContainerKey;

      OPEN C_DET;

      FETCH NEXT FROM C_DET
      INTO @n_RowRefNo
         , @c_PalletKey;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_ContLineNoCount = 0;

         SELECT @n_ContLineNoCount = ISNULL(MAX(1), 0)
         FROM dbo.V_CONTAINERDETAIL WITH (NOLOCK)
         WHERE ContainerKey = @c_ContainerKey;

         INSERT INTO dbo.CONTAINERDETAIL
         (
            PalletKey
          , ContainerKey
          , ContainerLineNumber
          , UserDefine01
          , UserDefine02
          , UserDefine03
          , UserDefine04
          , UserDefine05
          , AddWho
          , EditWho
         )
         SELECT @c_PalletKey
              , @c_ContainerKey
              , CASE WHEN @n_ContLineNoCount > 0 THEN CAST(FORMAT((@n_ContLineNoCount + 1), 'D5') AS NVARCHAR(5))
                     ELSE CAST(FORMAT(1, 'D5') AS NVARCHAR(5))
                END
              , ISNULL(TRIM(DUserDefine01), '')
              , ISNULL(TRIM(DUserDefine02), '')
              , ISNULL(TRIM(DUserDefine03), '')
              , ISNULL(TRIM(DUserDefine04), '')
              , ISNULL(TRIM(DUserDefine05), '')
              , @c_Username
              , @c_Username
         FROM SCE_DL_CONTAINER_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo
         AND Palletkey = @c_PalletKey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         UPDATE dbo.SCE_DL_CONTAINER_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo
            , @c_PalletKey;
      END;
      CLOSE C_DET;
      DEALLOCATE C_DET;

      NEXTITEM:
      FETCH NEXT FROM C_HDR
      INTO @c_ContainerKey;
   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN ( 0, 1 )
   BEGIN
      CLOSE C_HDR
      DEALLOCATE C_HDR
   END

   IF CURSOR_STATUS('LOCAL', 'C_DET') IN ( 0, 1 )
   BEGIN
      CLOSE C_DET
      DEALLOCATE C_DET
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CONTAINER_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '');
   END;

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1;
   END;
   ELSE
   BEGIN
      SET @b_Success = 0;
   END;
END;

GO