SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*******************************************************************************/
/* Store procedure: isp_GetPicklsipNo                                          */
/* Copyright      : LFLogistics                                                */
/*                                                                             */
/* Date         Rev  Author     Purposes                                       */
/* 2020-04-20   1.0  Chermaine  Created                                        */
/* 2021-03-22   1.1  Chermaine  TPS-566 remove closed pickslip checking (cc01) */
/* 2021-08-28   1.2  Chermaine  TPS-575 Add storer and facility checking       */
/*                              AND exclude Ecom sostatus by codelkup (cc02)   */
/* 2021-09-05   1.3  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc03)             */
/* 2022-06-24   1.4  YeeKung    TPS-646 remove status (yeekung01)              */
/* 2022-07-19   1.5  YeeKung    TPS-648 Add UCC (yeekung02)                    */
/* 2023-03-14   1.6  YeeKung    TPS-681 remove UCC (yeekung02)                 */
/* 2023-04-11   1.7  YeeKung    TPS-665 Fix group by (yekeung03)               */
/* 2024-02-23   1.8  YeeKung    TPS-876 Support Orderkey as scanno (yeekung04) */
/* 2024-10-06   1.9  YeeKung    TPS-910 Support ToteNO <9 (yeekung05)          */
/* 2024-12-31   2.0  YeeKung    UWP-28420 Fix tote status 5 (yeekung06)        */
/* 2025-02-14   2.1  yeekung    TPS-995 Change Error Message (yeekung03)       */
/* 2025-02-15   2.2  YeeKung    TPS-956 Add Status (yeekung04)                 */
/*******************************************************************************/

