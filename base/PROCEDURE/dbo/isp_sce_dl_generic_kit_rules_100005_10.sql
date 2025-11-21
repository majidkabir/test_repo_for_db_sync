SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_KIT_RULES_100005_10             */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Explode BOM                                        */
/*                                                                      */
/*                                                                      */
/* Usage:   @c_InParm1 =  '1'  Active Flag                              */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_KIT_RULES_100005_10] (
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

   DECLARE @c_Storerkey     NVARCHAR(15)
         , @c_ExternKitKey  NVARCHAR(20)
         , @c_KITKey        NVARCHAR(10)
         , @c_Status        NVARCHAR(10)
         , @n_ActionFlag    INT
         , @c_Facility      NVARCHAR(5)
         , @c_DType         NVARCHAR(5)
         , @n_RowRefNo      INT
         , @c_AdjustmentKey NVARCHAR(10)
         , @n_TOSKUQty      INT
         , @c_UOM           NVARCHAR(10)
         , @c_Packkey       NVARCHAR(10)
         , @c_Sku           NVARCHAR(20)
         , @c_ComponentSku  NVARCHAR(20)
         , @n_BOMQty        INT
         , @c_USRDEF1 NVARCHAR(18)
         , @n_STG_SeqNo     INT
         , @c_ttlMsg        NVARCHAR(250);

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

   IF @c_InParm1 = '1'
   BEGIN
      BEGIN TRANSACTION;

      SELECT TOP (1) @n_STG_SeqNo = STG_SeqNo
      FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      ORDER BY STG_SeqNo DESC;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT BOM.ComponentSku
           , BOM.Qty
           , CASE WHEN RTRIM(STG.DType) = 'T' THEN 'F'
                  ELSE 'T'
             END
           , STG.Storerkey
           , STG.Sku
           , STG.ExternKitkey
           , STG.Facility
      FROM dbo.V_BillOfMaterial     BOM WITH (NOLOCK)
      INNER JOIN dbo.SCE_DL_KIT_STG STG WITH (NOLOCK)
      ON  STG.Storerkey = BOM.Storerkey
      AND STG.Sku      = BOM.Sku
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @c_ComponentSku
         , @n_BOMQty
         , @c_DType
         , @c_Storerkey
         , @c_Sku
         , @c_ExternKitKey
         , @c_Facility;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT @n_TOSKUQty = ExpectedQty
         FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   Storerkey     = @c_Storerkey
         AND   ExternKitKey  = @c_ExternKitKey
         AND   Facility      = @c_Facility
         ORDER BY STG_SeqNo;

         SET @n_STG_SeqNo += 1;

         INSERT INTO dbo.SCE_DL_KIT_STG
         (
            STG_BatchNo
          , STG_SeqNo
          , STG_Status
          , Storerkey
          , ToStorerkey
          , ExternKitKey
          , DType
          , HUdef01
          , Facility
          , SKU
          , ExpectedQty
          , AddWho
         )
         VALUES
         (
            @n_BatchNo
          , @n_STG_SeqNo
          , '1'
          , @c_Storerkey
          , @c_Storerkey
          , @c_ExternKitKey
          , @c_DType
          , ''
          , @c_Facility
          , @c_ComponentSku
          , (@n_BOMQty * @n_TOSKUQty)
          , @c_Username
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         NEXTITEM:
         FETCH NEXT FROM C_HDR
         INTO @c_ComponentSku
            , @n_BOMQty
            , @c_DType
            , @c_Storerkey
            , @c_Sku
            , @c_ExternKitKey
            , @c_Facility;
      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;
   END;
   --ELSE IF @c_InParm1 = '2'
   --BEGIN
      --BEGIN TRANSACTION;

      --SELECT TOP (1) @n_STG_SeqNo = STG_SeqNo
      --FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
      --WHERE STG_BatchNo = @n_BatchNo
      --ORDER BY STG_SeqNo DESC;

      --DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SELECT BOM.ComponentSku
      --     , BOM.Qty
      --     , STG.Storerkey
      --     , STG.Sku
      --     , STG.ExternKitkey
      --     , STG.Facility
      --FROM dbo.V_BillOfMaterial     BOM WITH (NOLOCK)
      --INNER JOIN dbo.SCE_DL_KIT_STG STG WITH (NOLOCK)
      --ON  STG.Storerkey = BOM.Storerkey
      --AND STG.Sku      = BOM.Sku
      --WHERE STG.STG_BatchNo = @n_BatchNo
      --AND   STG.STG_Status    = '1';

      --OPEN C_HDR;
      --FETCH NEXT FROM C_HDR
      --INTO @c_ComponentSku
      --   , @n_BOMQty
      --   , @c_Storerkey
      --   , @c_Sku
      --   , @c_ExternKitKey
      --   , @c_Facility;

      --WHILE @@FETCH_STATUS = 0
      --BEGIN

      --   SELECT @n_TOSKUQty = ExpectedQty
      --   , @c_USRDEF1 = HUdef01
      --   FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
      --   WHERE STG_BatchNo = @n_BatchNo
      --   AND   STG_Status    = '1'
      --   AND   Storerkey     = @c_Storerkey
      --   AND   ExternKitKey  = @c_ExternKitKey
      --   AND   Facility      = @c_Facility
      --   ORDER BY STG_SeqNo;

      --   SET @n_STG_SeqNo += 1;

      --   INSERT INTO dbo.SCE_DL_KIT_STG
      --   (
      --      STG_BatchNo
      --    , STG_SeqNo
      --    , STG_Status
      --    , Storerkey
      --    , ToStorerkey
      --    , ExternKitKey
      --    , DType
      --    , HUdef01
      --    , Facility
      --    , SKU
      --    , ExpectedQty
      --    , LOTTABLE02
      --    , LOTTABLE04
      --   )
      --   SELECT @n_BatchNo
      --       , @n_STG_SeqNo 
      --       , '1'
      --       , @c_Storerkey
      --       , @c_Storerkey
      --       , @c_ExternKitkey
      --       , 'F'
      --       , @c_USRDEF1
      --       , @c_Facility
      --       , ComponentSku
      --       , CEILING(ROUND(Qty * @n_TOSKUQty, 2))
      --       , CASE WHEN KeyComponent = 1 THEN @c_lottable02
      --              ELSE ''
      --         END
      --       , CASE WHEN KeyComponent = 1 THEN @d_Lottable04
      --              ELSE NULL
      --         END
      --       , @iFileID
      --       , @n_TempRowNo * 100
      --       , '8'
      --   FROM dbo.SCE_DL_BOM WITH (NOLOCK)
      --   WHERE Storerkey = @c_Storerkey
      --   AND   SKU         = @c_SKU
      --   AND   (CASE WHEN ISNULL(@c_USRDEF1, '') <> ''
      --               AND  Consigneekey = @c_USRDEF1 THEN 1
      --               WHEN ISNULL(@c_USRDEF1, '') = ''
      --               AND  ISNULL(Consigneekey, '') = '' THEN 1
      --               ELSE 0
      --          END
      --         )           = 1;

      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @n_Continue = 3;
      --      ROLLBACK TRAN;
      --      GOTO QUIT;
      --   END;

      --   INSERT INTO dbo.SCE_DL_KIT_STG
      --   (
      --      STG_BatchNo
      --    , STG_SeqNo
      --    , STG_Status
      --    , Storerkey
      --    , ToStorerkey
      --    , ExternKitKey
      --    , DType
      --    , HUdef01
      --    , Facility
      --    , SKU
      --    , ExpectedQty
      --    , LOTTABLE02
      --    , LOTTABLE04
      --    , AddWho
      --   )
      --   VALUES
      --   (
      --      @n_BatchNo
      --    , @n_STG_SeqNo
      --    , '1'
      --    , @c_Storerkey
      --    , @c_Storerkey
      --    , @c_ExternKitKey
      --    , 'F'
      --    , ''
      --    , @c_Facility
      --    , @c_ComponentSku
      --    , (@n_BOMQty * @n_TOSKUQty)
      --    , @c_Username
      --   );

      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @n_Continue = 3;
      --      ROLLBACK TRAN;
      --      GOTO QUIT;
      --   END;

      --   NEXTITEM:
      --   FETCH NEXT FROM C_HDR
      --   INTO @c_ComponentSku
      --      , @n_BOMQty
      --      , @c_Storerkey
      --      , @c_Sku
      --      , @c_ExternKitKey
      --      , @c_Facility;
      --END;

      --CLOSE C_HDR;
      --DEALLOCATE C_HDR;

      --WHILE @@TRANCOUNT > 0
      --COMMIT TRAN;
   --END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_KIT_RULES_100005_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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