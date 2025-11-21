SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_PUTAWAYZONE_RULES_200001_10     */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into PUTAWAYZONE target table     */
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
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_PUTAWAYZONE_RULES_200001_10] (
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

   DECLARE @c_PutawayZone     NVARCHAR(10)
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
   SELECT RowRefNo
        , RTRIM(PutawayZone)
   FROM dbo.SCE_DL_PUTAWAYZONE_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @n_RowRefNo
      , @c_PutawayZone;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_FoundExist = 0;

      IF EXISTS (
      SELECT 1
      FROM dbo.V_PutawayZone WITH (NOLOCK)
      WHERE PutawayZone = @c_PutawayZone
      )
      BEGIN
         SET @n_FoundExist = 1;
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
            UPDATE dbo.SCE_DL_PUTAWAYZONE_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: PutawayZone already exists.User not allow to update'
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
         INSERT INTO dbo.PutawayZone
         (
            PutawayZone
          , Descr
          , InLoc
          , OutLoc
          , facility
          , ZoneCategory
          , Pallet_type
          , Floor
         )
         SELECT @c_PutawayZone
              , Descr
              , ISNULL(InLoc, '')
              , ISNULL(OutLoc, '')
              , ISNULL(facility, '')
              , ISNULL(ZoneCategory, '')
              , ISNULL(Pallet_type, '')
              , ISNULL(Floor, '')
         FROM dbo.SCE_DL_PUTAWAYZONE_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      ELSE IF @n_ActionFlag = 1
      BEGIN
         UPDATE TGT WITH (ROWLOCK)
         SET TGT.InLoc = ISNULL(STG.InLoc, TGT.InLoc)
           , TGT.OutLoc = ISNULL(STG.OutLoc, TGT.OutLoc)
           , TGT.facility = ISNULL(STG.facility, TGT.facility)
           , TGT.ZoneCategory = ISNULL(STG.ZoneCategory, TGT.ZoneCategory)
           , TGT.Pallet_type = ISNULL(STG.Pallet_type, TGT.Pallet_type)
           , TGT.Floor = ISNULL(STG.Floor, TGT.Floor)
           , TGT.EditWho = @c_Username
           , TGT.EditDate = GETDATE()
         FROM dbo.PutawayZone                  TGT
         INNER JOIN dbo.SCE_DL_PUTAWAYZONE_STG STG WITH (NOLOCK)
         ON TGT.PutawayZone = STG.PutawayZone
         WHERE STG.RowRefNo = @n_RowRefNo;


         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;

      UPDATE dbo.SCE_DL_PUTAWAYZONE_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      NEXTITEM:
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_PutawayZone;
   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_PUTAWAYZONE_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(RTRIM(@c_ErrMsg), '');
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