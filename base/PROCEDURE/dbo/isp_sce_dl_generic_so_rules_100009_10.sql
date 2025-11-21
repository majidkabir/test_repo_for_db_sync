SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_100009_10              */
/* Creation Date: 28-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Facility checking                                  */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' will validate the Facility whether          */
/*         is exists or not.                                            */
/*         @c_InParm2 = '1' Convert facility refer to                   */
/*         codelkup table where listname='IDSFac'                       */
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
/* 28-Dec-2021  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_100009_10] (
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

   DECLARE @c_Facility  NVARCHAR(10)
         , @c_Fac_Out   NVARCHAR(10)
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

      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo                = @n_BatchNo
      AND   STG_Status                   = '1'
      AND   (
             Facility IS NULL
          OR ISNULL(RTRIM(Facility), '') = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/Facility is null'
         WHERE STG_BatchNo                = @n_BatchNo
         AND   STG_Status                   = '1'
         AND   (
                Facility IS NULL
             OR ISNULL(RTRIM(Facility), '') = ''
         );


         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100009_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;
         END;

         COMMIT;
      END;


   IF @c_InParm1 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(Facility), '')
           , ISNULL(RTRIM(Storerkey), '')
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      --AND   StorerKey IS NOT NULL
      --AND   RTRIM(StorerKey) <> ''
      GROUP BY ISNULL(RTRIM(Facility), '')
             , ISNULL(RTRIM(Storerkey), '');

      OPEN C_CHK;
      FETCH NEXT FROM C_CHK
      INTO @c_Facility
         , @c_StorerKey;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N'';

         IF  @c_InParm2 = '1'
         AND @c_Facility <> ''
         BEGIN
            SET @c_Fac_Out = N'';

            SELECT @c_Fac_Out = ISNULL(RTRIM(Short), '')
            FROM dbo.V_CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'IDSFac'
            AND   Code       = @c_Facility
            AND   Notes      = @c_StorerKey;

            BEGIN TRANSACTION;

            UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
            SET Facility = CASE WHEN @c_Fac_Out <> '' THEN @c_Fac_Out
                                ELSE @c_Facility
                           END
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status    = '1'
            AND   Storerkey     = @c_StorerKey
            AND   Facility      = @c_Facility;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100009_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;

            IF @c_Fac_Out <> ''
            BEGIN
               SET @c_Facility = @c_Fac_Out;
            END;
         END;

         IF NOT EXISTS (
         SELECT 1
         FROM dbo.V_FACILITY WITH (NOLOCK)
         WHERE Facility = @c_Facility
         )
         BEGIN
            SET @c_ttlMsg = N'/Facility not exists';
         END;

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + @c_ttlMsg
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status    = '1'
            AND   Storerkey     = @c_StorerKey
            AND   Facility      = @c_Facility;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100009_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;
         END;

         FETCH NEXT FROM C_CHK
         INTO @c_Facility
            , @c_StorerKey;
      END;

      CLOSE C_CHK;
      DEALLOCATE C_CHK;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_100009_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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