SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKUINFO_RULES_200002_10         */
/* Creation Date: 06-Mar-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-21909 Perform insert or update into SKUINFO table      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore existing SKUInfo */
/*                           @c_InParm1 =  '1'  Update columns in Excel */
/*                                              only                    */
/*                           @c_InParm1 =  '2'  Update ALL              */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data MoSIfications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 06-Mar-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKUINFO_RULES_200002_10]
(
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @c_SKU        NVARCHAR(20)
         , @c_StorerKey  NVARCHAR(15)
         , @n_RowRefNo   INT
         , @n_FoundExist INT
         , @n_ActionFlag INT
         , @c_ttlMsg     NVARCHAR(250)

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (SPName NVARCHAR(300) '$.SubRuleSP'
          , InParm1 NVARCHAR(60) '$.InParm1'
          , InParm2 NVARCHAR(60) '$.InParm2'
          , InParm3 NVARCHAR(60) '$.InParm3'
          , InParm4 NVARCHAR(60) '$.InParm4'
          , InParm5 NVARCHAR(60) '$.InParm5')
   WHERE SPName = OBJECT_NAME(@@PROCID)

   BEGIN TRANSACTION

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , TRIM(StorerKey)
        , TRIM(SKU)
   FROM dbo.SCE_DL_SKUINFO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1'

   OPEN C_HDR
   FETCH NEXT FROM C_HDR
   INTO @n_RowRefNo
      , @c_StorerKey
      , @c_SKU

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_FoundExist = 0

      SELECT @n_FoundExist = 1
      FROM SkuInfo WITH (NOLOCK)
      WHERE Storerkey = @c_StorerKey AND Sku = @c_SKU

      IF @c_InParm1 IN ('1','2')
      BEGIN
         IF @n_FoundExist = 1
         BEGIN
            SET @n_ActionFlag = 1 -- UPDATE
         END
         ELSE
         BEGIN
            SET @n_ActionFlag = 0 -- INSERT
         END
      END
      ELSE IF @c_InParm1 = '0'
      BEGIN
         IF @n_FoundExist = 1
         BEGIN
            UPDATE dbo.SCE_DL_SKUINFO_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error:SKUINFO with Storer ' + TRIM(@c_StorerKey) + N' and SKU ' + TRIM(@c_SKU)
                             + 'already exists in SKUINFO.'
            WHERE RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
            GOTO NEXTITEM
         END
         ELSE
         BEGIN
            SET @n_ActionFlag = 0 -- INSERT
         END
      END

      IF @n_ActionFlag = 1
      BEGIN
         IF @c_InParm1 = '1'
         BEGIN
            UPDATE SI WITH (ROWLOCK)
            SET SI.ExtendedField01 = CASE WHEN ISNULL(TRIM(STG.ExtendedField01), '') = '' THEN SI.ExtendedField01
                                          ELSE TRIM(STG.ExtendedField01)END
              , SI.ExtendedField02 = CASE WHEN ISNULL(TRIM(STG.ExtendedField02), '') = '' THEN SI.ExtendedField02
                                          ELSE TRIM(STG.ExtendedField02)END
              , SI.ExtendedField03 = CASE WHEN ISNULL(TRIM(STG.ExtendedField03), '') = '' THEN SI.ExtendedField03
                                          ELSE TRIM(STG.ExtendedField03)END
              , SI.ExtendedField04 = CASE WHEN ISNULL(TRIM(STG.ExtendedField04), '') = '' THEN SI.ExtendedField04
                                          ELSE TRIM(STG.ExtendedField04)END
              , SI.ExtendedField05 = CASE WHEN ISNULL(TRIM(STG.ExtendedField05), '') = '' THEN SI.ExtendedField05
                                          ELSE TRIM(STG.ExtendedField05)END
              , SI.ExtendedField06 = CASE WHEN ISNULL(TRIM(STG.ExtendedField06), '') = '' THEN SI.ExtendedField06
                                          ELSE TRIM(STG.ExtendedField06)END
              , SI.ExtendedField07 = CASE WHEN ISNULL(TRIM(STG.ExtendedField07), '') = '' THEN SI.ExtendedField07
                                          ELSE TRIM(STG.ExtendedField07)END
              , SI.ExtendedField08 = CASE WHEN ISNULL(TRIM(STG.ExtendedField08), '') = '' THEN SI.ExtendedField08
                                          ELSE TRIM(STG.ExtendedField08)END
              , SI.ExtendedField09 = CASE WHEN ISNULL(TRIM(STG.ExtendedField09), '') = '' THEN SI.ExtendedField09
                                          ELSE TRIM(STG.ExtendedField09)END
              , SI.ExtendedField10 = CASE WHEN ISNULL(TRIM(STG.ExtendedField10), '') = '' THEN SI.ExtendedField10
                                          ELSE TRIM(STG.ExtendedField10)END
              , SI.ExtendedField11 = CASE WHEN ISNULL(TRIM(STG.ExtendedField11), '') = '' THEN SI.ExtendedField11
                                          ELSE TRIM(STG.ExtendedField11)END
              , SI.ExtendedField12 = CASE WHEN ISNULL(TRIM(STG.ExtendedField12), '') = '' THEN SI.ExtendedField12
                                          ELSE TRIM(STG.ExtendedField12)END
              , SI.ExtendedField13 = CASE WHEN ISNULL(TRIM(STG.ExtendedField13), '') = '' THEN SI.ExtendedField13
                                          ELSE TRIM(STG.ExtendedField13)END
              , SI.ExtendedField14 = CASE WHEN ISNULL(TRIM(STG.ExtendedField14), '') = '' THEN SI.ExtendedField14
                                          ELSE TRIM(STG.ExtendedField14)END
              , SI.ExtendedField15 = CASE WHEN ISNULL(TRIM(STG.ExtendedField15), '') = '' THEN SI.ExtendedField15
                                          ELSE TRIM(STG.ExtendedField15)END
              , SI.ExtendedField16 = CASE WHEN ISNULL(TRIM(STG.ExtendedField16), '') = '' THEN SI.ExtendedField16
                                          ELSE TRIM(STG.ExtendedField16)END
              , SI.ExtendedField17 = CASE WHEN ISNULL(TRIM(STG.ExtendedField17), '') = '' THEN SI.ExtendedField17
                                          ELSE TRIM(STG.ExtendedField17)END
              , SI.ExtendedField18 = CASE WHEN ISNULL(TRIM(STG.ExtendedField18), '') = '' THEN SI.ExtendedField18
                                          ELSE TRIM(STG.ExtendedField18)END
              , SI.ExtendedField19 = CASE WHEN ISNULL(TRIM(STG.ExtendedField19), '') = '' THEN SI.ExtendedField19
                                          ELSE TRIM(STG.ExtendedField19)END
              , SI.ExtendedField20 = CASE WHEN ISNULL(TRIM(STG.ExtendedField20), '') = '' THEN SI.ExtendedField20
                                          ELSE TRIM(STG.ExtendedField20)END
              , SI.ExtendedField21 = CASE WHEN ISNULL(TRIM(STG.ExtendedField21), '') = '' THEN SI.ExtendedField21
                                          ELSE TRIM(STG.ExtendedField21)END
              , SI.ExtendedField22 = CASE WHEN ISNULL(TRIM(STG.ExtendedField22), '') = '' THEN SI.ExtendedField22
                                          ELSE TRIM(STG.ExtendedField22)END
              , SI.EditWho = @c_Username
              , SI.EditDate = GETDATE()
            FROM dbo.SkuInfo SI
            JOIN dbo.SCE_DL_SKUINFO_STG STG WITH (NOLOCK) ON STG.Storerkey = SI.Storerkey AND STG.Sku = SI.Sku
            WHERE STG.RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            UPDATE SI WITH (ROWLOCK)
            SET SI.ExtendedField01 = ISNULL(STG.ExtendedField01,'')
              , SI.ExtendedField02 = ISNULL(STG.ExtendedField02,'')
              , SI.ExtendedField03 = ISNULL(STG.ExtendedField03,'')
              , SI.ExtendedField04 = ISNULL(STG.ExtendedField04,'')
              , SI.ExtendedField05 = ISNULL(STG.ExtendedField05,'')
              , SI.ExtendedField06 = ISNULL(STG.ExtendedField06,'')
              , SI.ExtendedField07 = ISNULL(STG.ExtendedField07,'')
              , SI.ExtendedField08 = ISNULL(STG.ExtendedField08,'')
              , SI.ExtendedField09 = ISNULL(STG.ExtendedField09,'')
              , SI.ExtendedField10 = ISNULL(STG.ExtendedField10,'')
              , SI.ExtendedField11 = ISNULL(STG.ExtendedField11,'')
              , SI.ExtendedField12 = ISNULL(STG.ExtendedField12,'')
              , SI.ExtendedField13 = ISNULL(STG.ExtendedField13,'')
              , SI.ExtendedField14 = ISNULL(STG.ExtendedField14,'')
              , SI.ExtendedField15 = ISNULL(STG.ExtendedField15,'')
              , SI.ExtendedField16 = ISNULL(STG.ExtendedField16,'')
              , SI.ExtendedField17 = ISNULL(STG.ExtendedField17,'')
              , SI.ExtendedField18 = ISNULL(STG.ExtendedField18,'')
              , SI.ExtendedField19 = ISNULL(STG.ExtendedField19,'')
              , SI.ExtendedField20 = ISNULL(STG.ExtendedField20,'')
              , SI.ExtendedField21 = ISNULL(STG.ExtendedField21,'')
              , SI.ExtendedField22 = ISNULL(STG.ExtendedField22,'')
              , SI.EditWho = @c_Username
              , SI.EditDate = GETDATE()
            FROM dbo.SkuInfo SI
            JOIN dbo.SCE_DL_SKUINFO_STG STG WITH (NOLOCK) ON STG.Storerkey = SI.Storerkey AND STG.Sku = SI.Sku
            WHERE STG.RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END
      END
      ELSE IF @n_ActionFlag = 0
      BEGIN
         INSERT INTO dbo.SkuInfo (Storerkey, Sku, ExtendedField01, ExtendedField02, ExtendedField03, ExtendedField04
                                , ExtendedField05, ExtendedField06, ExtendedField07, ExtendedField08, ExtendedField09
                                , ExtendedField10, ExtendedField11, ExtendedField12, ExtendedField13, ExtendedField14
                                , ExtendedField15, ExtendedField16, ExtendedField17, ExtendedField18, ExtendedField19
                                , ExtendedField20, AddWho, ExtendedField21, ExtendedField22, EditWho)
         SELECT Storerkey
              , Sku
              , ISNULL(ExtendedField01,'')
              , ISNULL(ExtendedField02,'')
              , ISNULL(ExtendedField03,'')
              , ISNULL(ExtendedField04,'')
              , ISNULL(ExtendedField05,'')
              , ISNULL(ExtendedField06,'')
              , ISNULL(ExtendedField07,'')
              , ISNULL(ExtendedField08,'')
              , ISNULL(ExtendedField09,'')
              , ISNULL(ExtendedField10,'')
              , ISNULL(ExtendedField11,'')
              , ISNULL(ExtendedField12,'')
              , ISNULL(ExtendedField13,'')
              , ISNULL(ExtendedField14,'')
              , ISNULL(ExtendedField15,'')
              , ISNULL(ExtendedField16,'')
              , ISNULL(ExtendedField17,'')
              , ISNULL(ExtendedField18,'')
              , ISNULL(ExtendedField19,'')
              , ISNULL(ExtendedField20,'')
              , @c_Username
              , ISNULL(ExtendedField21,'')
              , ISNULL(ExtendedField22,'')
              , @c_Username
         FROM dbo.SCE_DL_SKUINFO_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END

      UPDATE dbo.SCE_DL_SKUINFO_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXTITEM:

      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_StorerKey
         , @c_SKU
   END

   CLOSE C_HDR
   DEALLOCATE C_HDR

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN ( 0, 1 )
   BEGIN
      CLOSE C_HDR
      DEALLOCATE C_HDR
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKUINFO_RULES_200002_10] EXIT... ErrMsg : '
             + ISNULL(TRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1
   END
   ELSE
   BEGIN
      SET @b_Success = 0
   END
END

GO