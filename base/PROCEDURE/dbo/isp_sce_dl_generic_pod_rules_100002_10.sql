SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_POD_RULES_100002_10             */
/* Creation Date: 01-Feb-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-24517 - POD - Perform Column Checking                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 01-Feb-2024  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_POD_RULES_100002_10] (
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
         , @n_RowRefNo       BIGINT = 0

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

   DECLARE @c_ttlMsg              NVARCHAR(250)
         , @c_Mbolkey             NVARCHAR(10)
         , @c_Mbollinenumber      NVARCHAR(10)
         , @c_LoadKey             NVARCHAR(5)
         , @c_Storerkey           NVARCHAR(15)
         , @c_OrderKey            NVARCHAR(10)
         , @c_BuyerPO             NVARCHAR(20)
         , @c_ExternOrderKey      NVARCHAR(50)
         , @c_InvoiceNo           NVARCHAR(20)
         , @c_Status              NVARCHAR(10)
         , @dt_ActualDeliveryDate DATETIME
         , @dt_InvDespatchDate    DATETIME
         , @dt_PodReceivedDate    DATETIME
         , @dt_PodFiledDate       DATETIME

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

   DECLARE C_CHK_COLUMN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , Mbolkey
        , Mbollinenumber
        , LoadKey
        , Storerkey
        , OrderKey
        , BuyerPO
        , ExternOrderKey
        , InvoiceNo
        , [Status]
        , ActualDeliveryDate
        , InvDespatchDate
        , PodReceivedDate
        , PodFiledDate
   FROM dbo.SCE_DL_POD_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'

   OPEN C_CHK_COLUMN
   FETCH NEXT FROM C_CHK_COLUMN
   INTO @n_RowRefNo
      , @c_Mbolkey
      , @c_Mbollinenumber     
      , @c_LoadKey            
      , @c_Storerkey          
      , @c_OrderKey           
      , @c_BuyerPO            
      , @c_ExternOrderKey     
      , @c_InvoiceNo          
      , @c_Status             
      , @dt_ActualDeliveryDate
      , @dt_InvDespatchDate   
      , @dt_PodReceivedDate   
      , @dt_PodFiledDate      

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF ISNULL(@c_Mbolkey, '') = '' OR ISNULL(@c_Mbollinenumber, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/Mbolkey or Mbollinenumber is NULL'
      END

      IF ISNULL(@c_LoadKey, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/LoadKey is NULL'
      END

      IF ISNULL(@c_OrderKey, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/OrderKey is NULL'
      END

      IF ISNULL(@c_ExternOrderKey, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ExternOrderKey is NULL'
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_POD_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status = '1'
         AND   RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_POD_RULES_100002_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END

         COMMIT
      END

      FETCH NEXT FROM C_CHK_COLUMN
      INTO @n_RowRefNo
         , @c_Mbolkey
         , @c_Mbollinenumber     
         , @c_LoadKey            
         , @c_Storerkey          
         , @c_OrderKey           
         , @c_BuyerPO            
         , @c_ExternOrderKey     
         , @c_InvoiceNo          
         , @c_Status             
         , @dt_ActualDeliveryDate
         , @dt_InvDespatchDate   
         , @dt_PodReceivedDate   
         , @dt_PodFiledDate   
   END

   CLOSE C_CHK_COLUMN
   DEALLOCATE C_CHK_COLUMN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK_COLUMN') IN (0 , 1)
   BEGIN
      CLOSE C_CHK_COLUMN
      DEALLOCATE C_CHK_COLUMN   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_POD_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
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