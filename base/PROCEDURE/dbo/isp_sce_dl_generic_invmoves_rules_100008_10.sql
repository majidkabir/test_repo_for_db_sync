SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_INVMOVES_RULES_100008_10        */
/* Creation Date: 05-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20470 - Perform ToUOM Checking                          */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Perform NULL ToUOM Checking                 */
/*         @c_InParm2 = '1' Perform Exist ToUOM Checking                */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_INVMOVES_RULES_100008_10] (
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

   DECLARE @c_PackKey NVARCHAR(10)
         , @c_UOM     NVARCHAR(10)
         , @c_ttlMsg  NVARCHAR(250)

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
   WHERE SPName = OBJECT_NAME(@@PROCID)

   IF @c_InParm1 = '1'
   BEGIN
      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_INVMOVES_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   (ToUOM IS NULL OR RTRIM(ToUOM) = '')
      )
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_INVMOVES_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/ToUOM is Null'
         WHERE STG_BatchNo                = @n_BatchNo
         AND   STG_Status                 = '1'
         AND   (ToUOM IS NULL OR RTRIM(ToUOM) = '')

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 63782
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_INVMOVES_RULES_100008_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT
      END
   END

   IF @c_InParm2 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ISNULL(RTRIM(ToPackKey), '')
                    , ISNULL(RTRIM(ToUOM), '')
      FROM dbo.SCE_DL_INVMOVES_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'

      OPEN C_CHK

      FETCH NEXT FROM C_CHK
      INTO @c_PackKey
         , @c_UOM

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SET @c_ttlMsg = N''

         IF @c_UOM <> ''
         BEGIN
            IF EXISTS (
            SELECT 1
            FROM dbo.V_PACK WITH (NOLOCK)
            WHERE PackKey = @c_PackKey
            AND   PackUOM1  <> @c_UOM
            AND   PackUOM2  <> @c_UOM
            AND   PackUOM3  <> @c_UOM
            AND   PackUOM4  <> @c_UOM
            )
            BEGIN
               SET @c_ttlMsg += N'/ToUOM(' + @c_UOM + N') not exists in PACK table'
            END
         END
         ELSE
         BEGIN
            BEGIN TRANSACTION

            UPDATE STG WITH (ROWLOCK)
            SET STG.ToUOM = P.PackUOM3
            FROM dbo.SCE_DL_INVMOVES_STG STG
            INNER JOIN dbo.V_PACK   P WITH (NOLOCK)
            ON P.PackKey = STG.ToPackKey
            WHERE STG.STG_BatchNo                = @n_BatchNo
            AND   STG.STG_Status                 = '1'
            AND   ISNULL(RTRIM(STG.ToPackkey), '') = @c_PackKey
            AND   ISNULL(RTRIM(STG.ToUOM), '')     = @c_UOM

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 63783
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_INVMOVES_RULES_100008_10)'
               ROLLBACK TRANSACTION
               GOTO STEP_999_EXIT_SP
            END

            COMMIT TRANSACTION
         END

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION

            UPDATE dbo.SCE_DL_INVMOVES_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo                = @n_BatchNo
            AND   STG_Status                 = '1'
            AND   ISNULL(RTRIM(ToPackKey), '') = @c_PackKey
            AND   ISNULL(RTRIM(ToUOM), '')     = @c_UOM

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 63784
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_INVMOVES_RULES_100008_10)'
               ROLLBACK TRANSACTION
               GOTO STEP_999_EXIT_SP
            END

            COMMIT TRANSACTION
         END

         FETCH NEXT FROM C_CHK
         INTO @c_PackKey
            , @c_UOM
      END
      CLOSE C_CHK
      DEALLOCATE C_CHK
   END

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_INVMOVES_RULES_100008_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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