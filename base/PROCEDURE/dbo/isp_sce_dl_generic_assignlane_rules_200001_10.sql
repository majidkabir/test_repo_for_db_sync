SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_AssignLane_RULES_200001_10        */
/* Creation Date: 11-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Insert into LoadPlanDetail and LoadPlanLaneDetail  */
/*           table.                                                     */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_AssignLane_RULES_200001_10] (
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

   DECLARE @n_RowRefNo       INT
         , @n_LoadLineNumber INT
         , @c_ExternOrderKey NVARCHAR(50);


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
   FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_CHK_CONF;
   FETCH NEXT FROM C_CHK_CONF
   INTO @n_RowRefNo;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      --SET @n_LoadLineNumber = 0;

      BEGIN TRANSACTION;

      --SELECT @n_LoadLineNumber = MAX(LPD.LoadLineNumber)
      --FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
      --WHERE EXISTS (
      --SELECT 1
      --FROM dbo.SCE_DL_AssignLane_STG STG WITH (NOLOCK)
      --WHERE STG.RowRefNo = @n_RowRefNo
      --AND   LPD.LoadKey    = STG.LoadKey
      --);

      --SET @n_LoadLineNumber += 1;

      --INSERT INTO dbo.LoadPlanDetail
      --(
      --   LoadKey
      -- , LoadLineNumber
      -- , OrderKey
      -- , ExternOrderKey
      -- , ConsigneeKey
      -- , CustomerName
      -- , [Priority]
      -- , OrderDate
      -- , DeliveryDate
      -- , DeliveryPlace
      -- , [Type]
      -- , Door
      -- , [Stop]
      -- , [Route]
      -- , [Weight]
      -- , [Cube]
      -- , [Status]
      -- , CaseCnt
      -- , NoOfOrdLines
      -- , Rdd
      -- , AddDate
      -- , AddWho
      -- , EditDate
      -- , EditWho
      -- , ArchiveCop
      -- , TrafficCop
      -- , UserDefine01
      -- , UserDefine02
      -- , UserDefine03
      -- , UserDefine04
      -- , UserDefine05
      -- , UserDefine06
      -- , UserDefine07
      -- , UserDefine08
      -- , UserDefine09
      -- , UserDefine10
      -- , ExternLoadKey
      -- , ExternLineNo
      --)
      --SELECT LoadKey
      --     , REPLICATE('0', 5 - LEN(@n_LoadLineNumber)) + CONVERT(NVARCHAR(5), @n_LoadLineNumber)
      --     , OrderKey
      --     , ExternOrderKey
      --     , ConsigneeKey
      --     , CustomerName
      --     , [Priority]
      --     , OrderDate
      --     , DeliveryDate
      --     , DeliveryPlace
      --     , [Type]
      --     , Door
      --     , [Stop]
      --     , [Route]
      --     , [Weight]
      --     , [Cube]
      --     , [Status]
      --     , CaseCnt
      --     , NoOfOrdLines
      --     , Rdd
      --     , AddDate
      --     , @c_Username
      --     , EditDate
      --     , @c_Username
      --     , ArchiveCop
      --     , TrafficCop
      --     , UserDefine01
      --     , UserDefine02
      --     , UserDefine03
      --     , UserDefine04
      --     , UserDefine05
      --     , UserDefine06
      --     , UserDefine07
      --     , UserDefine08
      --     , UserDefine09
      --     , UserDefine10
      --     , ExternLoadKey
      --     , ExternLineNo
      --FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
      --WHERE RowRefNo = @n_RowRefNo;

      INSERT INTO dbo.LoadPlanLaneDetail
      (
         LoadKey
       , ExternOrderKey
       , ConsigneeKey
       , LP_LaneNumber
       , LocationCategory
       , LOC
       , [Status]
       , Notes
       , AddWho
       , AddDate
       , EditWho
       , EditDate
       , TrafficCop
       , ArchiveCop
       , MBOLKey
      )
      SELECT LoadKey
           , ExternOrderKey
           , ConsigneeKey
           , LP_LaneNumber
           , LocationCategory
           , LOC
           , ISNULL(RTRIM([Status]),'0')
           , ISNULL(RTRIM(Notes),'')
           , @c_Username
           , AddDate
           , @c_Username
           , EditDate
           , ArchiveCop
           , TrafficCop
           , ISNULL(RTRIM(MBOLKey),'')
      FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
      WHERE RowRefNo = @n_RowRefNo;

      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
      WHERE RowRefNo       = @n_RowRefNo
      AND   LocationCategory = 'processing'
      )
      BEGIN
         UPDATE O WITH (ROWLOCK)
         SET O.Door = ISNULL(STG.LOC, '')
         FROM dbo.ORDERS                      O
         INNER JOIN dbo.SCE_DL_AssignLane_STG STG WITH (NOLOCK)
         ON O.OrderKey = STG.OrderKey
         WHERE STG.RowRefNo       = STG.RowRefNo
         AND   STG.LocationCategory = 'processing';
      END;


      UPDATE dbo.SCE_DL_AssignLane_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo;


      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_200001_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;

      END;

      COMMIT;

      FETCH NEXT FROM C_CHK_CONF
      INTO @n_RowRefNo;
   END;

   CLOSE C_CHK_CONF;
   DEALLOCATE C_CHK_CONF;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_AssignLane_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(RTRIM(@c_ErrMsg), '');
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