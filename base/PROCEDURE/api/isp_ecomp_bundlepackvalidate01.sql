SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_BundlePackValidate01]              */              
/* Creation Date: 4-Sep-2024                                            */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: For GentleMonster/Tamburins Bundle Packing Validation       */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes	                                    */
/* 9-Jul-2024     Alex     #PAC-353                                     */
/************************************************************************/ 

CREATE   PROC [API].[isp_ECOMP_BundlePackValidate01]
   @b_Debug          INT            = 0
,  @c_PickSlipNo     NVARCHAR(10)
,  @n_CartonNo       INT
,  @c_OrderKey       NVARCHAR(10)
,  @c_Storerkey      NVARCHAR(15) 
,  @c_Sku            NVARCHAR(60)
,  @c_Type           NVARCHAR(15)   = ''
,  @b_Success        INT            OUTPUT  
,  @n_Err            INT            OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT                      ON  
   SET ANSI_NULLS                   OFF  
   SET QUOTED_IDENTIFIER            OFF  
   SET CONCAT_NULL_YIELDS_NULL      OFF  
  
   DECLARE @n_StartTCnt             INT                  = @@TRANCOUNT  
         , @n_Continue              INT                  = 1      
         , @c_PDSKU                 NVARCHAR(20)         = ''
         , @c_CurrBundleName        NVARCHAR(18)         = ''
         , @c_CurrOrderKey          NVARCHAR(10)         = ''
         , @c_CurrLineNumber        NVARCHAR(5)          = ''
         , @c_RootSKU               NVARCHAR(20)         = ''

         , @n_RefNo                 INT                  = 0 

         , @c_temp_OrderKey         NVARCHAR(10)         = ''
         , @c_temp_LineNumber       NVARCHAR(5)          = ''
         , @c_temp_SKU              NVARCHAR(20)         = ''
         , @n_temp_QTY              INT                  = 0

         , @n_NoneBundleQTYPacked   INT                  = 0 
         
         , @n_IsExists              INT                  = 0
         , @b_GenPDInfoRecord       INT                  = 0 
         , @b_UpdBundleX            INT                  = 0
         , @n_PackDetailInfoKey     BIGINT               = 0

         , @_LoopSKU                NVARCHAR(20)         = ''
         , @c_SKUBUSR5              NVARCHAR(30)         = ''

         , @c_PDI_SKU               NVARCHAR(20)         = ''
         , @c_PDI_UserDefine01      NVARCHAR(30)         = ''
         , @c_PDI_UserDefine02      NVARCHAR(30)         = ''
         , @c_PDI_UserDefine03      NVARCHAR(30)         = ''
         , @n_PDI_QTY               INT                  = 0
         , @n_QTYToPacked           INT                  = 0 
         , @n_QTYPacked             INT                  = 0
         , @c_POSMSKU               NVARCHAR(20)         = ''
         , @c_POSMPackedQTY         INT                  = 0 

         , @b_MBundleWithSamePOSM   BIT                  = 0
         , @b_IsScannedSKUisPOSM    BIT                  = 0
         , @n_CountBundle           INT                  = 0

   SET @n_Err                       = 0  
   SET @c_ErrMsg                    = ''  

   DECLARE @t_BundledItems As Table (
      StorerKey            NVARCHAR(15)      NULL,
      OrderKey             NVARCHAR(10)      NULL,
      OrderLineNumber      NVARCHAR(5)       NULL,
      UserDefine05         NVARCHAR(18)      NULL,    -- Bundle Name
      isSKUPOSM            BIT               NULL        DEFAULT (0),
      SKU                  NVARCHAR(20)      NULL,
      QTY                  INT               NULL,
      QTYPacked            INT               NULL        DEFAULT (0)
   )

   DECLARE @t_UnknownBundledItems As Table (
      StorerKey            NVARCHAR(15)      NULL,
      OrderKey             NVARCHAR(10)      NULL,
      OrderLineNumber      NVARCHAR(5)       NULL,
      UserDefine05         NVARCHAR(18)      NULL,    -- Bundle Name
      isSKUPOSM            BIT               NULL        DEFAULT (0),
      SKU                  NVARCHAR(20)      NULL,
      QTY                  INT               NULL,
      QTYPacked            INT               NULL        DEFAULT (0)
   )

   IF @b_Debug = 1
   BEGIN
      PRINT '>>> @c_OrderKey = ' + @c_OrderKey
   END

   IF @c_Type = 'VERIFYSKU'
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT * FROM [dbo].[PackTaskDetail] PTD WITH (NOLOCK) WHERE TaskBatchNo = ( SELECT TaskBatchNo FROM [dbo].[PackHeader] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo )
         AND EXISTS ( SELECT 1 FROM [dbo].[OrderDetail] OD WITH (NOLOCK) WHERE OD.OrderKey = PTD.OrderKey AND ISNULL(OD.UserDefine05, '') <> '' ) 
      END

      IF @c_OrderKey = '' 
      BEGIN
         IF EXISTS ( SELECT 1 FROM [dbo].[PackTaskDetail] PTD WITH (NOLOCK) WHERE TaskBatchNo = ( SELECT TaskBatchNo FROM [dbo].[PackHeader] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo )
            AND EXISTS ( SELECT 1 FROM [dbo].[OrderDetail] OD WITH (NOLOCK) WHERE OD.OrderKey = PTD.OrderKey AND ISNULL(OD.UserDefine05, '') <> '' ) )
         BEGIN
            SET @n_Continue   = 3 
            SET @n_Err        = 51250
            SET @c_ErrMsg     = 'Found bundle orders. Required to pack by order.'
            GOTO QUIT_SP
         END
      END
   END
   ELSE IF @c_Type = 'CHANGEORDER'
   BEGIN
      IF EXISTS ( SELECT 1 FROM [dbo].[PackTaskDetail] PTD WITH (NOLOCK) WHERE TaskBatchNo = ( SELECT TaskBatchNo FROM [dbo].[PackHeader] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo )
         AND EXISTS ( SELECT 1 FROM [dbo].[OrderDetail] OD WITH (NOLOCK) WHERE OD.OrderKey = PTD.OrderKey AND ISNULL(OD.UserDefine05, '') <> '' ) )
      BEGIN
         SET @n_Continue   = 3 
         SET @n_Err        = 51251
         SET @c_ErrMsg     = 'Not allowed to change order. The TaskBatchNo contains bundle orders.'
         GOTO QUIT_SP
      END
   END

   INSERT INTO @t_BundledItems (StorerKey, OrderKey, OrderLineNumber, UserDefine05, SKU, QTY) 
   SELECT 
      StorerKey, OrderKey, OrderLineNumber, ISNULL(RTRIM(UserDefine05), ''), SKU, QtyAllocated 
   FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
   
   --Skip validation if no bundle product.
   IF NOT EXISTS ( SELECT 1 FROM @t_BundledItems WHERE UserDefine05 <> '' )
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>> Order is single product.'
      END
      GOTO QUIT_SP
   END


   IF @b_Debug = 1
   BEGIN
      PRINT '-- Identify which SKU is POSM --'
   END

   --Identify which SKU is POSM.
   DECLARE CUR_FIND_SKUPOSM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT SKU, ISNULL(RTRIM(BUSR5), '') 
   FROM [dbo].[SKU] WITH (NOLOCK) 
   WHERE StorerKey = @c_Storerkey
   AND SKU IN ( SELECT DISTINCT SKU FROM @t_BundledItems WHERE UserDefine05 <> '' AND QTY > 0 )

   OPEN CUR_FIND_SKUPOSM  

   FETCH NEXT FROM CUR_FIND_SKUPOSM INTO @_LoopSKU, @c_SKUBUSR5
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      IF @c_SKUBUSR5 = 'POSM'
      BEGIN
         UPDATE @t_BundledItems
         SET isSKUPOSM = 1
         WHERE StorerKey = @c_Storerkey
         AND SKU = @_LoopSKU
         AND UserDefine05 <> ''
      END
      FETCH NEXT FROM CUR_FIND_SKUPOSM INTO @_LoopSKU, @c_SKUBUSR5
   END
   CLOSE CUR_FIND_SKUPOSM  
   DEALLOCATE CUR_FIND_SKUPOSM  

   IF @b_Debug = 1
   BEGIN
      PRINT '-- Update Packed QTY into temp table --'
   END

   --Update Packed QTY into temp table
   IF EXISTS ( SELECT 1 FROM [dbo].[PackDetailInfo] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo )
   BEGIN
      DECLARE CUR_UPD_QTYPacked CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT 
         SKU, UserDefine01, UserDefine02, UserDefine03, QTY
      FROM [dbo].[PackDetailInfo] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      OPEN CUR_UPD_QTYPacked  

      FETCH NEXT FROM CUR_UPD_QTYPacked INTO @c_PDI_SKU, @c_PDI_UserDefine01, @c_PDI_UserDefine02, @c_PDI_UserDefine03, @n_PDI_QTY
      WHILE @@FETCH_STATUS <> -1  
      BEGIN

         IF @c_PDI_UserDefine03 = 'UNKNOWN_BUNDLE'
         BEGIN
            SET @b_MBundleWithSamePOSM = 1
            --SET @n_QTYPacked = @n_PDI_QTY

            INSERT INTO @t_UnknownBundledItems (StorerKey, OrderKey, OrderLineNumber, UserDefine05, SKU, QTYPacked, isSKUPOSM) 
            VALUES ( @c_StorerKey, @c_PDI_UserDefine01, @c_PDI_UserDefine02, @c_PDI_UserDefine03, @c_PDI_SKU, @n_PDI_QTY, 1)
         END
         ELSE
         BEGIN
            UPDATE @t_BundledItems
            SET QTYPacked = @n_PDI_QTY
            WHERE OrderKey = @c_PDI_UserDefine01
            AND OrderLineNumber = @c_PDI_UserDefine02
            AND UserDefine05 = @c_PDI_UserDefine03
            AND SKU = @c_PDI_SKU
         END

         FETCH NEXT FROM CUR_UPD_QTYPacked INTO @c_PDI_SKU, @c_PDI_UserDefine01, @c_PDI_UserDefine02, @c_PDI_UserDefine03, @n_PDI_QTY
      END
      CLOSE CUR_UPD_QTYPacked  
      DEALLOCATE CUR_UPD_QTYPacked  
   END

   IF @c_Type = 'VERIFYSKU'
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '-- Checked if single product has been packed --'
      END

      -- if single product has been packed (single item always be packed first before packing bundled products)
      IF EXISTS (SELECT 1 FROM @t_BundledItems WHERE SKU <> @c_SKU AND UserDefine05 = '' AND [Qty] > [QTYPacked] )
      BEGIN
         SET @n_Continue   = 3 
         SET @n_Err        = 51252
         SET @c_ErrMsg     = 'Single product is not completed yet.'
         GOTO QUIT_SP
      END

      -- If Scanned SKU is Single Product, Insert PackDetailInfo
      SELECT @n_IsExists = (1)
            ,@c_CurrBundleName = UserDefine05
            ,@c_CurrOrderKey   = OrderKey
            ,@c_CurrLineNumber = OrderLineNumber
      FROM @t_BundledItems
      WHERE SKU = @c_SKU AND UserDefine05 = '' AND [Qty] > [QTYPacked]

      IF @b_Debug = 1
      BEGIN
         PRINT '-- Verified SKU is single product --'
         IF @n_IsExists = 1 PRINT '>>> This is single product..'
         ELSE PRINT '>>> This is NOT single product..'
      END

      IF @n_IsExists = 1
      BEGIN
         SET @b_GenPDInfoRecord = 1
         GOTO INSERT_UPDATE_PACKDETAILINFO
      END

      SELECT @b_IsScannedSKUisPOSM = (1) 
      FROM @t_BundledItems 
      WHERE UserDefine05 <> '' 
      AND isSKUPOSM = 1 
      AND SKU = @c_SKU

      --if any bundle item is pack in progress.
      SELECT @n_IsExists = (1) 
            ,@c_CurrBundleName = UserDefine05
      FROM @t_BundledItems 
      WHERE UserDefine05 IN ( SELECT UserDefine05 FROM @t_BundledItems WHERE UserDefine05 <> '' AND isSKUPOSM = 1 AND QTYPacked = QTY )
      AND IsSKUPOSM = 0
      AND QTYPacked < QTY

      IF @b_Debug = 1
      BEGIN
         PRINT '-- Check if any bundle item is pack in progress --'
         IF @n_IsExists = 1 PRINT '>>> There is pending bundle..'
         ELSE PRINT '>>> There is NO pending bundle..'
      END

      --If there is pending bundle
      IF @n_IsExists = 1 AND @c_CurrBundleName <> ''
      BEGIN
         SELECT @n_IsExists = (1) 
               ,@n_QTYToPacked = QTY
               ,@n_QTYPacked = QTYPacked
         FROM @t_BundledItems 
         WHERE UserDefine05 = @c_CurrBundleName
         AND SKU = @c_SKU

         --if scanned SKU is NOT belong to the bundle.
         IF @n_IsExists = 0
         BEGIN
            SET @n_Continue   = 3 
            SET @n_Err        = 51253
            SET @c_ErrMsg     = 'Different bundle. Please check.'
            GOTO QUIT_SP
         END
         --prompt error if over pack for scanned sku
         ELSE IF @n_QTYPacked >= @n_QTYToPacked AND @n_QTYPacked > 0
         BEGIN
            SET @n_Continue   = 3 
            SET @n_Err        = 51254
            SET @c_ErrMsg     = 'SKU(' + @c_SKU + ') over packed. Please check.'
            GOTO QUIT_SP
         END
         ELSE IF @n_QTYPacked < @n_QTYToPacked 
         BEGIN
            SELECT @c_CurrOrderKey   = OrderKey
                  ,@c_CurrLineNumber = OrderLineNumber
            FROM @t_BundledItems 
            WHERE UserDefine05 = @c_CurrBundleName
            AND SKU = @c_SKU

            IF @@ROWCOUNT = 0
            BEGIN
               SET @n_Continue   = 3 
               SET @n_Err        = 51255
               SET @c_ErrMsg     = 'Different bundle item. Please check.'
               GOTO QUIT_SP
            END

            SET @b_GenPDInfoRecord = 1
            GOTO INSERT_UPDATE_PACKDETAILINFO
         END
         
         IF NOT EXISTS ( SELECT 1 FROM @t_BundledItems WHERE UserDefine05 = @c_CurrBundleName AND SKU = @c_SKU AND QTYPacked < QTY)
         BEGIN
            SET @n_Continue   = 3 
            SET @n_Err        = 51256
            SET @c_ErrMsg     = 'Different bundle. Please check.'
            GOTO QUIT_SP
         END
         ELSE 
         BEGIN
            SELECT @n_IsExists = (1) 
                  ,@c_CurrOrderKey   = OrderKey
                  ,@c_CurrLineNumber = OrderLineNumber
            FROM @t_BundledItems 
            WHERE UserDefine05 = @c_CurrBundleName
            AND SKU = @c_SKU
            AND QTYPacked < QTY

            IF @@ROWCOUNT = 0
            BEGIN
               SET @n_Continue   = 3 
               SET @n_Err        = 51257
               SET @c_ErrMsg     = 'Different bundle item. Please check.'
               GOTO QUIT_SP
            END

            SET @b_GenPDInfoRecord = 1
            GOTO INSERT_UPDATE_PACKDETAILINFO
         END
      END
      --Else: No pending bundle
      ELSE
      BEGIN
         --if got multi bundle with same POSM
         IF EXISTS ( SELECT COUNT(1) FROM (SELECT DISTINCT UserDefine05 FROM @t_BundledItems WHERE SKU = @c_SKU AND IsSKUPOSM = 1 AND QTYPacked < QTY ) A HAVING COUNT(1) > 1) 
            AND @b_MBundleWithSamePOSM = 0
         BEGIN
            SET @c_CurrBundleName = 'UNKNOWN_BUNDLE'
            SET @c_CurrOrderKey = ''
            SET @c_CurrLineNumber = ''

            SET @b_GenPDInfoRecord = 1
            GOTO INSERT_UPDATE_PACKDETAILINFO
         END

         IF @b_MBundleWithSamePOSM = 1
         BEGIN
             IF @b_Debug = 1
             BEGIN
                PRINT '-- Multi Bundle with same POSM --'
                PRINT '>>> @b_MBundleWithSamePOSM = ' + CONVERT(NVARCHAR(1), @b_MBundleWithSamePOSM)
                PRINT '>>> @b_IsScannedSKUisPOSM = ' + CONVERT(NVARCHAR(1), @b_IsScannedSKUisPOSM)
             END

            -- if there is pending unknown bundle 
            IF EXISTS ( SELECT 1 FROM @t_UnknownBundledItems )
            BEGIN
               -- if Bundle POSM not pack finish yet.
               IF @b_IsScannedSKUisPOSM = 1
               BEGIN
                  SELECT @n_CountBundle = COUNT(1)
                  FROM @t_BundledItems 
                  WHERE SKU = @c_SKU 
                  AND IsSKUPOSM = 1 
                  AND QTY = (SELECT QTYPacked + 1 FROM @t_UnknownBundledItems WHERE isSKUPOSM = 1 AND SKU = @c_SKU )


                  IF @b_Debug = 1
                  BEGIN
                     PRINT '>>> @n_CountBundle = ' + CONVERT(NVARCHAR(2), @n_CountBundle)
                  END

                  -- if ONLY matched 1 bundle after increment of packed qty
                  IF @n_CountBundle = 1
                  BEGIN
                     SELECT @c_CurrBundleName = UserDefine05
                     FROM @t_BundledItems 
                     WHERE SKU = @c_SKU 
                     AND IsSKUPOSM = 1 
                     AND QTY = (SELECT QTYPacked + 1 FROM @t_UnknownBundledItems WHERE isSKUPOSM = 1 AND SKU = @c_SKU )

                     SET @b_GenPDInfoRecord = 1
                     SET @b_UpdBundleX = 1
                     GOTO UPDATE_UNKNOWN_BUNDLE
                  END
                  --If match more than 2 bundle, update POSM qty only.
                  ELSE
                  BEGIN
                     SET @c_CurrBundleName = 'UNKNOWN_BUNDLE'
                     SET @b_GenPDInfoRecord = 1
                     GOTO INSERT_UPDATE_PACKDETAILINFO
                  END
               END
               -- One Bundle POSM packed, operation scan bundle item
               ELSE
               BEGIN
                  --If scanned SKU is not POSM, need insert/update quantity after updated unknown bundle.
                  SELECT @n_IsExists = (1) 
                        ,@c_CurrBundleName = UserDefine05
                  FROM @t_BundledItems 
                  WHERE UserDefine05 IN ( 
                     SELECT DISTINCT b.UserDefine05 FROM @t_BundledItems b 
                     JOIN @t_UnknownBundledItems unk ON b.SKU = unk.SKU AND b.QTY = unk.QTYPacked 
                  )
                  AND IsSKUPOSM = 0
                  AND SKU = @c_SKU
                  AND QTYPacked < QTY

                  IF @n_IsExists = 1 AND @c_CurrBundleName <> ''
                  BEGIN

                     SET @b_GenPDInfoRecord = 1
                     SET @b_UpdBundleX = 1
                     GOTO UPDATE_UNKNOWN_BUNDLE
                  END
               END
            END
         END

         --Check if scanned SKU is POSM
         SELECT @n_IsExists = (1) 
               ,@c_CurrBundleName = UserDefine05
               ,@c_CurrOrderKey   = OrderKey
               ,@c_CurrLineNumber = OrderLineNumber
               --,@n_QTYPacked      = QTYPacked
         FROM @t_BundledItems 
         WHERE SKU = @c_SKU
         AND IsSKUPOSM = 1
         AND QTYPacked < QTY
         ORDER BY QTYPacked DESC

         IF @n_IsExists = 0
         BEGIN
            SET @n_Continue   = 3 
            SET @n_Err        = 51258
            SET @c_ErrMsg     = 'POSM not scanned.'
            GOTO QUIT_SP
         END

         SET @b_GenPDInfoRecord = 1
         GOTO INSERT_UPDATE_PACKDETAILINFO
      END

      UPDATE_UNKNOWN_BUNDLE:
      IF @b_UpdBundleX = 1 AND @c_CurrBundleName <> ''
      BEGIN
         SELECT @c_CurrOrderKey   = OrderKey
               ,@c_CurrLineNumber = OrderLineNumber
               --,@n_QTYPacked      = QTYPacked
         FROM @t_BundledItems
         WHERE UserDefine05 = @c_CurrBundleName
         AND IsSKUPOSM = 1

         SELECT @n_PackDetailInfoKey = PackDetailInfoKey
         FROM [dbo].[PackDetailInfo] WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo
         AND UserDefine01 = ''
         AND UserDefine02 = ''
         AND UserDefine03 = 'UNKNOWN_BUNDLE'

         --PRINT '>>> @n_PackDetailInfoKey = ' + CONVERT(NVARCHAR(2), @n_PackDetailInfoKey)
         IF @n_PackDetailInfoKey > 0
         BEGIN
            UPDATE dbo.PackDetailInfo WITH (ROWLOCK)
            SET UserDefine01 = @c_CurrOrderKey
              , UserDefine02 = @c_CurrLineNumber
              , UserDefine03 = @c_CurrBundleName
            WHERE PackDetailInfoKey = @n_PackDetailInfoKey
         END

         -- Scanned SKU
         IF @b_IsScannedSKUisPOSM = 0
         BEGIN
            SELECT @c_CurrOrderKey   = OrderKey
                  ,@c_CurrLineNumber = OrderLineNumber
            FROM @t_BundledItems 
            WHERE UserDefine05 = @c_CurrBundleName
            AND SKU = @c_SKU
            AND QTYPacked < QTY
            ORDER BY QTYPacked DESC
         END
      END

      INSERT_UPDATE_PACKDETAILINFO:
      IF @b_GenPDInfoRecord = 1
      BEGIN
         SET @n_IsExists = 0 
         SELECT @n_IsExists = (1)
               ,@n_PackDetailInfoKey = PackDetailInfoKey
         FROM [dbo].[PackDetailInfo] WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo
         AND SKU = @c_SKU
         AND UserDefine01 = @c_CurrOrderKey
         AND UserDefine02 = @c_CurrLineNumber
         AND UserDefine03 = @c_CurrBundleName

         IF @b_Debug = 1
         BEGIN
            PRINT '------- Generate PACKDETAILINFO -------'
            PRINT '@n_IsExists = ' + CONVERT(NVARCHAR(1), @n_IsExists)
            PRINT '@c_CurrOrderKey = ' + @c_CurrOrderKey
            PRINT '@c_CurrLineNumber = ' + @c_CurrLineNumber
            PRINT '@c_CurrBundleName = ' + @c_CurrBundleName
         END

         IF @n_IsExists = 0
         BEGIN
            INSERT INTO [dbo].[PackDetailInfo] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, UserDefine01, UserDefine02, UserDefine03, QTY)
            VALUES (@c_PickSlipNo, @n_CartonNo, '', '', @c_StorerKey, @c_SKU, @c_currOrderKey, @c_currLineNumber, @c_CurrBundleName, 1)
         END
         ELSE
         BEGIN
            UPDATE [dbo].[PackDetailInfo] WITH (ROWLOCK)
            SET [Qty] = [Qty] + 1
            WHERE PackDetailInfoKey = @n_PackDetailInfoKey
         END
      END
   END
   ELSE IF @c_Type = 'CLOSECARTON'
   BEGIN
      IF EXISTS ( SELECT 1 FROM @t_UnknownBundledItems )
      OR EXISTS ( SELECT 1 FROM @t_BundledItems WHERE UserDefine05 <> '' AND isSKUPOSM = 1 AND QTYPacked < QTY AND QTYPacked > 1) -- If POSM SKU is packing in progress
      OR EXISTS ( SELECT 1 FROM @t_BundledItems WHERE UserDefine05 IN ( SELECT UserDefine05 FROM @t_BundledItems WHERE UserDefine05 <> '' AND isSKUPOSM = 1 AND QTYPacked = QTY )
         AND IsSKUPOSM = 0 AND QTYPacked < QTY )
      BEGIN
         SET @n_Continue   = 3 
         SET @n_Err        = 51259
         SET @c_ErrMsg     = 'There is a bundle packing in progress. Please Check.'
         GOTO QUIT_SP
      END
   END

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM @t_BundledItems
   END

QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_BundlePackValidate01'  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure  
GO