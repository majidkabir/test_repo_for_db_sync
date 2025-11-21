SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100003_10       */
/* Creation Date: 19-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform Checking on updating by OrderLineNumber */
/*          OR ExternLineNo                                             */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' will validate to update by Order Line Number*/
/*         or not.                                                      */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100003_10] (
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
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_ExternLineNo    NVARCHAR(20)
         , @c_DUDEF03         NVARCHAR(50)
         , @c_SKU             NVARCHAR(20)

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
         AND   ISNULL(TRIM(OrderLineNumber),'') = ''
      )
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/OrderLineNumber is Null'
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   ISNULL(TRIM(OrderLineNumber),'') = ''
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100003_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT
      END
   END

   DECLARE CUR_CHECK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ExternOrderkey, OrderLineNumber
        , ExternLineNo, DUdef03
        , SKU
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   GROUP BY ExternOrderkey, OrderLineNumber
          , ExternLineNo, DUdef03 
          , SKU
   ORDER BY ExternOrderkey, OrderLineNumber
          , ExternLineNo, DUdef03
          , SKU

   OPEN CUR_CHECK

   FETCH NEXT FROM CUR_CHECK INTO @c_ExternOrderkey, @c_OrderLineNumber
                                , @c_ExternLineNo, @c_DUDEF03, @c_SKU
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_InParm1 = '1'
      BEGIN
         IF ISNULL(TRIM(@c_OrderLineNumber),'') <> '' AND
            @c_DUDEF03 IN ( 'ADJUST', 'DAMAGED', 'NEXP', 'SHIP', 'SORT', 'WOFF' )
         BEGIN
            IF NOT EXISTS ( 
               SELECT 1
               FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
               WHERE OD.ExternOrderKey = @c_ExternOrderkey
               AND OD.[Status] = '0'
               AND OD.OrderLineNumber = @c_OrderLineNumber
               AND OD.SKU = @c_SKU
            )
            BEGIN
               BEGIN TRANSACTION
   
               UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/Incorrect Data'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status  = '1'
               AND   ExternOrderkey = @c_ExternOrderkey
               AND   OrderLineNumber = @c_OrderLineNumber
               AND   SKU = @c_SKU
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_ErrNo = 68001
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100003_10)'
                  ROLLBACK
                  GOTO STEP_999_EXIT_SP
               END
               COMMIT
            END
         END
      END
      
      IF @c_InParm1 = '0'
      BEGIN
         IF @c_DUDEF03 IN ( 'ADJUST', 'DAMAGED', 'NEXP', 'SHIP', 'SORT', 'WOFF' )
         BEGIN
            IF NOT EXISTS ( 
               SELECT 1
               FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
               WHERE OD.ExternOrderKey = @c_ExternOrderkey
               AND OD.[Status] = '0'
               AND OD.ExternLineNo = @c_ExternLineNo
               AND OD.SKU = @c_SKU
            )
            BEGIN
               BEGIN TRANSACTION
   
               UPDATE SCE_DL_SO_STG WITH (ROWLOCK)
               SET STG_Status = '3'
                 , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/Incorrect Data'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status  = '1'
               AND   ExternOrderkey = @c_ExternOrderkey
               AND   ExternLineNo = @c_ExternLineNo
               AND   SKU = @c_SKU
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_ErrNo = 68001
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                                  + ': Update record fail. (isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100003_10)'
                  ROLLBACK
                  GOTO STEP_999_EXIT_SP
               END
               COMMIT
            END
         END
      END

      FETCH NEXT FROM CUR_CHECK INTO @c_ExternOrderkey, @c_OrderLineNumber
                                   , @c_ExternLineNo, @c_DUDEF03, @c_SKU
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_100003_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
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