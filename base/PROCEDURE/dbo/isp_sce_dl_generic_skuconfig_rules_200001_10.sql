SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKUCONFIG_RULES_200001_10       */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into SkuConfig target table       */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 = '0' Ignore existing SkuConfig */
/*                           @c_InParm1 = '1' Update is allow           */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKUCONFIG_RULES_200001_10] (
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

   DECLARE @c_Sku        NVARCHAR(20)
         , @c_StorerKey  NVARCHAR(15)
         , @c_ConfigType NVARCHAR(30)
         , @n_RowRefNo   INT
         , @n_FoundExist INT
         , @n_ActionFlag INT
         , @c_ttlMsg     NVARCHAR(250);

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

   BEGIN TRANSACTION 
   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(StorerKey)
        , TRIM(Sku)
        , TRIM(ConfigType)
   FROM dbo.SCE_DL_SKUCONFIG_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'  
   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @c_StorerKey
      , @c_Sku
      , @c_ConfigType   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_FoundExist = 0   
      SELECT @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_SKUCONFIG_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      AND   StorerKey     = @c_StorerKey
      AND   SKU           = @c_Sku
      AND   ConfigType    = @c_ConfigType 
      SELECT @n_FoundExist = 1
      FROM dbo.V_SKUConfig WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND   SKU         = @c_Sku
      AND   ConfigType  = @c_ConfigType   
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
            UPDATE dbo.SCE_DL_SKUCONFIG_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: Current Sku config records already exists in SkuConfig Table.'
            WHERE RowRefNo = @n_RowRefNo  
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
      END   
      IF @n_ActionFlag = 1
      BEGIN
         UPDATE SC WITH (ROWLOCK)
         SET SC.Data = ISNULL(STG.Data, '')
           , SC.userdefine01 = STG.userdefine01
           , SC.userdefine02 = STG.userdefine02
           , SC.userdefine03 = STG.userdefine03
           , SC.userdefine04 = STG.userdefine04
           , SC.userdefine05 = STG.userdefine05
           , SC.userdefine06 = STG.userdefine06
           , SC.userdefine07 = STG.userdefine07
           , SC.userdefine08 = STG.userdefine08
           , SC.userdefine09 = STG.userdefine09
           , SC.userdefine10 = STG.userdefine10
           , SC.userdefine11 = STG.userdefine11
           , SC.userdefine12 = STG.userdefine12
           , SC.userdefine13 = STG.userdefine13
           , SC.userdefine14 = STG.userdefine14
           , SC.userdefine15 = STG.userdefine15
           , SC.notes = CAST(STG.notes AS NVARCHAR(255))
           , SC.EditWho = @c_Username
           , SC.EditDate = GETDATE()
         FROM dbo.SKUConfig            SC
         JOIN dbo.SCE_DL_SKUCONFIG_STG STG WITH (NOLOCK)
         ON  STG.StorerKey   = SC.StorerKey
         AND STG.SKU        = SC.SKU
         AND STG.ConfigType = SC.ConfigType
         WHERE STG.RowRefNo = @n_RowRefNo 
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      ELSE IF @n_ActionFlag = 0
      BEGIN
         INSERT INTO dbo.SKUConfig
         (
            StorerKey
          , SKU
          , ConfigType
          , Data
          , userdefine01
          , userdefine02
          , userdefine03
          , userdefine04
          , userdefine05
          , userdefine06
          , userdefine07
          , userdefine08
          , userdefine09
          , userdefine10
          , userdefine11
          , userdefine12
          , userdefine13
          , userdefine14
          , userdefine15
          , notes
          , Addwho
          , EditWho
         )
         SELECT @c_StorerKey
              , @c_Sku
              , @c_ConfigType
              , ISNULL(Data, '')
              , userdefine01
              , userdefine02
              , userdefine03
              , userdefine04
              , userdefine05
              , userdefine06
              , userdefine07
              , userdefine08
              , userdefine09
              , userdefine10
              , userdefine11
              , userdefine12
              , userdefine13
              , userdefine14
              , userdefine15
              , CAST(notes AS NVARCHAR(255))
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_SKUCONFIG_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo  
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END   
      UPDATE dbo.SCE_DL_SKUCONFIG_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo  
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END   
      NEXTITEM: 
      FETCH NEXT FROM C_HDR
      INTO @c_StorerKey
         , @c_Sku
         , @c_ConfigType;
   END   
   CLOSE C_HDR;
   DEALLOCATE C_HDR  
   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKUCONFIG_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '');
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