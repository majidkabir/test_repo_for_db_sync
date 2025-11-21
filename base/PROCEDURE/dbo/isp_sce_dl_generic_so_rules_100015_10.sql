SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_100015_10              */
/* Creation Date: 28-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Order Allow Update Checking and status             */
/*           and Split externorderkey according to splitOrder value     */
/*                                                                      */
/* Usage:   Update or Ignore @c_InParm1 =  '0'  Ignore                  */
/*                           @c_InParm1 =  '1'  update is allow         */
/*                           @c_InParm1 =  '2'  Insert new only         */
/*                           @c_InParm1 =  '3'  Insert new if CANC      */
/*          split Order      @c_InParm2 =  '0'  turn off                */
/*                           @c_InParm2 =  '1'  turn on                 */
/*          splitOrder Value @c_InParm3 =  'abc123'                     */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.3                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Dec-2021  GHChan    1.1   Initial                                 */
/* 20-Feb-2023  WLChooi   1.1   DevOps Combine Script                   */
/* 20-Feb-2023  WLChooi   1.1   LFWM-3423 - Bug Fix (WL01)              */
/* 13-Jun-2023  WLChooi   1.2   UWP-1573 - Modify InParm1 - Allow insert*/
/*                              new if Status = CANC (WL01)             */
/* 15-Aug-2023  WLChooi   1.3   JSM-170432 - Initialize var value (WL03)*/
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_100015_10] (
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

   DECLARE @c_ExternOrderKey NVARCHAR(50)
         , @c_Storerkey      NVARCHAR(20)
         , @c_Orderkey       NVARCHAR(10)
         , @c_ChkStatus      NVARCHAR(10)
         , @c_OrderGroup     NVARCHAR(20)
         , @c_ttlMsg         NVARCHAR(250);

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

   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(ExternOrderkey), '')
        , ISNULL(RTRIM(Storerkey), '')
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   GROUP BY ISNULL(RTRIM(ExternOrderkey), '')
          , ISNULL(RTRIM(Storerkey), '');

   OPEN C_CHK;
   FETCH NEXT FROM C_CHK
   INTO @c_ExternOrderKey
      , @c_Storerkey;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N'';
      --WL03 S
      SET @c_Orderkey = '';
      SET @c_ChkStatus = '';
      SET @c_OrderGroup = '';
      --WL03 E

      IF ISNULL(@c_ExternOrderKey,'') = ''   --WL01
      BEGIN
         GOTO NEXTITEM;
      END;

      SELECT @c_Orderkey   = ISNULL(RTRIM(OrderKey), '')
           , @c_ChkStatus  = [Status]
           , @c_OrderGroup = OrderGroup
      FROM dbo.V_ORDERS WITH (NOLOCK)
      WHERE ExternOrderKey = @c_ExternOrderKey
      AND   StorerKey        = @c_Storerkey;

      IF @b_Debug = '1'
      BEGIN
         SELECT '@c_OrderKey : ' + ISNULL(@c_Orderkey,'');   --WL01
      END;

      IF ISNULL(@c_Orderkey,'') = ''   --WL01
      BEGIN
         GOTO NEXTITEM;
      END;

      IF @c_InParm2 = '0'
      BEGIN
         IF @c_InParm1 = '0'
         BEGIN
            SET @c_ttlMsg = N'Error:Order already exists';
         END;
         ELSE IF @c_InParm1 = '3'   --WL01 S
         BEGIN
            IF @c_ChkStatus NOT IN ('CANC')
            BEGIN
               SET @c_ttlMsg = N'Error:Order already exists';
            END
         END;   --WL01 E
         ELSE IF @c_InParm1 = '1'
         BEGIN
            IF @c_ChkStatus > '0'
            BEGIN
               SET @c_ttlMsg = N'Error:Order already Finalized, update failed';
            END;
         END;
         ELSE IF @c_InParm1 = '1'
              OR @c_InParm1 = '2'
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
            SET STG_ErrMsg = N'Warn:Order already exists'
            WHERE STG_BatchNo  = @n_BatchNo
            AND   STG_Status     = '1'
            AND   ExternOrderkey = @c_ExternOrderKey
            AND   Storerkey      = @c_Storerkey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100015_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;

            END;

            COMMIT;
         END;
      END;
      ELSE IF @c_InParm2 = '1'
      BEGIN
         IF @c_InParm1 <> '2'
         BEGIN
            SET @c_ttlMsg = N'Error:UpdateOrIgnore config must be 2 when spilt order config turn on ';
            GOTO NEXTITEM;
         END;

         IF @c_ChkStatus NOT IN ('5', '9')
         BEGIN
            SET @c_ttlMsg = N'Error:Order status not in 5 or 9,split order failed';
            GOTO NEXTITEM;
         END;

         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_ErrMsg = N'Warn:Order already exists'
         WHERE STG_BatchNo  = @n_BatchNo
         AND   STG_Status     = '1'
         AND   ExternOrderkey = @c_ExternOrderKey
         AND   Storerkey      = @c_Storerkey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100015_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;
      END;

      NEXTITEM:

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo  = @n_BatchNo
         AND   STG_Status     = '1'
         AND   ExternOrderkey = @c_ExternOrderKey
         AND   Storerkey      = @c_Storerkey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100015_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;
      END;

      IF @c_InParm2 = '1'
      BEGIN

         IF @c_Storerkey = @c_InParm3
         BEGIN
            BEGIN TRANSACTION;

            UPDATE SO WITH (ROWLOCK)
            SET SO.splitOrder = ISNULL(SKU.HazardousFlag, '')
            FROM SCE_DL_SO_STG SO
            JOIN dbo.V_SKU     Sku WITH (NOLOCK)
            ON (
                SO.Storerkey = Sku.StorerKey
            AND SO.SKU   = Sku.Sku
            )
            WHERE SO.STG_BatchNo  = @n_BatchNo
            AND   SO.STG_Status     = '1'
            AND   SO.ExternOrderkey = @c_ExternOrderKey
            AND   SO.Storerkey      = @c_Storerkey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100015_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;

            END;

            COMMIT;
         END;

         IF @c_InParm1 = '1'
         BEGIN
            BEGIN TRANSACTION;

            UPDATE SO WITH (ROWLOCK)
            SET SO.splitOrder = @c_OrderGroup
            FROM SCE_DL_SO_STG SO
            JOIN dbo.V_SKU     Sku WITH (NOLOCK)
            ON (
                SO.Storerkey = Sku.StorerKey
            AND SO.SKU   = Sku.Sku
            )
            WHERE SO.STG_BatchNo  = @n_BatchNo
            AND   SO.STG_Status     = '1'
            AND   SO.ExternOrderkey = @c_ExternOrderKey
            AND   SO.Storerkey      = @c_Storerkey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100015_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;

            END;

            COMMIT;
         END;
      END;

      FETCH NEXT FROM C_CHK
      INTO @c_ExternOrderKey
         , @c_Storerkey;
   END;

   CLOSE C_CHK;
   DEALLOCATE C_CHK;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_100015_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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