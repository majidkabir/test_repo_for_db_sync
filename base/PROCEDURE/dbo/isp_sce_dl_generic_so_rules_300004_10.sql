SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_300004_10              */
/* Creation Date: 13-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose: Auto Create CartonTrack record                              */
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
/* 13-Jan-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_300004_10] (
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

   DECLARE @c_Orderkey NVARCHAR(10)
         , @n_RowRefNo INT;


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

   DECLARE C_CtnTrack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '9'
   AND   OrderKey      <> '';

   OPEN C_CtnTrack;
   FETCH NEXT FROM C_CtnTrack
   INTO @n_RowRefNo;

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --while C_CtnTrack  
      BEGIN TRANSACTION;

      INSERT INTO dbo.CartonTrack
      (
         TrackingNo
       , CarrierName
       , KeyName
       , LabelNo
       , CarrierRef2
       , AddWho
       , EditWho
      )
      SELECT HUdef04
           , Shipperkey
           , 'ExcelLoader'
           , OrderKey
           , 'GET'
           , AddWho
           , AddWho
      FROM dbo.SCE_DL_SO_STG (NOLOCK)
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_300004_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;
      END;

      COMMIT;

      FETCH NEXT FROM C_CtnTrack
      INTO @n_RowRefNo;
   END; --while C_CtnTrack     

   CLOSE C_CtnTrack;
   DEALLOCATE C_CtnTrack;

   QUIT:
   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_300004_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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