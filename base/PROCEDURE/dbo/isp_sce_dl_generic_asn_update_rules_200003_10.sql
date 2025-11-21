SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200003_10      */
/* Creation Date: 17-Feb-2025                                           */
/* Copyright: Maersk                                                    */
/* Written by: BDI048                                                   */
/*                                                                      */
/* Purpose: Update Receiptdetail PalletType                             */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '0' - Reject Update Receiptdetail PalletType    */
/*         @c_InParm1 = '1' - Allow Update Receiptdetail PalletType     */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 17-Feb-2025  BDI048   1.0    Init                                    */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200003_10] (
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

   DECLARE @c_StorerKey             NVARCHAR(15)
         , @c_ttlMsg                NVARCHAR(250)
         , @c_ExternReceiptkey      NVARCHAR(50)
         , @c_Receiptkey            NVARCHAR(10)
         , @c_ReceiptLineNumber     NVARCHAR(5)
         , @n_RowRefNo              BIGINT
         , @c_Receiptkey_Out        NVARCHAR(10)
         , @c_Storerkey_Get         NVARCHAR(15)     
         , @c_ExternReceiptkey_Get  NVARCHAR(50)  
         , @c_ReceiptGroup_Out      NVARCHAR(50) 
         , @c_GetReceiptkey_Out     NVARCHAR(10)

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

   
   --Validation--
   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(ExternReceiptkey), '')
                 , ISNULL(TRIM(StorerKey), '')
                 , ISNULL(TRIM(Receiptkey),'')
                 , ISNULL(TRIM(ReceiptLineNumber),'')
                 , RowRefNo
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_CHK
   
   FETCH NEXT FROM C_CHK
   INTO @c_ExternReceiptkey 
      , @c_StorerKey
      , @c_Receiptkey       
      , @c_ReceiptLineNumber
      , @n_RowRefNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      
      IF @c_InParm1 = '1'
      BEGIN
         IF ISNULL(@c_Receiptkey, '') = '' OR ISNULL(@c_ReceiptLineNumber, '') = ''
         BEGIN
            SET @c_ttlMsg += N'/Update receiptdetail :Receiptkey or receiptlinenumber cannot NULL'
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM dbo.RECEIPTDETAIL RD (NOLOCK)
                           WHERE RD.ReceiptKey = @c_Receiptkey
                           AND RD.ReceiptLineNumber = @c_ReceiptLineNumber)
            BEGIN
               SET @c_ttlMsg += N'/Receiptkey : ' + @c_Receiptkey
                              + N'Or ReceiptlineNumber : ' + @c_ReceiptLineNumber + N' not exists'
            END
         END
      END

      IF EXISTS (SELECT 1
                 FROM dbo.RECEIPT R (NOLOCK)
                 WHERE R.ExternReceiptKey = @c_ExternReceiptkey
                 AND R.ReceiptKey = @c_Receiptkey
                 AND R.ASNStatus = '9') AND  @c_InParm1 = '1'
      BEGIN
         SET @c_ttlMsg += N'/RECEIPT already Finalized, update failed'
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   RowRefNo    = @n_RowRefNo
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200003_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      FETCH NEXT FROM C_CHK
      INTO @c_ExternReceiptkey 
         , @c_StorerKey
         , @c_Receiptkey       
         , @c_ReceiptLineNumber
         , @n_RowRefNo
   END
   CLOSE C_CHK
   DEALLOCATE C_CHK

   --Update--
   DECLARE C_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(ExternReceiptkey), '')
                 , ISNULL(TRIM(StorerKey), '')
                 , ISNULL(TRIM(Receiptkey),'')
                 , ISNULL(TRIM(ReceiptLineNumber),'')
                 , RowRefNo
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_UPD
   
   FETCH NEXT FROM C_UPD
   INTO @c_ExternReceiptkey 
      , @c_StorerKey
      , @c_Receiptkey       
      , @c_ReceiptLineNumber
      , @n_RowRefNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      SELECT @c_Receiptkey_Out = R.Receiptkey
      FROM RECEIPT R (NOLOCK)
      WHERE R.StorerKey = @c_StorerKey
      AND R.ExternReceiptKey = @c_ExternReceiptkey

      IF @c_InParm1 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
			 SET PalletType = ISNULL(STG.PalletType, RecDet.PalletType)          
			   , EditWho = SUSER_SNAME()
			   , EditDate = GETDATE()
			 FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
			 JOIN RECEIPTDETAIL RecDet ON (  STG.ReceiptKey = RecDet.ReceiptKey
									   AND   STG.ReceiptLineNumber = RecDet.ReceiptLineNumber)
			 WHERE RecDet.ReceiptKey = @c_Receiptkey
			 AND   RecDet.ReceiptLineNumber = @c_ReceiptLineNumber			 
			 AND   STG.STG_BatchNo = @n_BatchNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END   

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   RowRefNo    = @n_RowRefNo
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200003_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END           
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT
      END

	  UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo

      FETCH NEXT FROM C_UPD
      INTO @c_ExternReceiptkey 
         , @c_StorerKey
         , @c_Receiptkey       
         , @c_ReceiptLineNumber
         , @n_RowRefNo
   END
   CLOSE C_UPD
   DEALLOCATE C_UPD

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END

   IF CURSOR_STATUS('LOCAL', 'C_UPD') IN (0 , 1)
   BEGIN
      CLOSE C_UPD
      DEALLOCATE C_UPD   
   END
   
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200003_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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