SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_BTB_FTA_RULES_100002_10         */
/* Creation Date: 22-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20803 - Perform Column Checking                         */
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
/* 22-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/* 13-Jun-2023  WLChooi   1.1   WMS-20803 - Bug Fix (WL01)              */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_BTB_FTA_RULES_100002_10] (
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
         , @c_SKU          NVARCHAR(20)
         , @c_Authority    NVARCHAR(30)
         , @c_Option1      NVARCHAR(50)
         , @c_Option2      NVARCHAR(50)
         , @c_Option3      NVARCHAR(50)
         , @c_Option4      NVARCHAR(50)
         , @c_Option5      NVARCHAR(4000)
         , @c_AllowSKU     NVARCHAR(50)
         , @c_Descr        NVARCHAR(60)
         , @c_BTBShipItem  NVARCHAR(50)

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
                 , ISNULL(TRIM(SKU), '')
                 , ISNULL(TRIM(BTBShipItem),'')
   FROM dbo.SCE_DL_BTB_FTA_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_CHK
   
   FETCH NEXT FROM C_CHK
   INTO @c_StorerKey
      , @c_SKU
      , @c_BTBShipItem
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg     = N''
      SET @c_Authority  = N''
      SET @c_Option1    = N''
      SET @c_Option2    = N''
      SET @c_Option3    = N''
      SET @c_Option4    = N''
      SET @c_Option5    = N''
      SET @c_AllowSKU   = N'N'

      EXEC dbo.nspGetRight @c_Facility = NULL                
                         , @c_StorerKey = @c_StorerKey                
                         , @c_sku = NULL                 
                         , @c_ConfigKey = N'BTBShipmentByItem'                
                         , @b_Success  = @b_Success OUTPUT    
                         , @c_Authority = @c_Authority OUTPUT
                         , @n_err = @n_ErrNo OUTPUT            
                         , @c_errmsg = @c_errmsg OUTPUT      
                         , @c_Option1 = @c_Option1 OUTPUT    
                         , @c_Option2 = @c_Option2 OUTPUT    
                         , @c_Option3 = @c_Option3 OUTPUT    
                         , @c_Option4 = @c_Option4 OUTPUT    
                         , @c_Option5 = @c_Option5 OUTPUT    

      SELECT @c_AllowSKU = dbo.fnc_GetParamValueFromString('@c_AllowSKU', @c_Option5, @c_AllowSKU)

      IF ISNULL(@c_AllowSKU,'') = ''
         SET @c_AllowSKU = 'N'

      IF ISNULL(@c_Authority,'') = ''
         SET @c_Authority = '0'

      IF @c_Authority = '1'
      BEGIN
         IF @c_SKU <> '' AND @c_AllowSKU = 'N'
         BEGIN
            SET @c_ttlMsg += N'/Error: Storer is setup to use BTB Ship Item. Leave Sku Empty'
         END
      END
      ELSE IF @c_Authority = '0'
      BEGIN
         IF @c_BTBShipItem <> ''
         BEGIN
            SET @c_ttlMsg += N'/Error: Storer is setup to use WMS Sku for BTB shipment . Leave BTB Ship Item Empty'
         END
      END

      IF ((@c_Authority = '1' AND @c_SKU <> '' AND @c_AllowSKU = 'Y')
      OR  (@c_Authority = '0' AND @c_SKU <> '' )) AND @c_ttlMsg = ''
      BEGIN 
         IF NOT EXISTS (SELECT 1
                        FROM SKU (NOLOCK)
                        WHERE Storerkey = @c_StorerKey
                        AND SKU = @c_SKU)
         BEGIN 
            SET @c_ttlMsg += N'/Error: SKU ' + @c_SKU + ' not exists in Storer ' + @c_StorerKey + '.'
         END
         ELSE
         BEGIN
            BEGIN TRANSACTION

            SELECT @c_Descr = SKU.DESCR
            FROM SKU (NOLOCK)
            WHERE Storerkey = @c_StorerKey
            AND SKU = @c_SKU

            UPDATE dbo.SCE_DL_BTB_FTA_STG WITH (ROWLOCK)
            SET SkuDescr = CASE WHEN ISNULL(SkuDescr,'') = '' THEN @c_Descr ELSE SkuDescr END   --WL01
            WHERE STG_BatchNo                  = @n_BatchNo
            AND   STG_Status                   = '1'
            AND   ISNULL(TRIM(StorerKey), '')  = @c_StorerKey
            AND   ISNULL(TRIM(SKU), '')        = @c_SKU

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 68002
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_BTB_FTA_RULES_100002_10)'
               ROLLBACK TRANSACTION
               GOTO STEP_999_EXIT_SP
            END

            WHILE @@TRANCOUNT > 0
               COMMIT TRANSACTION
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_BTB_FTA_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo                  = @n_BatchNo
         AND   STG_Status                   = '1'
         AND   ISNULL(TRIM(StorerKey), '')  = @c_StorerKey
         AND   ISNULL(TRIM(SKU), '')        = @c_SKU
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_BTB_FTA_RULES_100002_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END
   
      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_SKU
         , @c_BTBShipItem
   
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_BTB_FTA_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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