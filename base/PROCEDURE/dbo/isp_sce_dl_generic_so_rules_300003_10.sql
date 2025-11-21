SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_300003_10              */
/* Creation Date: 13-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose: AB Allocation OD.lottable03 (A: full carton; B: pieces)     */
/*                                                                      */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_300003_10] (
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

   DECLARE @c_Orderkey        NVARCHAR(10)


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

   DECLARE C_ALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '9';

   OPEN C_ALLOC;
   FETCH NEXT FROM C_ALLOC
   INTO @c_Orderkey;

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --while    
      BEGIN TRANSACTION;

      UPDATE a WITH (ROWLOCK)
      SET a.Lottable01 = CASE c.CaseCnt WHEN 0 THEN 'B'
                                        ELSE CASE a.OriginalQty % CAST(c.CaseCnt AS INT)WHEN 0 THEN 'A'
                                                                                        ELSE 'B'
                                             END
                         END
        , EditDate = GETDATE()
      FROM dbo.ORDERDETAIL a
      JOIN dbo.V_SKU       b WITH (NOLOCK)
      ON  a.StorerKey = b.StorerKey
      AND a.Sku      = b.Sku
      JOIN dbo.V_PACK      c WITH (NOLOCK)
      ON b.PACKKey   = c.PackKey
      WHERE a.OrderKey = @c_Orderkey;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 68001;
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                         + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_300003_10)';
         ROLLBACK;
         GOTO STEP_999_EXIT_SP;
      END;

      COMMIT;

      FETCH NEXT FROM C_ALLOC
      INTO @c_Orderkey;
   END; --while  

   CLOSE C_ALLOC;
   DEALLOCATE C_ALLOC;

   QUIT:
   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_300003_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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