SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10         */
/* Creation Date: 22-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20803 Perform insert into BTB_FTA target table          */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 22-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/* 13-Jun-2023  WLChooi   1.1   WMS-20803 - Add ISNULL Checking (WL01)  */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10] (
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

   DECLARE @n_RowRefNo     INT
         , @c_ttlMsg       NVARCHAR(250)
         , @c_FormNo       NVARCHAR(40)
         , @c_FormType     NVARCHAR(10)
         , @c_COO          NVARCHAR(20)
         , @dt_IssuedDate  DATETIME
         , @c_HSCode       NVARCHAR(20)
         , @c_Storerkey    NVARCHAR(15)
         , @c_SKU          NVARCHAR(20)
         , @n_QtyImported  INT
         , @n_QtyExported  INT
         , @c_BTBShipItem  NVARCHAR(50)
         , @c_CustomLotNo  NVARCHAR(20)
         , @c_Authority    NVARCHAR(30)
         , @c_Option1      NVARCHAR(50)
         , @c_Option2      NVARCHAR(50)
         , @c_Option3      NVARCHAR(50)
         , @c_Option4      NVARCHAR(50)
         , @c_Option5      NVARCHAR(4000)
         , @c_AllowSKU     NVARCHAR(50)
         , @c_BTBFTAKey    NVARCHAR(10)

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

   IF @c_InParm1 = '1'
   BEGIN
      BEGIN TRANSACTION

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , ISNULL(TRIM(FormNo),'')
           , ISNULL(TRIM(FormType),'')
           , ISNULL(TRIM(COO),'')
           , ISNULL(IssuedDate,'1900-01-01')
           , ISNULL(TRIM(HSCode),'')
           , ISNULL(TRIM(Storerkey),'')
           , ISNULL(TRIM(SKU),'')
           , ISNULL(QtyImported,0)
           , ISNULL(QtyExported,0)
           , ISNULL(TRIM(BTBShipItem),'')
           , ISNULL(TRIM(CustomLotNo),'')
      FROM dbo.SCE_DL_BTB_FTA_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'

      OPEN C_HDR
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_FormNo     
         , @c_FormType   
         , @c_COO        
         , @dt_IssuedDate
         , @c_HSCode     
         , @c_Storerkey  
         , @c_SKU        
         , @n_QtyImported
         , @n_QtyExported
         , @c_BTBShipItem
         , @c_CustomLotNo

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_Authority  = N''
         SET @c_Option1    = N''
         SET @c_Option2    = N''
         SET @c_Option3    = N''
         SET @c_Option4    = N''
         SET @c_Option5    = N''
         SET @c_AllowSKU   = N'N'
         SET @c_BTBFTAKey  = N''
         SET @c_ttlMsg     = N''
         
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
         IF @n_ErrNo <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': EXEC nspGetRight fail. (isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10)'
            GOTO STEP_999_EXIT_SP
         END

         IF @c_FormNo = ''
            SET @c_ttlMsg += N'/Error: FormNo is empty.'
         ELSE IF @c_FormType = ''
            SET @c_ttlMsg += N'/Error: FormType is empty.'
         ELSE IF @c_COO = ''
            SET @c_ttlMsg += N'/Error: COO is empty.'
         ELSE IF CAST(@dt_IssuedDate AS NVARCHAR) = '1900-01-01'
            SET @c_ttlMsg += N'/Error: IssuedDate is NULL.'

         SELECT @c_AllowSKU = dbo.fnc_GetParamValueFromString('@c_AllowSKU', @c_Option5, @c_AllowSKU)

         IF ISNULL(@c_AllowSKU,'') = ''
            SET @c_AllowSKU = 'N'
         
         IF ISNULL(@c_Authority,'') = ''
            SET @c_Authority = '0'
         
         IF @c_Authority = '1'
         BEGIN
            IF @c_SKU <> '' AND @c_AllowSKU = 'N'
            BEGIN
               SET @c_ttlMsg += N'/Error: SKU is not required. Leave it empty.'
            END

            IF @c_BTBShipItem = ''
            BEGIN
               SET @c_ttlMsg += N'/Error: BTBShipItem is empty.'
            END
         END
         ELSE IF @c_Authority = '0'
         BEGIN
            IF @c_BTBShipItem <> ''
            BEGIN
               SET @c_ttlMsg += N'/Error: BTB Ship Item is not required. Leave it empty.'
            END

            IF @c_SKU = ''
            BEGIN
               SET @c_ttlMsg += N'/Error: SKU is empty.'
            END
         END

         --Check duplicate Form Type, FormNo, COO, HSCode, 
         --Storer's Sku, BTB Ship Item & Custom Lot No in STG
         IF EXISTS (SELECT 1
                    FROM dbo.SCE_DL_BTB_FTA_STG STG (NOLOCK)
                    WHERE STG.FormType   = @c_FormType
                    AND STG.FormNo       = @c_FormNo
                    AND STG.COO          = @c_COO
                    AND STG.HSCode       = @c_HSCode
                    AND STG.Storerkey    = @c_Storerkey
                    AND STG.SKU          = @c_SKU
                    AND STG.BTBShipItem  = @c_BTBShipItem
                    AND STG.CustomLotNo  = @c_CustomLotNo
                    AND STG.RowRefNo     <> @n_RowRefNo
                    AND STG.STG_BatchNo  = @n_BatchNo)
         BEGIN
            SET @c_ttlMsg += N'/Error: Duplicate Form Type, FormNo, COO, HSCode, ' +
                             N'Storer''s Sku, BTB Ship Item & Custom Lot # Found.'
         END

         IF EXISTS (SELECT 1
                    FROM dbo.BTB_FTA BF (NOLOCK)
                    WHERE BF.FormType   = @c_FormType
                    AND BF.FormNo       = @c_FormNo
                    AND BF.COO          = @c_COO
                    AND BF.HSCode       = @c_HSCode
                    AND BF.Storerkey    = @c_Storerkey
                    AND BF.SKU          = @c_SKU
                    AND BF.BTBShipItem  = @c_BTBShipItem
                    AND BF.CustomLotNo  = @c_CustomLotNo)
         BEGIN
            SET @c_ttlMsg += N'/Error: Duplicate Form Type, FormNo, COO, HSCode, ' +
                             N'Storer''s Sku, BTB Ship Item & Custom Lot # Found.'
         END

         SET @c_Authority  = N''
         
         EXEC dbo.nspGetRight @c_Facility = NULL                
                            , @c_StorerKey = @c_StorerKey                
                            , @c_sku = NULL                 
                            , @c_ConfigKey = N'FTAAllowQtyImpLTQtyExp'                
                            , @b_Success  = @b_Success OUTPUT    
                            , @c_Authority = @c_Authority OUTPUT
                            , @n_err = @n_ErrNo OUTPUT            
                            , @c_errmsg = @c_errmsg OUTPUT  

         IF @n_ErrNo <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': EXEC nspGetRight fail. (isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10)'
            GOTO STEP_999_EXIT_SP
         END

         IF @n_QtyExported > @n_QtyImported AND @c_Authority = ''
         BEGIN
            SET @c_ttlMsg += N'/Error: Exported Qty > Imported Qty '
         END
         
         IF @c_ttlMsg = ''
         BEGIN
            EXEC dbo.nspg_GetKey @KeyName = N'BTBFTAKey'                
                               , @fieldlength = 10              
                               , @keystring = @c_BTBFTAKey OUTPUT
                               , @b_Success = @b_Success OUTPUT
                               , @n_err = @n_ErrNo OUTPUT      
                               , @c_errmsg = @c_errmsg OUTPUT                
         

            IF @n_ErrNo <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 68003
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': EXEC nspg_GetKey fail. (isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10)'
               GOTO STEP_999_EXIT_SP
            END
         END
         ELSE
         BEGIN
            BEGIN TRANSACTION

            UPDATE dbo.SCE_DL_BTB_FTA_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status  = '1'
            AND   FormType    = @c_FormType
            AND   FormNo      = @c_FormNo
            AND   COO         = @c_COO
            AND   HSCode      = @c_HSCode
            AND   Storerkey   = @c_Storerkey
            AND   SKU         = @c_SKU
            AND   BTBShipItem = @c_BTBShipItem
            AND   CustomLotNo = @c_CustomLotNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 68004
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10)'
               ROLLBACK
               GOTO STEP_999_EXIT_SP
            END

            COMMIT TRANSACTION
         END

         IF @c_BTBFTAKey <> ''
         BEGIN
            BEGIN TRANSACTION

            INSERT INTO dbo.BTB_FTA (BTB_FTAKey, FormNo, FormType, CustomerCode, HSCode, COO, PermitNo, IssuedDate, Storerkey, Sku
                                   , SkuDescr, UOM, QtyImported, QtyExported, OriginCriterion, EnabledFlag, UserDefine01
                                   , UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, UserDefine07
                                   , UserDefine08, UserDefine09, UserDefine10, IssueCountry, IssueAuthority, BTBShipItem, CustomLotNo)
            SELECT @c_BTBFTAKey, FormNo, FormType, CustomerCode, HSCode, COO, PermitNo, IssuedDate, Storerkey, Sku
                 , SkuDescr, UOM, QtyImported, QtyExported, OriginCriterion, ISNULL(EnabledFlag,''), ISNULL(UserDefine01,'')   --WL01
                 , ISNULL(UserDefine02,''), ISNULL(UserDefine03,''), ISNULL(UserDefine04,''), ISNULL(UserDefine05,''), UserDefine06, UserDefine07   --WL01
                 , ISNULL(UserDefine08,''), ISNULL(UserDefine09,''), ISNULL(UserDefine10,'')   --WL01
                 , IssueCountry, IssueAuthority, ISNULL(BTBShipItem,''), ISNULL(CustomLotNo,'')   --WL01
            FROM dbo.SCE_DL_BTB_FTA_STG STG (NOLOCK)
            WHERE STG.RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END;
            
            UPDATE dbo.SCE_DL_BTB_FTA_STG WITH (ROWLOCK)
            SET STG_Status = '9'
            WHERE RowRefNo = @n_RowRefNo
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END

         FETCH NEXT FROM C_HDR
         INTO @n_RowRefNo
            , @c_FormNo     
            , @c_FormType   
            , @c_COO        
            , @dt_IssuedDate
            , @c_HSCode     
            , @c_Storerkey  
            , @c_SKU        
            , @n_QtyImported
            , @n_QtyExported
            , @c_BTBShipItem
            , @c_CustomLotNo
      END

      CLOSE C_HDR
      DEALLOCATE C_HDR

      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_BTB_FTA_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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