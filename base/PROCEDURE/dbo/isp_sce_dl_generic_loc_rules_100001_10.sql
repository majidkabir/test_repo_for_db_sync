SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_LOC_RULES_100001_10             */
/* Creation Date: 17-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform LocCheckDigit checking                             */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = For individual country special checking on      */
/*         checkdigit,ByPass or continue checking(1_ByPass,0_Check)     */
/*         @c_InParm2 = Check against CheckDigitLengthForLocation from  */
/*                      Facility table                                  */
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
/* 07-Jun-2024  WLChooi   1.2   UWP-20493 Add new LocCheckDigit checking*/
/*                              logic (WL01)                            */        
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_LOC_RULES_100001_10] (
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
         , @c_ttlMsg    NVARCHAR(250);

   --WL01 S
   DECLARE @n_CheckDigitLengthForLocation INT = 0
         , @c_DisableCheckDigitAutoCompute NVARCHAR(10) = 'false'
         , @n_LocCheckDigitLen INT = 0
         , @n_RowRefNo      BIGINT = 0
         , @c_Facility      NVARCHAR(5)  = ''
         , @c_LocCheckDigit NVARCHAR(10) = ''
         , @c_Loc           NVARCHAR(10) = ''
         , @n_Exists        INT = 0
   --WL01 E

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

   IF @c_InParm1 = '0'
   BEGIN
      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_LOC_STG WITH (NOLOCK)
      WHERE STG_BatchNo         = @n_BatchNo
      AND   STG_Status            = '1'
      AND   (
             LocCheckDigit IS NULL
          OR RTRIM(LocCheckDigit) = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE SCE_DL_LOC_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/Location Check Digit cannot be Null'
         WHERE STG_BatchNo         = @n_BatchNo
         AND   STG_Status            = '1'
         AND   (
                LocCheckDigit IS NULL
             OR RTRIM(LocCheckDigit) = ''
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_LOC_RULES_100001_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;
         END;
         COMMIT;
      END;
   END;

   --WL01 S
   IF @c_InParm2 = '1'
   BEGIN
      DECLARE CUR_VALD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo, Facility, LocCheckDigit, Loc, ISNULL(DisableCheckDigitAutoCompute, 'false')
      FROM dbo.SCE_DL_LOC_STG STG WITH (NOLOCK)
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND STG.STG_Status = '1'

      OPEN CUR_VALD

      FETCH NEXT FROM CUR_VALD INTO @n_RowRefNo
                                  , @c_Facility
                                  , @c_LocCheckDigit
                                  , @c_Loc
                                  , @c_DisableCheckDigitAutoCompute

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_Exists = 0
         SET @n_CheckDigitLengthForLocation = 0
         SET @n_LocCheckDigitLen = 0

         SELECT @n_CheckDigitLengthForLocation = IIF(ISNUMERIC(MAX(CheckDigitLengthForLocation)) = 1, MAX(CheckDigitLengthForLocation), 0)
              , @n_Exists = COUNT(1)
         FROM dbo.FACILITY F (NOLOCK)
         WHERE F.Facility = @c_Facility

         IF ISNULL(@c_LocCheckDigit, '') = ''
         BEGIN
            IF @n_Exists > 0
            BEGIN
               IF @n_CheckDigitLengthForLocation = 2 AND @c_DisableCheckDigitAutoCompute = 'false'
               BEGIN
                  UPDATE STG
                  SET LocCheckDigit = dbo.fnc_GetLocCheckDigit2Digit(Loc)
                  FROM dbo.SCE_DL_LOC_STG STG WITH (NOLOCK)
                  WHERE RowRefNo = @n_RowRefNo
               END
            END
         END
         ELSE
         BEGIN
            SELECT @n_LocCheckDigitLen = LEN(@c_LocCheckDigit)

            IF @n_LocCheckDigitLen > @n_CheckDigitLengthForLocation
            BEGIN
               BEGIN TRANSACTION

               UPDATE SCE_DL_LOC_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/LocCheckDigit has exceeded the CheckDigitLengthForLocation in Facility table'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status = '1'
               AND   RowRefNo = @n_RowRefNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_ErrNo = 68002
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_LOC_RULES_100001_10)'
                  ROLLBACK
                  GOTO STEP_999_EXIT_SP
               END
               COMMIT
            END
         END
         
         FETCH NEXT FROM CUR_VALD INTO @n_RowRefNo
                                     , @c_Facility
                                     , @c_LocCheckDigit
                                     , @c_Loc
                                     , @c_DisableCheckDigitAutoCompute
      END
   END
   --WL01 E

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_LOC_RULES_100001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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