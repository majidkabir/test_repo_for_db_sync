SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_AssignLane_RULES_100004_10        */
/* Creation Date: 11-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform primary key checking                               */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_AssignLane_RULES_100004_10] (
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

   --IF EXISTS (
   --SELECT 1
   --FROM dbo.SCE_DL_AssignLane_STG STG WITH (NOLOCK)
   --WHERE STG.STG_BatchNo = @n_BatchNo
   --AND   STG.STG_Status    = '1'
   --AND   EXISTS (
   --SELECT 1
   --FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
   --WHERE LPD.LoadKey      = STG.LoadKey
   --AND   LPD.LoadLineNumber = STG.LoadLineNumber
   --)
   --)
   --BEGIN
   --   BEGIN TRANSACTION;

   --   UPDATE STG WITH (ROWLOCK)
   --   SET STG.STG_Status = '5'
   --     , STG.STG_ErrMsg = 'Records existed in LoadPlanDetail Table. Not allow to perform insert'
   --   FROM dbo.SCE_DL_AssignLane_STG STG
   --   WHERE STG.STG_BatchNo = @n_BatchNo
   --   AND   STG.STG_Status    = '1'
   --   AND   EXISTS (
   --   SELECT 1
   --   FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
   --   WHERE LPD.LoadKey      = STG.LoadKey
   --   AND   LPD.LoadLineNumber = STG.LoadLineNumber
   --   );

   --   IF @@ERROR <> 0
   --   BEGIN
   --      SET @n_Continue = 3;
   --      SET @n_ErrNo = 68001;
   --      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
   --                      + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100004_10)';
   --      ROLLBACK;
   --      GOTO STEP_999_EXIT_SP;

   --   END;

   --   COMMIT;
   --END;

   IF EXISTS (
   SELECT 1
   FROM dbo.SCE_DL_AssignLane_STG STG WITH (NOLOCK)
   WHERE STG.STG_BatchNo = @n_BatchNo
   AND   STG.STG_Status    = '1'
   AND   EXISTS (
   SELECT 1
   FROM dbo.LoadPlanLaneDetail LPLD WITH (NOLOCK)
   WHERE LPLD.LoadKey      = STG.LoadKey
   AND   LPLD.ExternOrderKey = STG.ExternOrderKey
   AND   LPLD.ConsigneeKey   = STG.ConsigneeKey
   AND   LPLD.LP_LaneNumber  = STG.LP_LaneNumber
   AND   LPLD.MBOLKey        = STG.MBOLKey
   )
   )
   BEGIN
      BEGIN TRANSACTION;

      UPDATE STG WITH (ROWLOCK)
      SET STG.STG_Status = '3'
        , STG.STG_ErrMsg = 'Records existed in LoadPlanLaneDetail Table. Not allow to perform insert'
      FROM dbo.SCE_DL_AssignLane_STG STG
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1'
      AND   EXISTS (
      SELECT 1
      FROM dbo.LoadPlanLaneDetail LPLD WITH (NOLOCK)
      WHERE LPLD.LoadKey      = STG.LoadKey
      AND   LPLD.ExternOrderKey = STG.ExternOrderKey
      AND   LPLD.ConsigneeKey   = STG.ConsigneeKey
      AND   LPLD.LP_LaneNumber  = STG.LP_LaneNumber
      AND   LPLD.MBOLKey        = STG.MBOLKey
      );

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100004_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;

      END;

      COMMIT;
   END;




   --DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --SELECT RowRefNo
   --     , ISNULL(RTRIM(LoadKey), '')
   --     , ISNULL(RTRIM(LoadLineNumber), '')
   --     , ISNULL(RTRIM(OrderKey), '')
   --     , ISNULL(RTRIM(ExternOrderKey), '')
   --     , ISNULL(RTRIM(ConsigneeKey), '')
   --     , ISNULL(RTRIM(CustomerName), '')
   --     , ISNULL(RTRIM([Priority]), '')
   --     , ISNULL(RTRIM(OrderDate), '')
   --     , ISNULL(DeliveryDate, '')
   --     , ISNULL(DeliveryPlace, '')
   --     , ISNULL(RTRIM([Type]), '')
   --     , ISNULL(RTRIM(Door), '')
   --     , ISNULL(RTRIM([Stop]), '')
   --     , ISNULL(RTRIM([Route]), '')
   --     , ISNULL([Weight], 0)
   --     , ISNULL([Cube], 0)
   --     , ISNULL(RTRIM([Status]), '')
   --     , ISNULL(CaseCnt, 0)
   --     , ISNULL(NoOfOrdLines, 0)
   --     , ISNULL(RTRIM(Rdd), '')
   --     , ISNULL(RTRIM(UserDefine01), '')
   --     , ISNULL(RTRIM(UserDefine02), '')
   --     , ISNULL(RTRIM(UserDefine03), '')
   --     , ISNULL(RTRIM(UserDefine04), '')
   --     , ISNULL(RTRIM(UserDefine05), '')
   --     , ISNULL(UserDefine06, '')
   --     , ISNULL(UserDefine07, '')
   --     , ISNULL(RTRIM(UserDefine08), '')
   --     , ISNULL(RTRIM(UserDefine09), '')
   --     , ISNULL(RTRIM(UserDefine10), '')
   --     , ISNULL(RTRIM(ExternLoadKey), '')
   --     , ISNULL(RTRIM(ExternLineNo), '')
   --     , ISNULL(RTRIM(LP_LaneNumber), '')
   --     , ISNULL(RTRIM(LocationCategory), '')
   --     , ISNULL(RTRIM(LOC), '')
   --     , ISNULL(RTRIM(Notes), '')
   --     , ISNULL(RTRIM(MBOLKey), '')
   --FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
   --WHERE STG_BatchNo = @n_BatchNo
   --AND   STG_Status    = '1'
   --ORDER BY STG_SeqNo ASC;

   --OPEN C_CHK_CONF;
   --FETCH NEXT FROM C_CHK_CONF
   --INTO @n_RowRefNo
   --   , @c_LoadKey
   --   , @c_LoadLineNumber
   --   , @c_OrderKey
   --   , @c_ExternOrderKey
   --   , @c_ConsigneeKey
   --   , @c_CustomerName
   --   , @c_Priority
   --   , @c_OrderDate
   --   , @c_DeliveryDate
   --   , @c_DeliveryPlace
   --   , @c_Type
   --   , @c_Door
   --   , @c_Stop
   --   , @c_Route
   --   , @f_Weight
   --   , @f_Cube
   --   , @c_Status
   --   , @c_CaseCnt
   --   , @c_NoOfOrdLines
   --   , @c_Rdd
   --   , @c_UserDefine01
   --   , @c_UserDefine02
   --   , @c_UserDefine03
   --   , @c_UserDefine04
   --   , @c_UserDefine05
   --   , @c_UserDefine06
   --   , @c_UserDefine07
   --   , @c_UserDefine08
   --   , @c_UserDefine09
   --   , @c_UserDefine10
   --   , @c_ExternLoadKey
   --   , @c_ExternLineNo
   --   , @c_LP_LaneNumber
   --   , @c_LocationCategory
   --   , @c_LOC
   --   , @c_Notes
   --   , @c_MBOLKey;


   --WHILE @@FETCH_STATUS = 0
   --BEGIN
   --   SET @c_ttlMsg = N'';

   --   IF @c_LoadKey = ''
   --   BEGIN
   --      SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/LoadKey cannot be empty or null.';
   --      GOTO NEXTITEM;
   --   END;

   --   IF @c_LoadKey = ''
   --   BEGIN
   --      SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/LoadKey cannot be empty or null.';
   --      GOTO NEXTITEM;
   --   END;

   --   ELSE
   --   BEGIN
   --      IF EXISTS (
   --      SELECT 1
   --      FROM dbo.ExternOrdersDetail WITH (NOLOCK)
   --      WHERE ExternOrderKey = @c_ExternOrderKey
   --      AND   SKU              = @c_SKU
   --      AND   QRCode           = @c_QRCode
   --      )
   --      BEGIN
   --         SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/EXTERNORDERKEY+SKU+QRCODE cannot be duplicate.';
   --      END;
   --   END;

   --   NEXTITEM:
   --   IF @c_ttlMsg <> ''
   --   BEGIN
   --      BEGIN TRANSACTION;

   --      UPDATE dbo.SCE_DL_AssignLane_STG WITH (ROWLOCK)
   --      SET STG_Status = '5'
   --        , STG_ErrMsg = @c_ttlMsg
   --      WHERE RowRefNo = @n_RowRefNo;

   --      IF @@ERROR <> 0
   --      BEGIN
   --         SET @n_Continue = 3;
   --         SET @n_ErrNo = 68001;
   --         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
   --                         + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100004_10)';
   --         ROLLBACK;
   --         GOTO STEP_999_EXIT_SP;

   --      END;

   --      COMMIT;

   --   END;

   --   FETCH NEXT FROM C_CHK_CONF
   --   INTO @n_RowRefNo
   --      , @c_LoadKey
   --      , @c_LoadLineNumber
   --      , @c_OrderKey
   --      , @c_ExternOrderKey
   --      , @c_ConsigneeKey
   --      , @c_CustomerName
   --      , @c_Priority
   --      , @c_OrderDate
   --      , @c_DeliveryDate
   --      , @c_DeliveryPlace
   --      , @c_Type
   --      , @c_Door
   --      , @c_Stop
   --      , @c_Route
   --      , @f_Weight
   --      , @f_Cube
   --      , @c_Status
   --      , @c_CaseCnt
   --      , @c_NoOfOrdLines
   --      , @c_Rdd
   --      , @c_UserDefine01
   --      , @c_UserDefine02
   --      , @c_UserDefine03
   --      , @c_UserDefine04
   --      , @c_UserDefine05
   --      , @c_UserDefine06
   --      , @c_UserDefine07
   --      , @c_UserDefine08
   --      , @c_UserDefine09
   --      , @c_UserDefine10
   --      , @c_ExternLoadKey
   --      , @c_ExternLineNo
   --      , @c_LP_LaneNumber
   --      , @c_LocationCategory
   --      , @c_LOC
   --      , @c_Notes
   --      , @c_MBOLKey;
   --END;

   --CLOSE C_CHK_CONF;
   --DEALLOCATE C_CHK_CONF;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_AssignLane_RULES_100004_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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