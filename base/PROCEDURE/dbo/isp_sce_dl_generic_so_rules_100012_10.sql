SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_100012_10              */
/* Creation Date: 29-Nov-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform ChannelInventoryMgmt checking                      */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = 'ChannelInventoryMgmt'                          */
/*         @c_InParm2 = 'Channel'                                       */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_100012_10] (
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

   DECLARE @c_Configvalue      NVARCHAR(30)
         , @c_STConfigFacility NVARCHAR(10)
         , @c_StorerKey        NVARCHAR(15)
         , @c_Facility         NVARCHAR(5)
         , @c_Channel          NVARCHAR(20)
         , @c_ttlMsg           NVARCHAR(250);

   SELECT @c_InParm1 = ISNULL(RTRIM(InParm1), '') --ChannelInventoryMgmt
        , @c_InParm2 = ISNULL(RTRIM(InParm2), '') --Channel
        , @c_InParm3 = ISNULL(RTRIM(InParm3), '')
        , @c_InParm4 = ISNULL(RTRIM(InParm4), '')
        , @c_InParm5 = ISNULL(RTRIM(InParm5), '')
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

   IF  @c_InParm1 = 'ChannelInventoryMgmt'
   AND @c_InParm2 = 'Channel'
   BEGIN
      DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(StorerKey), '')
           , ISNULL(RTRIM(Facility), '')
           , ISNULL(RTRIM(Channel), '')
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      AND   StorerKey IS NOT NULL
      GROUP BY ISNULL(RTRIM(StorerKey), '')
             , ISNULL(RTRIM(Facility), '')
             , ISNULL(RTRIM(Channel), '');

      OPEN C_CHK_CONF;
      FETCH NEXT FROM C_CHK_CONF
      INTO @c_StorerKey
         , @c_Facility
         , @c_Channel;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N'';

         SELECT @c_Configvalue      = ISNULL(RTRIM(SValue), '')
              , @c_STConfigFacility = ISNULL(RTRIM(Facility), '')
         FROM dbo.V_StorerConfig WITH (NOLOCK)
         WHERE ConfigKey = @c_InParm1
         AND   StorerKey   = @c_StorerKey;

         IF @b_Debug = 1
         BEGIN
            SELECT @c_STConfigFacility '@c_STConfigFacility'
                 , @c_Configvalue      '@c_Configvalue';
         END;

         IF  @c_STConfigFacility <> ''
         AND @c_STConfigFacility = @c_Facility
         BEGIN
            SET @c_Configvalue = N'0';

            SELECT @c_Configvalue = ISNULL(RTRIM(SValue), '')
            FROM dbo.V_StorerConfig WITH (NOLOCK)
            WHERE ConfigKey = @c_InParm1
            AND   StorerKey   = @c_StorerKey
            AND   Facility    = @c_Facility;
         END;

         IF @c_Configvalue = '1'
         BEGIN
            IF @c_Channel = ''
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, '')))
                               + N'/storerconfig: ChannelInventoryMgmt turn on Channel cannot be NULL.';
            ELSE IF NOT EXISTS (
                 SELECT 1
                 FROM dbo.V_CODELKUP WITH (NOLOCK)
                 WHERE LISTNAME = @c_InParm2
                 AND   Code       = @c_Channel
                 )
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Channel : ' + @c_Channel
                               + N' not setup in codelkup table.';
         END;

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status    = '1'
            AND   StorerKey     = @c_StorerKey
            AND   Facility      = @c_Facility
            AND   Channel       = @c_Channel;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100012_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;

         END;

         FETCH NEXT FROM C_CHK_CONF
         INTO @c_StorerKey
            , @c_Facility
            , @c_Channel;
      END;

      CLOSE C_CHK_CONF;
      DEALLOCATE C_CHK_CONF;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_100012_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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