SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_300002_10              */
/* Creation Date: 13-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Auto Create OrderInfo record                               */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_300002_10] (
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

   DECLARE @n_RowRefNo INT;

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

   DECLARE C_ORD_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '9';

   OPEN C_ORD_INFO;
   FETCH NEXT FROM C_ORD_INFO
   INTO @n_RowRefNo;

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --while    
      BEGIN TRANSACTION;

      INSERT INTO dbo.OrderInfo
      (
         OrderKey
       , OrderInfo01
       , OrderInfo02
       , OrderInfo03
       , OrderInfo04
       , OrderInfo05
       , OrderInfo06
       , OrderInfo07
       , OrderInfo08
       , OrderInfo09
       , OrderInfo10
       , EcomOrderId
       , ReferenceId
       , StoreName
       , [Platform]
       , InvoiceType
       , PmtDate
       , InsuredAmount
       , CarrierCharges
       , OtherCharges
       , PayableAmount
       , DeliveryMode
       , CarrierName
       , DeliveryCategory
       , Notes
       , Notes2
       , OTM_OrderOwner
       , OTM_BillTo
       , OTM_NotifyParty
       , AddWho
       , EditWho
      )
      SELECT ISNULL(t1.OrderKey, '')
           , ISNULL(t1.OrderInfo01, '')
           , ISNULL(t1.OrderInfo02, '')
           , ISNULL(t1.OrderInfo03, '')
           , ISNULL(t1.OrderInfo04, '')
           , ISNULL(t1.OrderInfo05, '')
           , ISNULL(t1.OrderInfo06, '')
           , ISNULL(t1.OrderInfo07, '')
           , ISNULL(t1.OrderInfo08, '')
           , ISNULL(t1.OrderInfo09, '')
           , ISNULL(t1.OrderInfo10, '')
           , ISNULL(t1.EcomOrderId, '')
           , ISNULL(t1.ReferenceId, '')
           , ISNULL(t1.StoreName, '')
           , ISNULL(t1.[Platform], '')
           , ISNULL(t1.InvoiceType, '')
           , ISNULL(t1.PmtDate, '')
           , ISNULL(t1.InsuredAmount, '')
           , ISNULL(t1.CarrierCharges, '')
           , ISNULL(t1.OtherCharges, '')
           , ISNULL(t1.PayableAmount, '')
           , ISNULL(t1.DeliveryMode, '')
           , ISNULL(t1.CarrierName, '')
           , ISNULL(t1.DeliveryCategory, '')
           , ISNULL(t1.INotes, '')
           , ISNULL(t1.INotes2, '')
           , ISNULL(t1.OTM_OrderOwner, '')
           , ISNULL(t1.OTM_BillTo, '')
           , ISNULL(t1.OTM_NotifyParty, '')
           , t1.AddWho
           , t1.AddWho
      FROM dbo.SCE_DL_SO_STG t1 WITH (NOLOCK)
      WHERE t1.RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_300002_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;
      END;

      COMMIT;

      FETCH NEXT FROM C_ORD_INFO
      INTO @n_RowRefNo;
   END; --while  

   CLOSE C_ORD_INFO;
   DEALLOCATE C_ORD_INFO;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_300002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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