SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_UPC_RULES_200001_10             */
/* Creation Date: 09-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert into UPC target table     	               */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*         @c_InParm2 = '1' Allow Update '0' Ignore Update              */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-May-2022  GHChan    1.1   Initial                                 */
/* 01-Sep-2022  WLChooi   1.2   WMS-20449 - Add Qty (WL01)              */
/* 01-Sep-2022  WLChooi   1.2   DevOps Combine Script                   */
/* 26-Sep-2022  WLChooi   1.3   WMS-20824 - Allow Update (WL02)         */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_UPC_RULES_200001_10] (
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

   DECLARE @c_UPC       NVARCHAR(30)
         , @c_Storerkey NVARCHAR(15)
         , @c_Sku       NVARCHAR(20)
         , @c_Packkey   NVARCHAR(10)
         , @c_UOM       NVARCHAR(10)
         , @n_RowRefNo  INT
         , @c_ttlMsg    NVARCHAR(250)
         , @n_Qty       INT;   --WL01

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

      BEGIN TRANSACTION;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , RTRIM(UPC)
           , RTRIM(StorerKey)
           , RTRIM(Sku)
           , RTRIM(PackKey)
           , RTRIM(UOM)
           , ISNULL(Qty, 0)   --WL01
      FROM dbo.SCE_DL_UPC_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_UPC
         , @c_Storerkey
         , @c_Sku
         , @c_Packkey
         , @c_UOM
         , @n_Qty;   --WL01

      WHILE @@FETCH_STATUS = 0
      BEGIN
         --WL02 S
         IF EXISTS (SELECT 1
                    FROM dbo.UPC U (NOLOCK)
                    WHERE U.StorerKey = @c_Storerkey
                    AND U.UPC = @c_UPC
                    AND U.SKU = @c_Sku)
         BEGIN
            IF @c_InParm2 = 1   --Allow update
            BEGIN
               UPDATE U WITH (ROWLOCK)
               SET U.PackKey  = CASE WHEN ISNULL(TRIM(STG.Packkey),'') = ''   THEN U.Packkey ELSE ISNULL(TRIM(STG.Packkey),'')   END
                 , U.UOM      = CASE WHEN ISNULL(TRIM(STG.UOM),'') = ''       THEN U.UOM     ELSE ISNULL(TRIM(STG.UOM),'')       END
                 , U.QTY      = CASE WHEN STG.Qty IS NULL THEN U.Qty ELSE STG.Qty END
               FROM UPC U
               JOIN dbo.SCE_DL_UPC_STG STG WITH (NOLOCK) ON STG.Storerkey = U.StorerKey
                                                        AND STG.UPC = U.UPC
                                                        AND STG.SKU = U.SKU
               WHERE STG.RowRefNo = @n_RowRefNo

            END
            ELSE
            BEGIN
               UPDATE dbo.SCE_DL_SERIALNO_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = '/Error: UPC ' + TRIM(@c_UPC) + ' is existed.'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status  = '1'
               AND   RowRefNo    = @n_RowRefNo
            END
         END
         ELSE
         BEGIN
            INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM, Qty)   --WL01
            VALUES
            (
               @c_UPC
             , @c_Storerkey
             , @c_Sku
             , @c_Packkey
             , @c_UOM
             , @n_Qty   --WL01
            );

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
         END
         --WL02 E

         UPDATE dbo.SCE_DL_UPC_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         FETCH NEXT FROM C_HDR
         INTO @n_RowRefNo
            , @c_UPC
            , @c_Storerkey
            , @c_Sku
            , @c_Packkey
            , @c_UOM
            , @n_Qty;   --WL01
      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_UPC_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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