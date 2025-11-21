SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CONSIGNEESKU_RULES_200001_10    */
/* Creation Date: 29-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23690 - Perform insert into CONSIGNEESKU target table   */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Allow Update                                */
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
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CONSIGNEESKU_RULES_200001_10] (
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

   DECLARE @n_RowRefNo           BIGINT
         , @c_ttlMsg             NVARCHAR(250)
         , @c_Storerkey          NVARCHAR(15)
         , @c_SKU                NVARCHAR(20)
         , @c_ConsigneeKey       NVARCHAR(20)
         , @c_ConsigneeSKU       NVARCHAR(20)
         , @c_ConsigneeSKUAddWho NVARCHAR(128)

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

   BEGIN TRANSACTION
   
   DECLARE C_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(Storerkey), '')
                 , ISNULL(TRIM(SKU), '')
                 , ISNULL(TRIM(ConsigneeKey), '')
                 , ISNULL(TRIM(ConsigneeSKU), '')
                 , ISNULL(TRIM(ConsigneeSKUAddWho), '')
                 , RowRefNo
   FROM dbo.SCE_DL_CONSIGNEESKU_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   ORDER BY RowRefNo
   
   OPEN C_INS
   FETCH NEXT FROM C_INS
   INTO @c_StorerKey
      , @c_SKU
      , @c_ConsigneeKey
      , @c_ConsigneeSKU
      , @c_ConsigneeSKUAddWho
      , @n_RowRefNo
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      
      IF EXISTS ( SELECT 1
                  FROM CONSIGNEESKU CS (NOLOCK)
                  WHERE CS.ConsigneeKey = @c_ConsigneeKey
                  AND CS.ConsigneeSKU = @c_ConsigneeSKU)
      BEGIN
         IF @c_InParm1 = '1'
         BEGIN
            --Update
            BEGIN TRANSACTION
      
            UPDATE CS WITH (ROWLOCK)
            SET CS.ConsigneeKey = CASE WHEN ISNULL(STG.ConsigneeKey, '') = '' THEN CS.ConsigneeKey WHEN STG.ConsigneeKey = '$$' THEN '' ELSE STG.ConsigneeKey END
              , CS.ConsigneeSKU = CASE WHEN ISNULL(STG.ConsigneeSKU, '') = '' THEN CS.ConsigneeSKU WHEN STG.ConsigneeSKU = '$$' THEN '' ELSE STG.ConsigneeSKU END
              , CS.StorerKey    = CASE WHEN ISNULL(STG.StorerKey   , '') = '' THEN CS.StorerKey    WHEN STG.StorerKey = '$$'    THEN '' ELSE STG.StorerKey END
              , CS.SKU    = CASE WHEN ISNULL(STG.SKU, '')    = '' THEN CS.SKU    WHEN STG.SKU = '$$'    THEN '' ELSE STG.SKU END
              , CS.UOM    = CASE WHEN ISNULL(STG.UOM, '')    = '' THEN CS.UOM    WHEN STG.UOM = '$$'    THEN '' ELSE STG.UOM END
              , CS.Active = CASE WHEN ISNULL(STG.Active, '') = '' THEN CS.Active WHEN STG.Active = '$$' THEN '' ELSE STG.Active END
              , CS.CrossSKUQty = CASE WHEN ISNULL(STG.CrossSKUQty, 0) = 0 THEN CS.CrossSKUQty WHEN STG.CrossSKUQty = -1 THEN 0 ELSE STG.CrossSKUQty END
              , CS.UDF01 = CASE WHEN ISNULL(STG.UDF01, '') = '' THEN CS.UDF01 WHEN STG.UDF01 = '$$' THEN '' ELSE STG.UDF01 END 
              , CS.UDF02 = CASE WHEN ISNULL(STG.UDF02, '') = '' THEN CS.UDF02 WHEN STG.UDF02 = '$$' THEN '' ELSE STG.UDF02 END 
              , CS.UDF03 = CASE WHEN ISNULL(STG.UDF03, '') = '' THEN CS.UDF03 WHEN STG.UDF03 = '$$' THEN '' ELSE STG.UDF03 END 
              , CS.UDF04 = CASE WHEN ISNULL(STG.UDF04, '') = '' THEN CS.UDF04 WHEN STG.UDF04 = '$$' THEN '' ELSE STG.UDF04 END 
              , CS.UDF05 = CASE WHEN ISNULL(STG.UDF05, '') = '' THEN CS.UDF05 WHEN STG.UDF05 = '$$' THEN '' ELSE STG.UDF05 END 
              , CS.EditWho = ISNULL(STG.ConsigneeSKUAddWho, STG.Addwho)
              , CS.EditDate = GETDATE()
            FROM SCE_DL_CONSIGNEESKU_STG STG (NOLOCK)
            JOIN CONSIGNEESKU CS ON CS.ConsigneeKey = STG.ConsigneeKey AND CS.ConsigneeSKU = STG.ConsigneeSKU
            WHERE STG.RowRefNo = @n_RowRefNo
            AND STG_BatchNo = @n_BatchNo
            AND STG_Status  = '1'
         END
         ELSE
         BEGIN
            UPDATE dbo.SCE_DL_CONSIGNEESKU_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: ConsigneeKey: ' + TRIM(@c_ConsigneeKey) + 
                           + ' AND ConsigneeSKU: ' + TRIM(@c_ConsigneeSKU) + ' already exists in CONSIGNEESKU table.'
            WHERE RowRefNo = @n_RowRefNo
            AND STG_BatchNo = @n_BatchNo
            AND STG_Status  = '1'

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            GOTO NEXT_ITEM
         END
      END
      ELSE
      BEGIN
         --Insert
         BEGIN TRANSACTION
   
         INSERT INTO CONSIGNEESKU ( ConsigneeKey, ConsigneeSKU, StorerKey, SKU
                                  , UOM, Active, CrossSKUQty
                                  , UDF01, UDF02, UDF03, UDF04, UDF05
                                  , AddWho, AddDate
                                  , EditWho, EditDate )
         SELECT ConsigneeKey, ConsigneeSKU, StorerKey, SKU
              , ISNULL(UOM, 'EA'), ISNULL(Active, 'Y'), ISNULL(CrossSKUQty, 0)
              , ISNULL(UDF01, ''), ISNULL(UDF02, ''), ISNULL(UDF03, ''), ISNULL(UDF04, ''), ISNULL(UDF05, '')
              , ISNULL(ConsigneeSKUAddWho, Addwho), AddDate
              , ISNULL(ConsigneeSKUAddWho, Addwho), AddDate
         FROM SCE_DL_CONSIGNEESKU_STG STG (NOLOCK)
         WHERE STG.RowRefNo = @n_RowRefNo
         AND STG_BatchNo = @n_BatchNo
         AND STG_Status  = '1'
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
   
      UPDATE dbo.SCE_DL_CONSIGNEESKU_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXT_ITEM:

      FETCH NEXT FROM C_INS
      INTO @c_StorerKey
         , @c_SKU
         , @c_ConsigneeKey
         , @c_ConsigneeSKU
         , @c_ConsigneeSKUAddWho
         , @n_RowRefNo
   END
   
   CLOSE C_INS
   DEALLOCATE C_INS
   
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CONSIGNEESKU_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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