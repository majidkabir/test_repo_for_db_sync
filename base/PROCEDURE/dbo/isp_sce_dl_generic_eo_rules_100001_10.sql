SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_EO_RULES_100001_10              */
/* Creation Date: 15-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform RFIDNO, TIDNo and QRCode checking                  */
/*                                                                      */
/*                                                                      */
/* Usage: @c_InParm1 = '1' Turn on the RFIDNO, TIDNo and QRCode Checking*/
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Dec-2021  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_EO_RULES_100001_10] (
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
         , @c_ExternOrderKey NVARCHAR(50)
         , @c_SKU            NVARCHAR(20)
         , @c_QRCode         NVARCHAR(100)
         , @c_RFIDNo         NVARCHAR(100)
         , @c_TIDNo          NVARCHAR(100)
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

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , ISNULL(RTRIM(ExternOrderKey), '')
           , ISNULL(RTRIM(SKU), '')
           , ISNULL(RTRIM(QRCode), '')
           , ISNULL(RTRIM(RFIDNo), '')
           , ISNULL(RTRIM(TIDNo), '')
      FROM dbo.SCE_DL_EO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_CHK_CONF;
      FETCH NEXT FROM C_CHK_CONF
      INTO @n_RowRefNo
         , @c_ExternOrderKey
         , @c_SKU
         , @c_QRCode
         , @c_RFIDNo
         , @c_TIDNo;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N'';

         IF @c_RFIDNo <> ''
         BEGIN
            IF @c_TIDNo = ''
            BEGIN
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/RFIDNo contains value, TIDNo cannot be null.';
            END;
            ELSE
            BEGIN
               IF EXISTS (
               SELECT 1
               FROM dbo.ExternOrdersDetail WITH (NOLOCK)
               WHERE ExternOrderKey = @c_ExternOrderKey
               AND   SKU              = @c_SKU
               AND   QRCode           = @c_QRCode
               AND   RFIDNo           = @c_RFIDNo
               )
               BEGIN
                  SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/EXTERNORDERKEY+SKU+QRCODE+RFIDNO cannot be duplicate.';
               END;
            END;
         END;
         ELSE
         BEGIN
            IF EXISTS (
            SELECT 1
            FROM dbo.ExternOrdersDetail WITH (NOLOCK)
            WHERE ExternOrderKey = @c_ExternOrderKey
            AND   SKU              = @c_SKU
            AND   QRCode           = @c_QRCode
            )
            BEGIN
               SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/EXTERNORDERKEY+SKU+QRCODE cannot be duplicate.';
            END;
         END;

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_EO_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = @c_ttlMsg
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record to SCE_DL_EO_STG fail. (isp_SCE_DL_GENERIC_EO_RULES_100001_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;

            END;

            COMMIT;

         END;

         FETCH NEXT FROM C_CHK_CONF
         INTO @n_RowRefNo
            , @c_ExternOrderKey
            , @c_SKU
            , @c_QRCode
            , @c_RFIDNo
            , @c_TIDNo;
      END;

      CLOSE C_CHK_CONF;
      DEALLOCATE C_CHK_CONF;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_EO_RULES_100001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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