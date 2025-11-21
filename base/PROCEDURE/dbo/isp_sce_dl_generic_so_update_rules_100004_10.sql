SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100004_10       */
/* Creation Date: 19-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform Update Order Checking                   */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Allow Update Order Group (Status = 0)       */
/*         @c_InParm1 = '2' Allow Update Order Group (Status < 9)       */
/*         @c_InParm2 = '1' Allow Update Order Header (Status = 0)      */
/*         @c_InParm2 = '2' Allow Update Order Header (Status < 9)      */
/*         @c_InParm3 = '1' Allow Update UA Order Header                */
/*         @c_InParm4 = '1' Allow Update SOStatus <> CANC               */
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

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100004_10] (
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
         , @c_Storerkey       NVARCHAR(15)
         , @c_Orderkey        NVARCHAR(10)
         , @c_Status          NVARCHAR(20)

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

   DECLARE CUR_CHECK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ExternOrderkey, Storerkey, OrderKey
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   GROUP BY ExternOrderkey, Storerkey, OrderKey
   
   OPEN CUR_CHECK
   
   FETCH NEXT FROM CUR_CHECK INTO @c_ExternOrderkey, @c_Storerkey, @c_Orderkey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_Status = ''

      SELECT @c_Status = OH.[STATUS]
      FROM dbo.ORDERS OH WITH (NOLOCK)
      WHERE OH.OrderKey = @c_Orderkey

      IF ISNULL(TRIM(@c_Orderkey),'') <> ''
      BEGIN
         IF (@c_InParm1 = '1' OR @c_InParm2 = '1')
         BEGIN
            IF @c_Status <> '0'
            BEGIN
               BEGIN TRANSACTION
         
               UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/Status is not 0. Cannot Update OrderHeader and OrderGroup'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status  = '1'
               AND   ExternOrderkey = @c_ExternOrderkey
               AND   Storerkey = @c_Storerkey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_ErrNo = 68001
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100004_10)'
                  ROLLBACK
                  GOTO STEP_999_EXIT_SP
               END
               COMMIT
            END
         END

         IF (@c_InParm3 = '1' OR @c_InParm4 = '1')
         BEGIN
            IF @c_Status = '9'
            BEGIN
               BEGIN TRANSACTION
         
               UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/Status 9. Cannot Update OrderHeader '
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status  = '1'
               AND   ExternOrderkey = @c_ExternOrderkey
               AND   Storerkey = @c_Storerkey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_ErrNo = 68001
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100004_10)'
                  ROLLBACK
                  GOTO STEP_999_EXIT_SP
               END
               COMMIT
            END
         END
      END

      FETCH NEXT FROM CUR_CHECK INTO @c_ExternOrderkey, @c_Storerkey, @c_Orderkey
   END
   CLOSE CUR_CHECK
   DEALLOCATE CUR_CHECK

   QUIT:

   STEP_999_EXIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_CHECK') IN (0 , 1)
   BEGIN
      CLOSE CUR_CHECK
      DEALLOCATE CUR_CHECK   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100004_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
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