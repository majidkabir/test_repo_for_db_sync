SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_PO_RULES_100006_10              */
/* Creation Date: 29-Nov-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Use SKU or AltSku (1_SKU, 0_AltSKU)                        */
/*           if AltSku Then    (1_ALTSKU, 2_REALSKU, 3_UPC)             */
/*                                                                      */
/*                                                                      */
/* Usage:  SKUORAltSKU => @c_InParm1 = '0'                              */
/*         ALTSKUField => @c_InParm2 = '1'                              */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Nov-2021  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_PO_RULES_100006_10] (
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

   DECLARE @n_RowRefNo  INT
         , @c_Sku       NVARCHAR(20)
         , @c_ALTSKU    NVARCHAR(20)
         , @c_RetailSku NVARCHAR(20)
         , @c_UPC       NVARCHAR(30)
         , @c_StorerKey NVARCHAR(15)
         , @c_ttlMsg    NVARCHAR(250);

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

   DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , ISNULL(RTRIM(Sku), '')
        , ISNULL(RTRIM(ALTSKU), '')
        , ISNULL(RTRIM(RetailSku), '')
        , ISNULL(RTRIM(UPC), '')
        , ISNULL(RTRIM(StorerKey), '')
   FROM dbo.SCE_DL_PO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_CHK_CONF;
   FETCH NEXT FROM C_CHK_CONF
   INTO @n_RowRefNo
      , @c_Sku
      , @c_ALTSKU
      , @c_RetailSku
      , @c_UPC
      , @c_StorerKey;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N'';

      IF @c_InParm1 = '0'
      BEGIN
         IF @c_InParm2 = '1'
         BEGIN
            IF @c_ALTSKU <> ''
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND   ALTSKU      = @c_ALTSKU
               )
               BEGIN
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/ALTSKU not exists';
               END;
               ELSE
               BEGIN
                  BEGIN TRANSACTION;

                  UPDATE stg WITH (ROWLOCK)
                  SET stg.Sku = SKU.Sku
                  FROM dbo.SCE_DL_PO_STG stg
                  INNER JOIN dbo.V_SKU   sku WITH (NOLOCK)
                  ON  stg.StorerKey = sku.StorerKey
                  AND stg.ALTSKU   = sku.ALTSKU
                  WHERE stg.RowRefNo = @n_RowRefNo;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68001;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Update record to SCE_DL_PO_STG fail. (isp_SCE_DL_GENERIC_PO_RULES_100006_10)';
                     ROLLBACK;
                     GOTO STEP_999_EXIT_SP;

                  END;

                  COMMIT;
               END;
            END;
            ELSE
            BEGIN
               IF @c_Sku = ''
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/ALTSKU is Null';
            END;
         END;
         ELSE IF @c_InParm2 = '2'
         BEGIN
            IF @c_RetailSku <> ''
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND   RETAILSKU   = @c_RetailSku
               )
               BEGIN
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/RETAILSKU not exists';
               END;
               ELSE
               BEGIN
                  BEGIN TRANSACTION;

                  UPDATE stg WITH (ROWLOCK)
                  SET stg.Sku = SKU.Sku
                  FROM dbo.SCE_DL_PO_STG stg
                  INNER JOIN dbo.V_SKU   sku WITH (NOLOCK)
                  ON  stg.StorerKey  = sku.StorerKey
                  AND stg.RetailSku = sku.RETAILSKU
                  WHERE stg.RowRefNo = @n_RowRefNo;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68001;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Update record to SCE_DL_PO_STG fail. (isp_SCE_DL_GENERIC_PO_RULES_100006_10)';
                     ROLLBACK;
                     GOTO STEP_999_EXIT_SP;

                  END;

                  COMMIT;
               END;
            END;
            ELSE
            BEGIN
               IF @c_Sku = ''
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/RETAILSKU is Null';
            END;

         END;
         ELSE IF @c_InParm2 = '3'
         BEGIN
            IF @c_UPC <> ''
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.V_UPC WITH (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND   UPC         = @c_UPC
               )
               BEGIN
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/UPC not exists';
               END;
               ELSE
               BEGIN
                  BEGIN TRANSACTION;

                  UPDATE stg WITH (ROWLOCK)
                  SET stg.Sku = UPC.Sku
                  FROM dbo.SCE_DL_PO_STG stg
                  INNER JOIN dbo.V_UPC   upc WITH (NOLOCK)
                  ON  stg.StorerKey = upc.StorerKey
                  AND stg.UPC      = upc.UPC
                  WHERE stg.RowRefNo = @n_RowRefNo;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     SET @n_ErrNo = 68001;
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                     + ': Update record to SCE_DL_PO_STG fail. (isp_SCE_DL_GENERIC_PO_RULES_100006_10)';
                     ROLLBACK;
                     GOTO STEP_999_EXIT_SP;

                  END;

                  COMMIT;
               END;
            END;
            ELSE
            BEGIN
               IF @c_Sku = ''
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/UPC is Null';
            END;
         END;
      END;
      ELSE IF @c_InParm1 = '1'
      BEGIN
         IF @c_Sku <> ''
         BEGIN
            IF NOT EXISTS (
            SELECT 1
            FROM dbo.V_SKU WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND   Sku         = @c_Sku
            )
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/SKU not exists';
         END;
         ELSE
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/SKU is Null';
      END;

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_PO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record to SCE_DL_PO_STG fail. (isp_SCE_DL_GENERIC_PO_RULES_100006_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;

      END;

      FETCH NEXT FROM C_CHK_CONF
      INTO @n_RowRefNo
         , @c_Sku
         , @c_ALTSKU
         , @c_RetailSku
         , @c_UPC
         , @c_StorerKey;
   END;

   CLOSE C_CHK_CONF;
   DEALLOCATE C_CHK_CONF;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_PO_RULES_100006_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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