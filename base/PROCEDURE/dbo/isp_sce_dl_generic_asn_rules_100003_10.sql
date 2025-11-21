SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ASN_RULES_100003_10             */
/* Creation Date: 17-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Facility checking                                  */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Perform Facility Existing checking          */
/*         @c_InParm2 = '1' Convert facility refer to                   */
/*                         codelkup table where listname='IDSFac'       */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ASN_RULES_100003_10] (
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

   DECLARE @c_StorerKey NVARCHAR(15)
         , @c_Facility  NVARCHAR(15)
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
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo    = @n_BatchNo
   AND   STG_Status       = '1'
   AND   (
          Facility IS NULL
       OR RTRIM(Facility) = ''
   )
   )
   BEGIN
      BEGIN TRANSACTION;

      UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
      SET STG_Status = '3'
        , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/Facility is Null'
      WHERE STG_BatchNo    = @n_BatchNo
      AND   STG_Status       = '1'
      AND   (
             Facility IS NULL
          OR RTRIM(Facility) = ''
      );

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_RULES_100003_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;
      END;
      COMMIT;
   END;

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RTRIM(Storerkey)
           , RTRIM(Facility)
      FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      --AND   StorerKey IS NOT NULL
      --AND   RTRIM(StorerKey) <> ''
      GROUP BY RTRIM(Storerkey)
             , RTRIM(Facility);

      OPEN C_CHK;
      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_Facility;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N'';

         IF @c_InParm2 = '1'
         BEGIN
            IF NOT EXISTS (
            SELECT 1
            FROM dbo.V_CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'IDSFac'
            AND   Notes      = @c_StorerKey
            AND   Code       = @c_Facility
            )
            BEGIN
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, '')))
                               + N'/Facility not found in codelkup table where listname=''IDSFac''';
               GOTO NEXTITEM;
            END;

            BEGIN TRANSACTION;

            UPDATE STG WITH (ROWLOCK)
            SET STG.Facility = CLK.Short
            FROM dbo.SCE_DL_ASN_STG STG
            INNER JOIN dbo.V_CODELKUP CLK WITH (NOLOCK)
            ON  CLK.Notes = STG.Storerkey
            AND CLK.Code = STG.Facility
            WHERE STG.STG_BatchNo    = @n_BatchNo
            AND   STG.STG_Status       = '1'
            AND   RTRIM(STG.Storerkey) = @c_StorerKey
            AND   RTRIM(STG.Facility)  = @c_Facility;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_RULES_100003_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;

         END;
         ELSE
         BEGIN
            IF NOT EXISTS (
            SELECT 1
            FROM dbo.V_FACILITY WITH (NOLOCK)
            WHERE Facility = @c_Facility
            )
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Facility not exists';
            GOTO NEXTITEM;

         END;

         NEXTITEM:
         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo   = @n_BatchNo
            AND   STG_Status      = '1'
            AND RTRIM(Storerkey) = @c_StorerKey
            AND   RTRIM(Facility) = @c_Facility;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_RULES_100003_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;
         END;

         FETCH NEXT FROM C_CHK
         INTO @c_StorerKey
            , @c_Facility;
      END;

      CLOSE C_CHK;
      DEALLOCATE C_CHK;
   END;


   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ASN_RULES_100003_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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