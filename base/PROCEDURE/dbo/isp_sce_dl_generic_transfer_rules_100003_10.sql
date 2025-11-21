SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_TRANSFER_RULES_100003_10        */
/* Creation Date: 06-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform From/To SKU Checking                               */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' From SKU Checking                           */
/* Usage:  @c_InParm2 = '1' To SKU Checking                             */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 06-Apr-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_TRANSFER_RULES_100003_10] (
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

   DECLARE @c_FromSKU  NVARCHAR(20)
         , @c_ToSKU    NVARCHAR(20)
         , @ttl_ErrMsg NVARCHAR(250);

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
   OR @c_InParm2 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(FromSku), '')
           , ISNULL(RTRIM(ToSku), '')
      FROM dbo.SCE_DL_TRANSFER_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      GROUP BY ISNULL(RTRIM(FromSku), '')
             , ISNULL(RTRIM(ToSku), '');

      OPEN C_CHK;

      FETCH NEXT FROM C_CHK
      INTO @c_FromSKU
         , @c_ToSKU;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @ttl_ErrMsg = N'';

         IF @c_InParm1 = '1'
         BEGIN
            IF @c_FromSKU = ''
            BEGIN
               SET @ttl_ErrMsg += N'/FromSKU cannot be null.';
            END;
            ELSE
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE Sku = @c_FromSKU
               )
               BEGIN
                  SET @ttl_ErrMsg += N'/FromSKU(' + @c_FromSKU + N') not exists.';
               END;
            END;
         END;

         IF @c_InParm2 = '1'
         BEGIN
            IF @c_ToSKU = ''
            BEGIN
               SET @ttl_ErrMsg += N'/ToSKU cannot be null';
            END;
            ELSE
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE Sku = @c_ToSKU
               )
               BEGIN
                  SET @ttl_ErrMsg += N'/To Sku(' + @c_ToSKU + N') not exists.';
               END;
            END;
         END;

         IF @ttl_ErrMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_TRANSFER_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @ttl_ErrMsg
            WHERE STG_BatchNo              = @n_BatchNo
            AND   STG_Status                 = '1'
            AND   ISNULL(RTRIM(FromSku), '') = @c_FromSKU
            AND   ISNULL(RTRIM(ToSku), '')     = @c_ToSKU;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68002;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_TRANSFER_RULES_100003_10)';
               ROLLBACK TRANSACTION;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT TRANSACTION;
         END;

         FETCH NEXT FROM C_CHK
         INTO @c_FromSKU
            , @c_ToSKU;
      END;
      CLOSE C_CHK;
      DEALLOCATE C_CHK;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_TRANSFER_RULES_100003_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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