SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKU_RULES_100007_10             */
/* Creation Date: 17-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform PackKey checking                                   */
/*                                                                      */
/*                                                                      */
/* Usage: 			                                                      */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 17-Jan-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKU_RULES_100007_10] (
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

   DECLARE @c_StorerKey  NVARCHAR(15)
         , @c_Sku        NVARCHAR(20)
         , @c_PACKKey    NVARCHAR(10)
         , @c_IB_UOM     NVARCHAR(10)
         , @c_IB_RPT_UOM NVARCHAR(10)
         , @c_OB_UOM     NVARCHAR(10)
         , @c_OB_RPT_UOM NVARCHAR(10)
         , @c_PackUOM1   NVARCHAR(10)
         , @c_PackUOM2   NVARCHAR(10)
         , @c_PackUOM3   NVARCHAR(10)
         , @c_PackUOM4   NVARCHAR(10)
         , @c_PackUOM5   NVARCHAR(10)
         , @c_PackUOM6   NVARCHAR(10)
         , @c_PackUOM7   NVARCHAR(10)
         , @c_PackUOM8   NVARCHAR(10)
         , @c_PackUOM9   NVARCHAR(10)
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

   --IF EXISTS (
   --SELECT 1
   --FROM dbo.SCE_DL_SKU_STG WITH (NOLOCK)
   --WHERE STG_BatchNo              = @n_BatchNo
   --AND   STG_Status                 = '1'
   --AND   (PACKKey IS NULL OR RTRIM(Sku) = '')
   --)
   --BEGIN
   --   BEGIN TRANSACTION;

   --   UPDATE SCE_DL_SKU_STG WITH (ROWLOCK)
   --   SET STG_Status = '3'
   --     , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/SKU is Null'
   --   WHERE STG_BatchNo              = @n_BatchNo
   --   AND   STG_Status                 = '1'
   --   AND   (Sku IS NULL OR RTRIM(Sku) = '');

   --   IF @@ERROR <> 0
   --   BEGIN
   --      SET @n_Continue = 3;
   --      SET @n_ErrNo = 68001;
   --      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
   --                      + ': Update record fail. (isp_SCE_DL_GENERIC_SKU_RULES_100005_10)';
   --      ROLLBACK;
   --      GOTO STEP_999_EXIT_SP;
   --   END;
   --   COMMIT;
   --END;

   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RTRIM(StorerKey)
        , RTRIM(Sku)
        , ISNULL(RTRIM(PACKKey), '')
        , ISNULL(RTRIM(IB_UOM), '')
        , ISNULL(RTRIM(IB_RPT_UOM), '')
        , ISNULL(RTRIM(OB_UOM), '')
        , ISNULL(RTRIM(OB_RPT_UOM), '')
   FROM dbo.SCE_DL_SKU_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   --AND   StorerKey IS NOT NULL
   --AND   RTRIM(StorerKey) <> ''
   GROUP BY RTRIM(StorerKey)
          , RTRIM(Sku)
          , ISNULL(RTRIM(PACKKey), '')
          , ISNULL(RTRIM(IB_UOM), '')
          , ISNULL(RTRIM(IB_RPT_UOM), '')
          , ISNULL(RTRIM(OB_UOM), '')
          , ISNULL(RTRIM(OB_RPT_UOM), '');

   OPEN C_CHK;
   FETCH NEXT FROM C_CHK
   INTO @c_StorerKey
      , @c_Sku
      , @c_PACKKey
      , @c_IB_UOM
      , @c_IB_RPT_UOM
      , @c_OB_UOM
      , @c_OB_RPT_UOM;


   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N'';

      IF @c_PACKKey = ''
      BEGIN
         SELECT @c_PACKKey = PACKKey
         FROM dbo.V_SKU WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND   Sku         = @c_Sku;
      END;
      ELSE
      BEGIN
         IF NOT EXISTS (
         SELECT 1
         FROM dbo.V_PACK WITH (NOLOCK)
         WHERE PackKey = @c_PACKKey
         )
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Packkey not exists';
      END;

      IF (
          ISNULL(@c_IB_UOM, '') <> ''
       OR ISNULL(@c_IB_RPT_UOM, '') <> ''
       OR ISNULL(@c_OB_UOM, '') <> ''
       OR ISNULL(@c_OB_RPT_UOM, '') <> ''
      )
      BEGIN
         SELECT @c_PackUOM1 = PackUOM1
              --, @n_CaseCnt    = CaseCnt
              , @c_PackUOM2 = PackUOM2
              --, @n_InnerPack  = InnerPack
              , @c_PackUOM3 = PackUOM3
              --, @n_uom3Qty    = Qty
              , @c_PackUOM4 = PackUOM4
              --, @n_Pallet     = Pallet
              , @c_PackUOM5 = PackUOM5
              --, @n_Cube       = Cube
              , @c_PackUOM6 = PackUOM6
              --, @n_GrossWgt   = GrossWgt
              , @c_PackUOM7 = PackUOM7
              --, @n_NetWgt     = NetWgt
              , @c_PackUOM8 = PackUOM8
              --, @n_OtherUnit1 = OtherUnit1
              , @c_PackUOM9 = PackUOM9
         --, @n_OtherUnit2 = OtherUnit2
         FROM dbo.V_PACK (NOLOCK)
         WHERE PackKey = @c_PACKKey;


         IF @c_IB_UOM NOT IN (@c_PackUOM1, @c_PackUOM2, @c_PackUOM3, @c_PackUOM4, @c_PackUOM5, @c_PackUOM6, @c_PackUOM7
                            , @c_PackUOM8, @c_PackUOM9
         )
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Default Inbound UOM not exists';
         END;

         IF @c_IB_RPT_UOM NOT IN (@c_PackUOM1, @c_PackUOM2, @c_PackUOM3, @c_PackUOM4, @c_PackUOM5, @c_PackUOM6, @c_PackUOM7
                                , @c_PackUOM8, @c_PackUOM9
         )
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Default inbound reporting UOM not exists';
         END;

         IF @c_OB_UOM NOT IN (@c_PackUOM1, @c_PackUOM2, @c_PackUOM3, @c_PackUOM4, @c_PackUOM5, @c_PackUOM6, @c_PackUOM7
                            , @c_PackUOM8, @c_PackUOM9
         )
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Default Onbound UOM not exists';
         END;

         IF @c_OB_RPT_UOM NOT IN (@c_PackUOM1, @c_PackUOM2, @c_PackUOM3, @c_PackUOM4, @c_PackUOM5, @c_PackUOM6, @c_PackUOM7
                                , @c_PackUOM8, @c_PackUOM9
         )
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Default Onbound reporting UOM not exists';
         END;
      END;

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_SKU_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo                 = @n_BatchNo
         AND   STG_Status                    = '1'
         AND   RTRIM(StorerKey)              = @c_StorerKey
         AND   RTRIM(Sku)                    = @c_Sku
         AND   ISNULL(RTRIM(PACKKey), '')    = @c_PACKKey
         AND   ISNULL(RTRIM(IB_UOM), '')     = @c_IB_UOM
         AND   ISNULL(RTRIM(IB_RPT_UOM), '') = @c_IB_RPT_UOM
         AND   ISNULL(RTRIM(OB_UOM), '')     = @c_OB_UOM
         AND   ISNULL(RTRIM(OB_RPT_UOM), '') = @c_OB_RPT_UOM;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SKU_RULES_100007_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;
         END;

         COMMIT;
      END;

      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_Sku
         , @c_PACKKey
         , @c_IB_UOM
         , @c_IB_RPT_UOM
         , @c_OB_UOM
         , @c_OB_RPT_UOM;
   END;

   CLOSE C_CHK;
   DEALLOCATE C_CHK;
   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKU_RULES_100007_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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