CREATE   PROC [API].[isp_GetPicklsipNo] (
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cScanNo       NVARCHAR( 30),
   @cType         NVARCHAR( 30),
   @cUserName      NVARCHAR( 30),
   @jResult       NVARCHAR( MAX) OUTPUT,
   @b_Success     INT = 1  OUTPUT,
   @n_Err         INT = 0  OUTPUT,
   @c_ErrMsg      NVARCHAR( 255) = ''  OUTPUT,
   @cSelectAll    NVARCHAR( 1) = '0'

)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cScanNoType   NVARCHAR( 30),
      @cPickSlipNo   NVARCHAR( 30),
      @cDropID       NVARCHAR( 30),
      @cOrderKey     NVARCHAR( 10),
      @cLoadKey      NVARCHAR( 10),
      @cZone         NVARCHAR( 18),
      @cLot          NVARCHAR( 30),
      @EcomSingle    NVARCHAR( 1),
      @CalOrderSKU   NVARCHAR( 1),
      @b2bProcess    NVARCHAR( 1),
      @cSQL          NVARCHAR( MAX),
      @nExists       INT,

      @cEcomPickslipSP     NVARCHAR( 30),
      @pickSkuDetailJson   NVARCHAR( MAX),
      @cDynamicRightName1  NVARCHAR( 30),
      @cDynamicRightValue1 NVARCHAR( 30)

   SET @EcomSingle = '0'
   SET @CalOrderSKU = 'N'
   SET @b2bProcess = '1'

   --DECLARE @pickSKUDetail TABLE (
   Declare @pickSKUDetail TABLE(
       SKU              NVARCHAR( 30),
       QtyToPack        INT,
       OrderKey         NVARCHAR( 30),
       PickslipNo       NVARCHAR( 30),
       LoadKey          NVARCHAR( 30),--externalOrderKey
       PickDetailStatus NVARCHAR ( 3)
   )

   --(cc02)
   Declare @tSostatusList TABLE(
       Code             NVARCHAR( 30)
   )

   IF EXISTS (SELECT TOP 1 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'NONEPACKSO' AND Storerkey = @cStorerKey)
   BEGIN
      INSERT INTO @tSostatusList (code)
      SELECT code FROM CODELKUP (NOLOCK) WHERE Listname = 'NONEPACKSO' AND Storerkey = @cStorerKey
   END
   ELSE
   BEGIN
      INSERT INTO @tSostatusList (code)
      VALUES ('CANC'),('PENCANC')
   END

   IF @cType = 'pickslip'
   BEGIN
      SET @cPickSlipNo = @cScanNo


      IF SUBSTRING(@cPickSlipNo,1,1) ='P'
      BEGIN

         -- Get PickHeader info
         SELECT TOP 1
            @cOrderKey = OrderKey,
            @cLoadKey = ExternOrderKey,
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         IF @@ROWCOUNT = 0
         BEGIN
            SET @b_Success = 0
            SET @n_Err = 1001101
            SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Invalid Pickslip No. Please use other Pickslip No. Function : isp_GetPicklsipNo'
            GOTO EXIT_SP
         END

         --Discrete
         IF @cOrderKey <> ''
         BEGIN
            SET @cScanNoType = 'Discrete'

            IF (SELECT TOP 1 storerKey FROM ORDERS (NOLOCK) WHERE OrderKey =  @cOrderKey ) <> @cStorerKey
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 1001102
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Pickslip No is from a different Storrer. Please use valid Pickslip No. Function : isp_GetPicklsipNo'
               GOTO EXIT_SP
            END

            --(cc02)
            IF (SELECT TOP 1 facility FROM ORDERS (NOLOCK) WHERE OrderKey =  @cOrderKey ) <> @cFacility
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 1001103
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Pickslip No is from a different Facility. Please use valid Pickslip No. Function : isp_GetPicklsipNo'
               GOTO EXIT_SP
            END

            INSERT INTO @pickSKUDetail
            SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,@cPickslipNo,@cLoadKey,PD.Status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.Status
            FROM pickDetail PD WITH (NOLOCK)
            LEFT JOIN orders O WITH (NOLOCK) ON (PD.orderKey = O.OrderKey) --(cc02)
            --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status <= '5'
              -- AND PD.Status NOT IN  ('4')
               AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList)  --(cc02)
            GROUP BY PD.SKU,PD.OrderKey,PD.Status--,UCC.UCCNo--,PD.Status (yeekung)

            SET @cDynamicRightName1 = 'OrderKey'
            SET @cDynamicRightValue1 = @cOrderKey
         END
         --conso
         ELSE IF @cLoadKey <> ''
         BEGIN
            SET @cScanNoType = 'Conso'

            IF (SELECT TOP 1 storerKey FROM ORDERS (NOLOCK) WHERE loadKey = @cLoadKey ) <> @cStorerKey
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 1001104
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Pickslip No is from a different Storrer. Please use valid Pickslip No. Function : isp_GetPicklsipNo'
               GOTO EXIT_SP
            END

            --(cc02)
            IF (SELECT TOP 1 facility FROM ORDERS (NOLOCK) WHERE loadKey = @cLoadKey ) <> @cFacility
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 1001105
               SET @c_ErrMsg =API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Pickslip No is from a different Facility. Please use valid Pickslip No. Function : isp_GetPicklsipNo'
               GOTO EXIT_SP
            END

            INSERT INTO @pickSKUDetail
            SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,'',@cPickslipNo,@cLoadKey,PD.Status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.Status
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status <= '5'
               --AND PD.Status NOT IN  ('4')
              -- AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList)  --(cc02)
            GROUP BY PD.SKU,PD.Status --(yeekung03)

            SET @cDynamicRightName1 = 'LoadKey'
            SET @cDynamicRightValue1 = @cLoadKey
         END
         ELSE
         BEGIN
            SET @cScanNoType = 'Custom'

            INSERT INTO @pickSKUDetail
            SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,@cPickslipNo,@cLoadKey,PD.Status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.Status
            FROM dbo.PickDetail PD WITH (NOLOCK)
              --    LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Status <= '5'
             --  AND PD.Status NOT IN  ('4')
            GROUP BY PD.SKU,PD.OrderKey,PD.Status--,UCC.UCCNo--,PD.Status

            SET @cDynamicRightName1 = 'OrderKey'
            SET @cDynamicRightValue1 = @cOrderKey
         END

    END
      ELSE
      BEGIN
         SET @cOrderKey = @cScanNo

         SELECT @cPickslipNo = Pickheaderkey
         FROM PickHeader (nolock)
         WHERE Orderkey = @cOrderKey

         INSERT INTO @pickSKUDetail
         SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,@cPickslipNo,@cLoadKey,PD.status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.Status
         FROM pickDetail PD WITH (NOLOCK)
         LEFT JOIN orders O WITH (NOLOCK) ON (PD.orderKey = O.OrderKey) --(cc02)
         --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status <= '5'
          --  AND PD.Status NOT IN  ('4')
            AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList)  --(cc02)
         GROUP BY PD.SKU,PD.OrderKey,PD.Status--,UCC.UCCNo--,PD.Status (yeekung)

         SET @cDynamicRightName1 = 'OrderKey'
         SET @cDynamicRightValue1 = @cOrderKey
      END
   END

   --type: toteID: (dropID)
   IF @cType = 'toteID'
   BEGIN
      SET @cDropID = @cScanNo
      SET @cOrderKey = ''
      SET @cPickSlipNo = ''

      IF EXISTS ( SELECT 1 
                  FROM ORDERS (NOLOCK)
                  Where Orderkey = @cScanNo
                  AND Storerkey = @cStorerKey)
      BEGIN
         SET @cOrderKey = @cScanNo

         SELECT @cPickslipNo = Pickheaderkey
         FROM PickHeader (nolock)
         WHERE Orderkey = @cOrderKey

         INSERT INTO @pickSKUDetail
         SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,@cPickslipNo,@cLoadKey,PD.status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.Status
         FROM pickDetail PD WITH (NOLOCK)
         LEFT JOIN orders O WITH (NOLOCK) ON (PD.orderKey = O.OrderKey) --(cc02)
         --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status <= '5'
          --  AND PD.Status NOT IN  ('4')
            AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList)  --(cc02)
         GROUP BY PD.SKU,PD.OrderKey,PD.Status--,UCC.UCCNo--,PD.Status (yeekung)

         SET @cDynamicRightName1 = 'OrderKey'
         SET @cDynamicRightValue1 = @cOrderKey
      END
      ELSE
      BEGIN

         SELECT @cEcomPickslipSP = svalue FROM storerConfig (NOLOCK) WHERE storerKey = @cStorerKey AND configKey ='TPS-GetEcomPickslip'

         --1. check config
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cEcomPickslipSP AND type = 'P')
         BEGIN
            --SELECT '1. config'
            SET @cSQL = 'EXEC [API].' +@cEcomPickslipSP+ ' @cStorerKey=@cStorerKey, @cFacility=@cFacility, @nFunc=@nFunc, @cLangCode=@cLangCode, @cScanNo=@cDropID, @cType = @cType, @cUserName = @cUserName, @jResult = @jResult OUTPUT, @b_Success = @b_Success OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT, @cSelectAll = @cSelectAll'

            EXEC sp_executesql @cSQL
               ,N'@cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @nFunc NVARCHAR(5), @cLangCode NVARCHAR(3), @cDropID NVARCHAR( 50), @cType NVARCHAR(30), @cUserName NVARCHAR(128), @jResult NVARCHAR(MAX) OUTPUT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT, @cSelectAll NVARCHAR( 1)'
               ,@cStorerKey
               ,@cFacility
               ,@nFunc
               ,@cLangCode
               ,@cDropID
               ,@cType
               ,@cUserName
               ,@jResult        OUTPUT
               ,@b_Success      OUTPUT
               ,@n_Err          OUTPUT
               ,@c_ErrMsg       OUTPUT
               ,@cSelectAll

            IF @n_Err > 0
               BEGIN
                  SET @b_Success = 0
                  SET @n_Err = @n_Err
                  SET @c_ErrMsg = @c_ErrMsg
                  GOTO EXIT_SP
               END

               SET @b2bProcess = '0'

               --Decode Json Format
               SELECT @cScanNoType = ScanNoType, @EcomSingle = EcomSingle,@pickSkuDetailJson = PickSkuDetail
               FROM OPENJSON(@jResult)
               WITH (
                     ScanNoType        NVARCHAR( 30),
                     EcomSingle        NVARCHAR( 1),
                     PickSkuDetail     NVARCHAR( MAX) as json
               )
               --SELECT @cScanNoType as ScanNoType,  @EcomSingle as EcomSingle

               INSERT INTO @pickSKUDetail
               SELECT *
               FROM OPENJSON(@pickSkuDetailJson)
               WITH (
                     SKU               NVARCHAR( 20)  '$.SKU',
                     QtyToPack         INT            '$.QtyToPack',
                     OrderKey          NVARCHAR( 10)  '$.OrderKey',
                     PickslipNo        NVARCHAR( 30)  '$.PickslipNo',
                     LoadKey           NVARCHAR( 10)  '$.LoadKey',
                     PickDetailStatus  NVARCHAR( 1)   '$.PickDetailStatus'--,
                    -- UCCNo             NVARCHAR( 20)  '$.UCCNo'
               )

              SELECT TOP 1 @cPickSlipNo = PickslipNo, @cOrderKey = orderKey, @cLoadKey = loadKey FROM @pickSKUDetail
         END
         --2. check ecom_single_flag need to be hav 'S','M'
         ELSE IF EXISTS (SELECT TOP 1 1 FROM pickDetail PD WITH (NOLOCK)
                  JOIN ORDERS O WITH (NOLOCK)
                  ON PD.orderkey = O.orderKey
                  AND PD.storerKey = O.StorerKey
                  WHERE PD.dropID = @cDropID
                  AND PD.StorerKey = @cStorerKey
                  AND ecom_single_flag  IN ('S','M'))
         BEGIN
            --SELECT '2. ecom_flag'
            --Mix 'S' n 'M'
            IF (SELECT COUNT(DISTINCT O.ecom_single_flag)
                       FROM pickDetail PD WITH (NOLOCK)
                       JOIN ORDERS O WITH (NOLOCK)
                       ON PD.orderkey = O.orderKey
                       AND PD.storerKey = O.StorerKey
                       WHERE PD.dropID = @cDropID
                       AND PD.StorerKey = @cStorerKey) > 1
            BEGIN
               --SELECT 'mixed S n M'
               SET @EcomSingle = '0'
            END
            ELSE
            BEGIN
               -- all 'M'
               IF (SELECT DISTINCT O.ecom_single_flag
                  FROM pickDetail PD WITH (NOLOCK)
                  JOIN ORDERS O WITH (NOLOCK)
                  ON PD.orderkey = O.orderKey
                  AND PD.storerKey = O.StorerKey
                  WHERE PD.dropID = @cDropID
                  AND PD.StorerKey = @cStorerKey) = 'M'
               BEGIN
                  --SELECT 'All M'
                  SET @EcomSingle = '0'
               END

               -- all 'M'
               IF (SELECT DISTINCT O.ecom_single_flag
                  FROM pickDetail PD WITH (NOLOCK)
                  JOIN ORDERS O WITH (NOLOCK)
                  ON PD.orderkey = O.orderKey
                  AND PD.storerKey = O.StorerKey
                  WHERE PD.dropID = @cDropID
                  AND PD.StorerKey = @cStorerKey) = 'S'
               BEGIN
                  --SELECT 'All S'
                  SET @EcomSingle = '1'
               END
            END

            IF @EcomSingle = '1'
            BEGIN
               -- double check the qty to make sure is Ecom_single
               IF (SELECT COUNT(DISTINCT O.Orderkey)
                  FROM ORDERS O (NOLOCK)
                  JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
                  LEFT JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey  --AND PH.Status = '9'
                  LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PH.PickSlipNo = PKD.PickSlipNo
                        WHERE PD.DropID = @cDropID
                        AND ISNULL(PD.Dropid,'') <> ''
                        AND PD.Storerkey = @cStorerKey
                  AND PKD.Pickslipno IS NULL
                  GROUP BY O.Orderkey
                  HAVING COUNT(DISTINCT PD.Sku) > 1 OR SUM(PD.Qty) > 1) > 0
               BEGIN
                  --SELECT 'set to M'
                  SET @EcomSingle = '0'
               END
               ELSE
               BEGIN
                  --SELECT 'set to S'
                  SET @EcomSingle = '1'
               END
            END

            IF @cSelectAll = '1'
            BEGIN
               --SELECT 'select ALL'
               -- all order in tote (packed/unpacked)
               INSERT INTO @pickSKUDetail
               SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,PD.status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.status
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
                --     LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
               WHERE PD.dropID = @cDropID
                  AND ISNULL(PD.Dropid,'') <> ''
                  AND PD.Storerkey = @cStorerKey
                  AND PD.Status NOT IN  ('0','9')
                  --AND O.sostatus NOT IN ('CANC','PENCANC')
                  AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList)  --(cc02)
               GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,O.Priority,PD.Status--,UCC.UCCNO
               --HAVING SUM(PD.QTY) = 1
               ORDER BY O.Priority, PD.Orderkey,PD.Status--,UCC.UCCNo

               SELECT TOP 1 @cPickSlipNo = PickslipNo, @cOrderKey = orderKey, @cLoadKey = loadKey FROM @pickSKUDetail

            END
            ELSE
            BEGIN
               IF @EcomSingle = '1'
               BEGIN
                  --SELECT 'ecom_single insert'
                  -- havent pack (not in packDetail/packHeader) ecomSingle - 1 pickslip 1 order 1 sku
                  INSERT INTO @pickSKUDetail
                  SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,PD.status--,CASE WHEN ISNULL(UCC.UCCNo,'')='' THEN '' ELSE UCC.UCCNo END--,PD.status
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
                  LEFT JOIN PACKHEADER PKH (NOLOCK) ON O.Orderkey = PKH.Orderkey
                  LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PKH.PickSlipNo = PKD.PickSlipNo
                        --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
                  WHERE PD.dropID = @cDropID
                     AND ISNULL(PD.Dropid,'') <> ''
                     AND PD.Storerkey = @cStorerKey
                     AND PD.Status NOT IN  ('0','9')
                     --AND O.sostatus NOT IN ('CANC','PENCANC')
                     AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList) --cc02
                     AND PKD.Pickslipno IS NULL
                  GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,O.Priority,PD.Status--,UCC.UCCNO
                  HAVING SUM(PD.QTY) = 1
                  ORDER BY O.Priority, PD.Orderkey,PD.Status--,UCC.UCCNo

               END
               ELSE
               BEGIN
                  -- ecomMulti - discrete - 1 pickslip 1 order multi sku
                  --SELECT 'ecom_multi insert'
                  INSERT INTO @pickSKUDetail
                  SELECT PickD.SKU, PickD.QtyToPick, PickD.OrderKey, PickD.PickHeaderKey, PickD.ExternOrderKey, PickD.status--,''
                  FROM (
                      SELECT PD.SKU, SUM(PD.QTY) AS QtyToPick, PD.OrderKey, PH.PickHeaderKey, PH.ExternOrderKey,PD.Status
                      FROM dbo.PickDetail PD WITH (NOLOCK)
                      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
                      JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
                      --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
                      WHERE PD.dropID = @cDropID
                            AND ISNULL(PD.Dropid,'') <> ''
                            AND PD.Storerkey = @cStorerKey
                            AND PD.Status NOT IN  ('0', '9')
                            --AND O.sostatus NOT IN ('CANC','PENCANC')
                  AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList) --cc02
                      GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,PD.Status--,PD.status
                      ) PickD
                  LEFT JOIN (
                           SELECT PKD.PickSlipNo, PKD.StorerKey, PKD.SKU, SUM(PKD.Qty) AS QtyPacked
                           FROM dbo.PackDetail PKD WITH (NOLOCK)
                           JOIN dbo.PackHeader PKH WITH (NOLOCK) ON (PKD.pickslipNo = PKH.PickSlipNo)
                           WHERE PKD.Storerkey = @cStorerKey
                           AND PKH.status <> 9
                           GROUP BY PKD.PickSlipNo, PKD.StorerKey, PKD.SKU
                      ) PackD ON PickD.Pickheaderkey = PackD.PickSlipNo AND PickD.SKU = PackD.SKU
                  --WHERE QtyToPick <> ISNULL(QtyPacked, 0)
                  ORDER BY PickD.Orderkey

                  --SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,PD.status
                  --FROM dbo.PickDetail PD WITH (NOLOCK)
                  --JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
                  --JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
                  --LEFT JOIN PACKHEADER PKH (NOLOCK) ON O.Orderkey = PKH.Orderkey   AND PKH.status <> 9
                  --LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PKH.PickSlipNo = PKD.PickSlipNo AND PKD.SKU=PD.SKU
                  --WHERE PD.dropID = @cDropID
                  --   AND ISNULL(PD.Dropid,'') <> ''
                  --   AND PD.Storerkey = @cStorerKey
                  --   AND PD.Status NOT IN  ('0','4','9')
                  --   AND O.sostatus NOT IN ('CANC','PENCANC')
                  --   --AND PKH.status <> 9
                  --GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,PD.status,O.Priority
                  ----HAVING SUM(PD.QTY) = 1
                  --ORDER BY O.Priority, PD.Orderkey

                  SELECT TOP 1 @cPickSlipNo = PickslipNo, @cOrderKey = orderKey, @cLoadKey = loadKey FROM @pickSKUDetail

                  IF (SELECT COUNT(DISTINCT pickslipNo) FROM @pickSKUDetail) >1
                  BEGIN
                     SET @b_Success = 0
                     SET @n_Err = 1001107
                     SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Scanned ToteID is not valid to be reuse. Function : isp_GetPicklsipNo'
                     GOTO EXIT_SP
                  END

                  SELECT TOP 1 @cPickSlipNo= pickslipno FROM @pickSKUDetail

                  --IF EXISTS (SELECT TOP 1 * FROM packHeader WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND STATUS = 9)
                  --BEGIN
                    -- SET @b_Success = 0
                  --   SET @n_Err = 100902
                  --   SET @c_ErrMsg = 'Packing Document No has completed packing.Please enter valid Packing Document No.'
                  --   GOTO EXIT_SP
                  --END

               END
            END
         END
         ELSE
         -- 3. normal toteID pack process
         BEGIN
            SELECT '2. toteID normal'
            --order not yet packed
            SELECT TOP 1
               @cOrderKey = OrderKey
            FROM PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID
               AND Status <= '5'

            -- Check DropID valid
            IF @@ROWCOUNT = 0
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 1001108
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'ToteID is from a different Storrer. Please use valid ToteID. Function : isp_GetPicklsipNo'
               GOTO EXIT_SP
            END

            -- Auto retrieve PickSlipNo
            IF @cPickSlipNo = ''
            BEGIN
               -- Get discrete pick slip
               SET @cScanNoType = 'Discrete'

               IF (SELECT TOP 1 storerKey FROM ORDERS (NOLOCK) WHERE OrderKey =  @cOrderKey ) <> @cStorerKey
               BEGIN
                  SET @b_Success = 0
                  SET @n_Err = 1001109
                  SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'ToteID is from a different Storrer. Please use valid ToteID. Function : isp_GetPicklsipNo'
                  GOTO EXIT_SP
               END

               IF (SELECT TOP 1 facility FROM ORDERS (NOLOCK) WHERE OrderKey =  @cOrderKey ) <> @cFacility
               BEGIN
                  SET @b_Success = 0
                  SET @n_Err = 1001115
                  SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'ToteID is from a different Facility. Please use valid ToteID.: isp_GetPicklsipNo'
                  GOTO EXIT_SP
               END

               SELECT @cPickSlipNo = PickHeaderKey
               FROM PickHeader WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               --AND storerKey = @cStorerKey

               INSERT INTO @pickSKUDetail
               SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,PD.status--,UCC.UCCNo--,PD.status
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.orderKey = PH.OrderKey
                    -- LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
               WHERE PD.dropID = @cDropID
                  AND PD.Status <= '5'
                  --AND PD.Status NOT IN  ('4')
               GROUP BY PD.SKU,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,PD.Status--,UCC.UCCNo--,PD.status

               SET @cDynamicRightName1 = 'OrderKey'
               SET @cDynamicRightValue1 = @cOrderKey

               -- Get conso pick slip
               IF @cPickSlipNo = ''
               BEGIN
                  SET @cLoadKey = ''
                  SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                  IF @cLoadKey <> ''
                     SET @cScanNoType = 'Conso'

                     IF (SELECT TOP 1 storerKey FROM ORDERS (NOLOCK) WHERE loadKey =  @cLoadKey ) <> @cStorerKey
                     BEGIN
                        SET @b_Success = 0
                        SET @n_Err = 1001110
                        SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'ToteID is from a different Storrer. Please use valid Pickslip No. Function : isp_GetPicklsipNo'
                        GOTO EXIT_SP
                     END

                     SELECT @cPickSlipNo = PickHeaderKey
                     FROM PickHeader WITH (NOLOCK)
                     WHERE ExternOrderKey = @cLoadKey
                        AND OrderKey = ''

                     INSERT INTO @pickSKUDetail
                     SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,'',PH.PickHeaderKey,PH.ExternOrderKey,PD.status--,UCC.UCCNo--,PD.Status
                     FROM  dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                        JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (LPD.loadkey = PH.ExternOrderKey)
                      --  LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
                     WHERE PD.dropID = @cDropID
                        AND PD.Status <= '5'
                       -- AND PD.Status NOT IN  ('4')
                     GROUP BY PD.SKU,PH.PickHeaderKey,PH.ExternOrderKey,PD.OrderKey,PD.Status--,UCC.UCCNo--,PD.Status

                     SET @cDynamicRightName1 = 'LoadKey'
                     SET @cDynamicRightValue1 = @cLoadKey
               END

               -- Check PickHeader
               IF @cPickSlipNo = ''
               BEGIN
                  SET @n_Err = 1001111
                  SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to retrieve PickHeader detail. Function : isp_GetPickslipNo'
                  GOTO EXIT_SP
               END
            END

            -- Check blank
            IF @cPickSlipNo = ''
            BEGIN
               SET @n_Err = 1001112
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Packing Document No required. Please enter valid Packing Document No. Function : isp_GetPickslipNo'
               GOTO EXIT_SP
            END
            SELECT * FROM @pickSKUDetail
            --SELECT @cPickSlipNo AS pickslipNo

            IF (SELECT COUNT(DISTINCT pickslipNo)  FROM @pickSKUDetail WHERE pickDetailStatus < 5 )>1
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 1001113
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Scanned ToteID is not valid to be reuse. Function : isp_GetPickslipNo'
               GOTO EXIT_SP
            END

          --  IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
            --BEGIN
              -- SET @b_Success = 0
          --     SET @n_Err = 100807
          --     SET @c_ErrMsg = 'Packing Document No has completed packing. Please enter valid Packing Document No.'
          --     GOTO EXIT_SP
            --END

         END
         --SELECT * FROM @pickSKUDetail
      END
   END

   IF NOT EXISTS (SELECT TOP 1 1 FROM @pickSKUDetail where PickDetailStatus <>'4')
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 1001114
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Invalid Pickslip No. Please use other Pickslip No. Function : isp_GetPickslipNo'
      GOTO EXIT_SP
   END

   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @jResult =

   (SELECT @cScanNoType AS ScanNoType, @cPickSlipNo AS PickslipNo, @cDropID AS DropID, @cOrderKey AS OrderKey, @cLoadKey AS LoadKey, @cZone AS Zone, @EcomSingle AS EcomSingle
   , @cDynamicRightName1 AS DynamicRightName1, @cDynamicRightValue1 AS DynamicRightValue1,
   (SELECT * FROM @pickSKUDetail
   FOR JSON PATH , INCLUDE_NULL_VALUES) AS PickSkuDetail
   FOR JSON PATH , INCLUDE_NULL_VALUES)
   EXIT_SP:

   SET QUOTED_IDENTIFIER OFF

GO