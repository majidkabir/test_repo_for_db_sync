SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100001_10       */
/* Creation Date: 19-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform ExternOrderKey Checking                 */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' will validate the ExternOrderKey whether    */
/*         is null or not.                                              */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Aug-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100001_10] (
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements  NVARCHAR(4000)
         , @c_ExecArguments   NVARCHAR(4000)
         , @n_Continue        INT
         , @n_StartTCnt       INT
         , @c_ExternOrderkey  NVARCHAR(50)

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    


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
   WHERE SPName = OBJECT_NAME(@@PROCID)

   IF @c_InParm1 = '1'
   BEGIN
      IF EXISTS (
         SELECT 1
         FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   ISNULL(TRIM(ExternOrderkey),'') = ''
      )
      BEGIN
         BEGIN TRANSACTION

         UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/ExternOrderKey is Null'
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   ISNULL(TRIM(ExternOrderkey),'') = ''

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT
      END
      ELSE
      BEGIN
         DECLARE CUR_CHECK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(TRIM(ExternOrderkey), '')
         FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         GROUP BY ISNULL(TRIM(ExternOrderkey), '')

         OPEN CUR_CHECK

         FETCH NEXT FROM CUR_CHECK INTO @c_ExternOrderkey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS (SELECT 1 
                           FROM dbo.ORDERS OH (NOLOCK) 
                           WHERE ExternOrderkey IN (@c_ExternOrderkey))
            BEGIN
               BEGIN TRANSACTION

               UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/ExternOrderKey not exists'
               WHERE STG_BatchNo    = @n_BatchNo
               AND   STG_Status     = '1'
               AND   ExternOrderkey = @c_ExternOrderkey
            
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_ErrNo = 68002
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100001_10)'
                  ROLLBACK
                  GOTO STEP_999_EXIT_SP
               END
               COMMIT
            END

            FETCH NEXT FROM CUR_CHECK INTO @c_ExternOrderkey
         END
         CLOSE CUR_CHECK
         DEALLOCATE CUR_CHECK
      END
   END
   ELSE
   BEGIN
      IF EXISTS (
         SELECT 1
         FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   ISNULL(TRIM(Loadkey),'') = ''
      )
      BEGIN
         BEGIN TRANSACTION

         UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/Loadkey is Null'
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   ISNULL(TRIM(Loadkey),'') = ''

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68003
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT
      END
   END

   QUIT:

   STEP_999_EXIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_CHECK') IN (0 , 1)
   BEGIN
      CLOSE CUR_CHECK
      DEALLOCATE CUR_CHECK   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100001_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1
   END
   ELSE
   BEGIN
      SET @b_Success = 0
   END
END

GO