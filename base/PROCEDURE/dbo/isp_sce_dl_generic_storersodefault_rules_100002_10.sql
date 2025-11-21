SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_100002_10 */
/* Creation Date: 29-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23690 - Perform Column Checking                         */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Enable Checking                             */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Sep-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_100002_10] (
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

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT

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

   DECLARE @c_StorerKey    NVARCHAR(15)
         , @c_ttlMsg       NVARCHAR(250)
         , @c_OrderType    NVARCHAR(10)
         , @c_Route        NVARCHAR(10)
         , @n_RowRefNo     BIGINT

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

   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(Storerkey), '')
                 , ISNULL(TRIM(OrderType), '')
                 , ISNULL(TRIM([Route]),'')
                 , RowRefNo
   FROM dbo.SCE_DL_STORERSODEFAULT_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_CHK
   
   FETCH NEXT FROM C_CHK
   INTO @c_StorerKey
      , @c_OrderType
      , @c_Route
      , @n_RowRefNo
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF ISNULL(@c_Storerkey,'') = ''
      BEGIN
         SET @c_ttlMsg += N'/Error: Storerkey is NULL.'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1
                         FROM STORER (NOLOCK)
                         WHERE Storerkey = @c_Storerkey )
         BEGIN
            SET @c_ttlMsg += N'/Error: Storerkey: ' + @c_Storerkey + ' Not Exists.'
         END
      END

      --Skip some validation if updating
      IF EXISTS ( SELECT 1 
                  FROM STORERSODEFAULT SOD (NOLOCK) 
                  WHERE Storerkey = @c_StorerKey )
      BEGIN
         SET @c_InParm1 = '0'
      END

      IF @c_InParm1 = '1'
      BEGIN
         IF ISNULL(@c_OrderType,'') <> ''
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM CODELKUP (NOLOCK)
                            WHERE LISTNAME = 'OrderType'
                            AND Code = @c_OrderType )
            BEGIN
               SET @c_ttlMsg += N'/Error: OrderType: ' + @c_OrderType + ' Not Exists.'
            END
         END

         IF ISNULL(@c_Route,'') = ''
         BEGIN
            SET @c_ttlMsg += N'/Error: Route is NULL.'
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_STORERSODEFAULT_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   RowRefNo    = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_100002_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END
   
      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_OrderType
         , @c_Route
         , @n_RowRefNo
   END
   CLOSE C_CHK
   DEALLOCATE C_CHK

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END
   
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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