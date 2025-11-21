SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_BOM_RULES_200001_10             */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert into BOM target table                       */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' DeleteB4Insert                              */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_BOM_RULES_200001_10]
(
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

   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_Sku            NVARCHAR(20)
         , @c_ComponentSku   NVARCHAR(20)
         , @c_Sequence       NVARCHAR(10)
         , @n_RowRefNo       INT
         , @c_AdjustmentType NVARCHAR(5)
         , @c_CustomerRefNo  NVARCHAR(10)
         , @c_AdjustmentKey  NVARCHAR(10)
         , @n_GetQty         INT
         , @c_UOM            NVARCHAR(10)
         , @c_Packkey        NVARCHAR(10)
         , @n_Qty            INT
         , @n_iNo            INT
         , @c_ttlMsg         NVARCHAR(250);

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (SPName NVARCHAR(300) '$.SubRuleSP'
          , InParm1 NVARCHAR(60) '$.InParm1'
          , InParm2 NVARCHAR(60) '$.InParm2'
          , InParm3 NVARCHAR(60) '$.InParm3'
          , InParm4 NVARCHAR(60) '$.InParm4'
          , InParm5 NVARCHAR(60) '$.InParm5')
   WHERE SPName = OBJECT_NAME(@@PROCID);

   BEGIN TRANSACTION;

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , TRIM(StorerKey)
        , TRIM(Sku)
        , TRIM(ComponentSku)
        , TRIM([Sequence])
   FROM dbo.SCE_DL_BOM_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @n_RowRefNo
      , @c_Storerkey
      , @c_Sku
      , @c_ComponentSku
      , @c_Sequence;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      --DeleteB4Insert
      IF @c_InParm1 = '1'
      BEGIN
         IF EXISTS (SELECT 1
                    FROM BillOfMaterial BOM (NOLOCK)
                    WHERE BOM.Storerkey = @c_Storerkey
                    AND BOM.SKU = @c_SKU)
         BEGIN
            DELETE FROM BillOfMaterial
            WHERE Storerkey = @c_Storerkey
            AND SKU = @c_SKU

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END
      END
      
      INSERT INTO dbo.BillOfMaterial (Storerkey, Sku, ComponentSku, Sequence, BomOnly, Notes, Qty, ParentQty, AddWho
                                    , UDF01, UDF02, UDF03, UDF04, UDF05)
      SELECT @c_Storerkey
           , @c_Sku
           , @c_ComponentSku
           , @c_Sequence
           , ISNULL(BomOnly, '')
           , ISNULL(Notes, '')
           , Qty
           , ParentQty
           , @c_Username
           , UDF01
           , UDF02
           , UDF03
           , UDF04
           , UDF05
      FROM dbo.SCE_DL_BOM_STG STG WITH (NOLOCK)
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      UPDATE dbo.SCE_DL_BOM_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo;

      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Storerkey
         , @c_Sku
         , @c_ComponentSku
         , @c_Sequence;
   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_BOM_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(TRIM(@c_ErrMsg), '');
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