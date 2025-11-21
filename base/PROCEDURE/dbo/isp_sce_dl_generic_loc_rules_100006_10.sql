SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_LOC_RULES_100006_10             */
/* Creation Date: 19-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Quantity Checking when facility updated            */
/*                                                                      */
/*                                                                      */
/* Usage:   @c_InParm1 =  '0'  Ignore                                   */
/*          @c_InParm1 =  '1'  Perform checking                         */
/*          @c_InParm2 =  'DAMAGE, HOLD'  Loc Flag value                */
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
/* 19-Jan-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_LOC_RULES_100006_10] (
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

   DECLARE @c_Loc               NVARCHAR(20)
         , @c_Facility          NVARCHAR(10)
         , @c_LocationFlag      NVARCHAR(20)
         , @c_temp_LocationFlag NVARCHAR(10)
         , @c_ttlMsg            NVARCHAR(250);

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
   FROM dbo.SCE_DL_LOC_STG WITH (NOLOCK)
   WHERE STG_BatchNo              = @n_BatchNo
   AND   STG_Status                 = '1'
   AND   (Loc IS NULL OR RTRIM(Loc) = '')
   )
   BEGIN
      BEGIN TRANSACTION;

      UPDATE SCE_DL_LOC_STG WITH (ROWLOCK)
      SET STG_Status = '3'
        , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/Loc is Null'
      WHERE STG_BatchNo              = @n_BatchNo
      AND   STG_Status                 = '1'
      AND   (Loc IS NULL OR RTRIM(Loc) = '');

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_LOC_RULES_100006_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;
      END;
      COMMIT;
   END;

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RTRIM(Loc)
           , RTRIM(Facility)
           , RTRIM(LocationFlag)
      FROM dbo.SCE_DL_LOC_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      --AND   StorerKey IS NOT NULL
      --AND   RTRIM(StorerKey) <> ''
      GROUP BY RTRIM(Loc)
             , RTRIM(Facility)
             , RTRIM(LocationFlag);

      OPEN C_CHK;
      FETCH NEXT FROM C_CHK
      INTO @c_Loc
         , @c_Facility
         , @c_LocationFlag;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N'';
         SET @c_temp_LocationFlag = N'';

         IF EXISTS (
         SELECT 1
         FROM (
         SELECT COUNT(1) AS LocFound
         FROM dbo.V_LOTxLOCxID WITH (NOLOCK)
         WHERE Loc       = @c_Loc
         AND   QtyExpected > 0
         ) x
         WHERE x.LocFound > 0
         )
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Check LotxLotxid for the Loc ' + @c_Loc
                            + N' had the qtyexpected > 0.Cannot Update LocationType ';
         END;

         IF EXISTS (
         SELECT 1
         FROM (
         SELECT COUNT(1) AS ChkLocFound
         FROM dbo.V_LOTxLOCxID WITH (NOLOCK)
         WHERE Loc = RTRIM(@c_Loc)
         AND   Qty   > 0
         ) x
         WHERE x.ChkLocFound > 0
         )
         BEGIN
            IF EXISTS (
            SELECT 1
            FROM dbo.V_LOTxLOCxID lli WITH (NOLOCK)
            JOIN dbo.V_LOC        L WITH (NOLOCK)
            ON L.Loc = lli.Loc
            WHERE lli.Loc  = RTRIM(@c_Loc)
            AND   L.Facility <> @c_Facility
            )
            BEGIN
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Loc ' + RTRIM(@c_Loc)
                               + N' the qty is > 0.Not allow to Update Location Facility ';
            END;
         END;

         SELECT @c_temp_LocationFlag = RTRIM(L.LocationFlag)
         FROM dbo.V_LOC L WITH (NOLOCK)
         WHERE L.Loc = @c_Loc;


         IF EXISTS (
         SELECT 1
         FROM dbo.V_LOTxLOCxID WITH (NOLOCK)
         WHERE Loc = @c_Loc
         AND   Qty   > 0
         )
         BEGIN
            IF EXISTS (
            SELECT 1
            FROM STRING_SPLIT(@c_InParm2, ',')
            WHERE RTRIM([value]) = @c_temp_LocationFlag
            AND   RTRIM([value])   <> @c_LocationFlag
            )
            BEGIN
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/ Loc ' + @c_Loc
                               + N' QTY is > 0. Cannot Change LocationFlag From HOLD/DAMAGE to ' + @c_LocationFlag;
            END;
            ELSE
            BEGIN
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Loc ' + @c_Loc
                               + N' the qty is > 0.Cannot Change LocationFlag from ' + @c_temp_LocationFlag + N' To '
                               + @c_LocationFlag;
            END;
         END;


         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_LOC_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo       = @n_BatchNo
            AND   STG_Status          = '1'
            AND   RTRIM(Loc)          = @c_Loc
            AND   RTRIM(Facility)     = @c_Facility
            AND   RTRIM(LocationFlag) = @c_LocationFlag;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_LOC_RULES_100006_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;
         END;

         FETCH NEXT FROM C_CHK
         INTO @c_Loc
            , @c_Facility
            , @c_LocationFlag;
      END;

      CLOSE C_CHK;
      DEALLOCATE C_CHK;
   END;


   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_LOC_RULES_100006_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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