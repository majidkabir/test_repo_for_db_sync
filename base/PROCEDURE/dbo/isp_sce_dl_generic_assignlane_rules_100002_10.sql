SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_AssignLane_RULES_100002_10      */
/* Creation Date: 11-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */  
/* Purpose:  Perform Normal Column Checking                             */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Perform LOC Column Checking                 */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_AssignLane_RULES_100002_10] (
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

   IF @c_InParm1 = '1'
   BEGIN

      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_AssignLane_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      AND   (
             LOC IS NULL
          OR RTRIM(LOC) = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_AssignLane_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/LOC is Null'
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   (
                LOC IS NULL
             OR RTRIM(LOC) = ''
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_AssignLane_RULES_100002_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;
         END;
         COMMIT;
      END;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_AssignLane_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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