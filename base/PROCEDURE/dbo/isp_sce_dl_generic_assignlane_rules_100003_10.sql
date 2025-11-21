SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10        */
/* Creation Date: 11-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Default and Lookup Value Checking                  */
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-Jan-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10] (
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

   DECLARE @n_RowRefNo         INT
         , @c_LoadKey          NVARCHAR(10)
         , @c_LoadLineNumber   NVARCHAR(5)
         , @c_OrderKey         NVARCHAR(20)
         , @c_ExternOrderKey   NVARCHAR(50)
         , @c_ConsigneeKey     NVARCHAR(15)
         , @c_CustomerName     NVARCHAR(50)
         , @c_Priority         NVARCHAR(10)
         , @c_OrderDate        DATETIME
         , @c_DeliveryDate     DATETIME
         , @c_DeliveryPlace    NVARCHAR(30)
         , @c_Type             NVARCHAR(10)
         , @c_Door             NVARCHAR(10)
         , @c_Stop             NVARCHAR(10)
         , @c_Route            NVARCHAR(10)
         , @f_Weight           FLOAT
         , @f_Cube             FLOAT
         , @c_Status           NVARCHAR(10)
         , @c_CaseCnt          INT
         , @c_NoOfOrdLines     INT
         , @c_Rdd              NVARCHAR(30)
         , @c_UserDefine01     NVARCHAR(20)
         , @c_UserDefine02     NVARCHAR(20)
         , @c_UserDefine03     NVARCHAR(20)
         , @c_UserDefine04     NVARCHAR(20)
         , @c_UserDefine05     NVARCHAR(20)
         , @c_UserDefine06     DATETIME
         , @c_UserDefine07     DATETIME
         , @c_UserDefine08     NVARCHAR(10)
         , @c_UserDefine09     NVARCHAR(10)
         , @c_UserDefine10     NVARCHAR(10)
         , @c_ExternLoadKey    NVARCHAR(30)
         , @c_ExternLineNo     NVARCHAR(20)
         , @c_LP_LaneNumber    NVARCHAR(5)
         , @c_LocationCategory NVARCHAR(10)
         , @c_LOC              NVARCHAR(10)
         , @c_Notes            NVARCHAR(215)
         , @c_MBOLKey          NVARCHAR(10)
         , @c_ttlMsg           NVARCHAR(250);


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
   FROM dbo.SCE_DL_AssignLane_STG STG WITH (NOLOCK)
   WHERE STG.STG_BatchNo = @n_BatchNo
   AND   STG.STG_Status    = '1'
   AND   NOT EXISTS (
   SELECT 1
   FROM dbo.V_ORDERS O WITH (NOLOCK)
   WHERE O.LoadKey      = STG.LoadKey
   AND   O.ExternOrderKey = STG.ExternOrderKey
   AND   O.ConsigneeKey   = CASE WHEN ISNULL(RTRIM(STG.ConsigneeKey), '') <> '' THEN STG.ConsigneeKey
                                 ELSE O.ConsigneeKey
                            END
   )
   )
   BEGIN
      BEGIN TRANSACTION;

      UPDATE STG WITH (ROWLOCK)
      SET STG.STG_Status = '3'
        , STG.STG_ErrMsg = 'Invalid LoadKey and Externorderkey. Failed to retrieve the OrderKey from Orders table.'
      FROM dbo.SCE_DL_AssignLane_STG STG
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1'
      AND   NOT EXISTS (
      SELECT 1
      FROM dbo.V_ORDERS O WITH (NOLOCK)
      WHERE O.LoadKey      = STG.LoadKey
      AND   O.ExternOrderKey = STG.ExternOrderKey
      AND   O.ConsigneeKey   = CASE WHEN ISNULL(RTRIM(STG.ConsigneeKey), '') <> '' THEN STG.ConsigneeKey
                                    ELSE O.ConsigneeKey
                               END
      );

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;

      END;

      COMMIT;
   END;

   DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(LoadKey), '')
        , ISNULL(RTRIM(ExternOrderKey), '')
        , ISNULL(RTRIM(ConsigneeKey), '')
   FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   GROUP BY ISNULL(RTRIM(LoadKey), '')
          , ISNULL(RTRIM(ExternOrderKey), '')
          , ISNULL(RTRIM(ConsigneeKey), '');

   OPEN C_CHK_CONF;
   FETCH NEXT FROM C_CHK_CONF
   INTO @c_LoadKey
      , @c_ExternOrderKey
      , @c_ConsigneeKey;


   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N'';

      IF EXISTS (
      SELECT 1
      FROM dbo.V_ORDERS O WITH (NOLOCK)
      WHERE O.LoadKey      = @c_LoadKey
      AND   O.ExternOrderKey = @c_ExternOrderKey
      AND   O.ConsigneeKey   = @c_ConsigneeKey
      HAVING COUNT(1) > 1
      )
      BEGIN
         SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, '')))
                         + N'/More than 1 OrderKey have been found. System unable to update the OrderKey fields.';
      END;
      ELSE
      BEGIN
         BEGIN TRANSACTION;

         UPDATE STG WITH (ROWLOCK)
         SET STG.OrderKey = O.OrderKey
           , STG.DeliveryDate = O.DeliveryDate
           , STG.DeliveryPlace = O.DeliveryPlace
           , STG.[Priority] = O.[Priority]
           --, STG.ConsigneeKey = CASE WHEN ISNULL(RTRIM(STG.ConsigneeKey), '') <> '' THEN STG.ConsigneeKey
           --                          ELSE O.ConsigneeKey
           --                     END
           , STG.OrderDate = O.OrderDate
           , STG.Door = O.Door
           , STG.[Stop] = O.[Stop]
           , STG.[Route] = O.[Route]
           , STG.Rdd = O.Rdd
           , STG.CustomerName = O.C_Company
           , STG.AddWho = @c_Username
           , STG.EditWho = @c_Username
         FROM dbo.SCE_DL_AssignLane_STG STG
         INNER JOIN dbo.V_ORDERS      O WITH (NOLOCK)
         ON  O.LoadKey         = STG.LoadKey
         AND O.ExternOrderKey = STG.ExternOrderKey
         AND O.ConsigneeKey   = STG.ConsigneeKey
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status    = '1'
         AND STG.LoadKey = @c_LoadKey
         AND STG.ExternOrderKey = @c_ExternOrderKey
         AND STG.ConsigneeKey = @c_ConsigneeKey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;

      END;

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_AssignLane_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   LoadKey = @c_LoadKey
         AND   ExternOrderKey = @c_ExternOrderKey
         AND   ConsigneeKey = @c_ConsigneeKey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record  fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;

      END;

      FETCH NEXT FROM C_CHK_CONF
      INTO @c_LoadKey
         , @c_ExternOrderKey
         , @c_ConsigneeKey;

   END;

   CLOSE C_CHK_CONF;
   DEALLOCATE C_CHK_CONF;


   --BEGIN TRANSACTION;

   --UPDATE x
   --SET x.LoadLineNumber = x.RN
   --FROM (
   --SELECT RowRefNo
   --     , LoadLineNumber
   --     , RIGHT('0000' + RTRIM(CAST(ROW_NUMBER() OVER (ORDER BY STG_SeqNo) AS CHAR(5))), 5) AS RN
   --FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
   --WHERE STG_BatchNo = @n_BatchNo
   --AND   STG_Status    = '1'
   --) x
   --WHERE x.RowRefNo = x.RowRefNo;

   --IF @@ERROR <> 0
   --BEGIN
   --   SET @n_Continue = 3;
   --   SET @n_ErrNo = 68001;
   --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
   --                   + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10)';
   --   ROLLBACK;
   --   GOTO STEP_999_EXIT_SP;

   --END;

   --COMMIT;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_AssignLane_RULES_100003_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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