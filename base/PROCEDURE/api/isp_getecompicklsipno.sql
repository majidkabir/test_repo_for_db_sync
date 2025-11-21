SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: isp_GetEcomPicklsipNo                                       */
/* Copyright      : LFLogistics                                                 */
/*                                                                              */
/* Date         Rev  Author     Purposes                                        */
/* 2020-04-20   1.0  Chermaine  Created                                         */
/* 2021-08-28   1.1  Chermaine  TPS-575 exclude Ecom sostatus by codelkup (cc01)*/
/* 2021-09-05   1.2  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc02)              */
/* 2022-06-24   1.3  YeeKung    TPS-646 remove status (yeekung01)               */
/* 2025-02-14   1.4  yeekung    TPS-995 Change Error Message (yeekung03)        */
/********************************************************************************/

CREATE   PROC [API].[isp_GetEcomPicklsipNo] (
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cScanNo       NVARCHAR( 30),
   @cType         NVARCHAR( 30),
   @cUserName     NVARCHAR( 30),
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
	--@cStorerKey    NVARCHAR( 15),
 --  @cFacility     NVARCHAR( 5),
 --  @nFunc         INT,
 --  @cLangCode     NVARCHAR( 3),
 --  @cScanNo       NVARCHAR( 30),
 --  @cType         NVARCHAR( 30),
 --  @userName      NVARCHAR( 30),

   @cScanNoType   NVARCHAR( 30),
   @cPickSlipNo   NVARCHAR( 30),
   @cDropID       NVARCHAR( 30),
   @cOrderKey     NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),
   @cZone         NVARCHAR( 18),
   @cLot          NVARCHAR( 30),
   @EcomSingle    NVARCHAR( 1),
   @CalOrderSKU   NVARCHAR( 1),
   @cDynamicRightName1  NVARCHAR( 30),
   @cDynamicRightValue1 NVARCHAR( 30)

SET @EcomSingle = '0'
SET @CalOrderSKU = 'N'

--DECLARE @pickSKUDetail TABLE (
Declare @pickSKUDetail TABLE(
    SKU              NVARCHAR( 30),
    QtyToPack        INT,
    OrderKey         NVARCHAR( 30),
    PickslipNo       NVARCHAR( 30),
    LoadKey          NVARCHAR( 30),--externalOrderKey
    PickDetailStatus NVARCHAR ( 3)
)



SET @cDropID = @cScanNo
SET @cOrderKey = ''
SET @cPickSlipNo = ''

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

IF NOT EXISTS (SELECT TOP 1 1 FROM pickDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND dropID = @cDropID)
BEGIN
	SET @b_Success = 0
   SET @n_Err = 1001106
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'ToteID is from a different Storrer. Please use valid ToteID.: isp_GetEcomPicklsipNo'
   GOTO EXIT_SP
END

---- all order must need to be 'S' or M'
--IF NOT EXISTS (SELECT TOP 1 1 FROM pickDetail PD WITH (NOLOCK)
--            JOIN ORDERS O WITH (NOLOCK)
--            ON PD.orderkey = O.orderKey
--            AND PD.storerKey = O.StorerKey
--            WHERE PD.dropID = @cDropID
--            AND PD.StorerKey = @cStorerKey
--            AND ecom_single_flag NOT IN ('S','M'))
--BEGIN
--   --Mix 'S' n 'M'
--   IF (SELECT COUNT(DISTINCT O.ecom_single_flag)
--              FROM pickDetail PD WITH (NOLOCK)
--              JOIN ORDERS O WITH (NOLOCK)
--              ON PD.orderkey = O.orderKey
--              AND PD.storerKey = O.StorerKey
--              WHERE PD.dropID = @cDropID
--              AND PD.StorerKey = @cStorerKey) > 1
--   BEGIN
--   	SET @EcomSingle = '0'
--   END
--   ELSE
--   BEGIN
--   	-- all 'M'
--   	IF (SELECT DISTINCT O.ecom_single_flag
--         FROM pickDetail PD WITH (NOLOCK)
--         JOIN ORDERS O WITH (NOLOCK)
--         ON PD.orderkey = O.orderKey
--         AND PD.storerKey = O.StorerKey
--         WHERE PD.dropID = @cDropID
--         AND PD.StorerKey = @cStorerKey) = 'M'
--      BEGIN
--      	SET @EcomSingle = '0'
--      END

--      -- all 'M'
--   	IF (SELECT DISTINCT O.ecom_single_flag
--         FROM pickDetail PD WITH (NOLOCK)
--         JOIN ORDERS O WITH (NOLOCK)
--         ON PD.orderkey = O.orderKey
--         AND PD.storerKey = O.StorerKey
--         WHERE PD.dropID = @cDropID
--         AND PD.StorerKey = @cStorerKey) = 'S'
--      BEGIN
--      	SET @EcomSingle = '1'
--      END
--   END
--END


--IF @EcomSingle = '1'
--BEGIN
	-- double check the qty to make sure is Ecom_single
	IF EXISTS (SELECT COUNT(DISTINCT O.Orderkey)
     FROM ORDERS O (NOLOCK)
     JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
     LEFT JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey  AND PH.Status = '9'
     LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PH.PickSlipNo = PKD.PickSlipNo
             WHERE PD.DropID = @cDropID
             AND PD.Storerkey =@cStorerKey
     AND PKD.Pickslipno IS NULL
     GROUP BY O.Orderkey
     HAVING COUNT(DISTINCT PD.Sku) > 1 OR SUM(PD.Qty) > 1) --> 0
	BEGIN
	   SET @EcomSingle = '0'
	END
	ELSE
	BEGIN
	   SET @EcomSingle = '1'
	END
--END

IF @cSelectAll = '1'
BEGIN
	-- all order in tote (packed/unpacked)
	INSERT INTO @pickSKUDetail
   SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,0--,PD.status
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
   JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PD.dropID = @cDropID
      AND ISNULL(PD.Dropid,'') <> ''
      AND PD.Storerkey = @cStorerKey
      AND PD.Status NOT IN  ('0','4')
      --AND O.sostatus NOT IN ('CANC','PENCANC')
      AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList) --cc01
   GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,O.Priority
   HAVING SUM(PD.QTY) = 1
   ORDER BY O.Priority, PD.Orderkey

END
ELSE
BEGIN
	IF @EcomSingle = '1'
	BEGIN
		-- havent pack (not in packDetail/packHeader) ecomSingle - 1 pickslip 1 order 1 sku
	   INSERT INTO @pickSKUDetail
      SELECT PD.SKU,SUM(PD.QTY) AS QtyToPick,PD.OrderKey,PH.PickHeaderKey,PH.ExternOrderKey,0--,PD.status
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
      LEFT JOIN PACKHEADER PKH (NOLOCK) ON O.Orderkey = PKH.Orderkey
      LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PKH.PickSlipNo = PKD.PickSlipNo
      WHERE PD.dropID = @cDropID
         AND ISNULL(PD.Dropid,'') <> ''
         AND PD.Storerkey = @cStorerKey
         AND PD.Status NOT IN  ('0','4','9')
         --AND O.sostatus NOT IN ('CANC','PENCANC')
         AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList) --cc01
         AND PKD.Pickslipno IS NULL
      GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,O.Priority
      --HAVING SUM(PD.QTY) = 1
      ORDER BY O.Priority, PD.Orderkey
	END
	ELSE
	BEGIN
		-- ecomMulti - discrete - 1 pickslip 1 order multi sku
		--INSERT INTO @pickSKUDetail
  --    SELECT PickD.SKU, PickD.QtyToPick, PickD.OrderKey, PickD.PickHeaderKey, PickD.ExternOrderKey, PickD.status
  --    FROM (
  --        SELECT PD.SKU, SUM(PD.QTY) AS QtyToPick, PD.OrderKey, PH.PickHeaderKey, PH.ExternOrderKey, PD.status
  --        FROM dbo.PickDetail PD WITH (NOLOCK)
  --        JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
  --        JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
  --        WHERE PD.dropID = @cDropID
  --              AND ISNULL(PD.Dropid,'') <> ''
  --              AND PD.Storerkey = @cStorerKey
  --              AND PD.Status NOT IN  ('0','4', '9')
  --              AND O.sostatus NOT IN ('CANC','PENCANC')
  --        GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey,PD.status
  --        ) PickD
  --    LEFT JOIN (
  --             SELECT PKD.PickSlipNo, PKD.StorerKey, PKD.SKU, SUM(PKD.Qty) AS QtyPacked
  --             FROM dbo.PackDetail PKD WITH (NOLOCK)
  --             JOIN dbo.PackHeader PKH WITH (NOLOCK) ON (PKD.pickslipNo = PKH.PickSlipNo)
  --             WHERE PKD.Storerkey = @cStorerKey
  --             AND PKH.status <> 9
  --             GROUP BY PKD.PickSlipNo, PKD.StorerKey, PKD.SKU
  --        ) PackD ON PickD.Pickheaderkey = PackD.PickSlipNo AND PickD.SKU = PackD.SKU
  --    --WHERE QtyToPick <> ISNULL(QtyPacked, 0)
  --    ORDER BY PickD.Orderkey


      SELECT TOP 1 @cOrderKey = PD.OrderKey, @cPickSlipNo = PH.PickHeaderKey
      FROM PICKDETAIL PD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      LEFT JOIN PICKHEADER PH (NOLOCK) ON PD.Orderkey = PH.Orderkey
      LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PH.Pickheaderkey = PKD.Pickslipno
      WHERE PD.DropID = @cDropID
      ORDER BY PD.Status, CASE WHEN PKD.Pickslipno IS NULL THEN 0 ELSE 1 END, PD.editdate DESC, PD.Orderkey DESC

      --INSERT INTO @pickSKUDetail
      --SELECT PD.SKU, SUM(PD.QTY) AS QtyToPick, PD.OrderKey, PH.PickHeaderKey, PH.ExternOrderKey, PD.status
      --FROM PICKDETAIL PD (NOLOCK)
      --JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      --LEFT JOIN PICKHEADER PH (NOLOCK) ON PD.Orderkey = PH.Orderkey
      --LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PH.Pickheaderkey = PKD.Pickslipno
      --WHERE PD.DropID = @cDropID
      --AND PD.Storerkey = @cStorerKey
      --AND PH.pickHeaderkey = @cPickSlipNo
      --AND PH.OrderKey = @cOrderKey
      --GROUP BY PD.SKU, PD.OrderKey, PH.PickHeaderKey, PH.ExternOrderKey, PD.status

      INSERT INTO @pickSKUDetail
      SELECT PickD.SKU, PickD.QtyToPick, PickD.OrderKey, PickD.PickHeaderKey, PickD.ExternOrderKey, 0
      FROM (
          SELECT PD.SKU, SUM(PD.QTY) AS QtyToPick, PD.OrderKey, PH.PickHeaderKey, PH.ExternOrderKey
          FROM dbo.PickDetail PD WITH (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
          JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
          WHERE PD.dropID = @cDropID
                AND ISNULL(PD.Dropid,'') <> ''
                AND PD.Storerkey = @cStorerKey
                AND PD.OrderKey = @cOrderKey
                AND PH.PickHeaderKey = @cPickSlipNo
                AND PD.Status NOT IN  ('0','4', '9')
                --AND O.sostatus NOT IN ('CANC','PENCANC')
                AND O.SOStatus NOT IN (SELECT code FROM @tSostatusList) --cc01
          GROUP BY PD.SKU,PD.Orderkey, PH.PickHeaderKey,PH.ExternOrderKey--,PD.status
          ) AS PickD
      LEFT JOIN (
               SELECT PKD.PickSlipNo, PKD.StorerKey, PKD.SKU, SUM(PKD.Qty) AS QtyPacked
               FROM dbo.PackDetail PKD WITH (NOLOCK)
               JOIN dbo.PackHeader PKH WITH (NOLOCK) ON (PKD.pickslipNo = PKH.PickSlipNo)
               WHERE PKD.Storerkey = @cStorerKey
               AND PKH.status <> 9
               AND PKH.OrderKey = @cOrderKey
               AND PKH.PickSlipNo = @cPickSlipNo
               GROUP BY PKD.PickSlipNo, PKD.StorerKey, PKD.SKU
          ) PackD ON PickD.Pickheaderkey = PackD.PickSlipNo AND PickD.SKU = PackD.SKU
      --WHERE QtyToPick <> ISNULL(QtyPacked, 0)
      ORDER BY PickD.Orderkey
	END


END

--SELECT * FROM @pickSKUDetail

--Ecom_multi onli can hav 1 pickslip per tote
IF (@EcomSingle = 0) AND ((SELECT COUNT(DISTINCT pickslipNo) FROM @pickSKUDetail) >1) AND @cSelectAll = '0'
BEGIN
	SET @b_Success = 0
   SET @n_Err = 1001052
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Scanned ToteID is not valid to be reuse. Function : isp_GetEcomPicklsipNo'
   GOTO EXIT_SP
END

IF @EcomSingle = '1'
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1 FROM @pickSKUDetail)
   BEGIN
	   SET @b_Success = 0
      SET @n_Err = 1001053
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Packing Document No has completed packing.Please enter valid Packing Document No. Function : isp_GetEcomPicklsipNo'
      GOTO EXIT_SP
   END
END
ELSE
BEGIN
   SELECT TOP 1 @cPickSlipNo= pickslipno FROM @pickSKUDetail

   IF EXISTS (SELECT TOP 1 * FROM packHeader WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND STATUS = 9)
   BEGIN
   	SET @b_Success = 0
      SET @n_Err = 1001054
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Packing Document No has completed packing.Please enter valid Packing Document No. Function : isp_GetEcomPicklsipNo'
      GOTO EXIT_SP
   END
END


IF @EcomSingle = '1'
BEGIN
	SET @cScanNoType = 'Ecom_single'
END
ELSE
BEGIN
	SET @cScanNoType = 'Ecom_multi'
END

--SELECT * FROM @pickSKUDetail
SET @b_Success = 1
SET @n_Err = 0
SET @c_ErrMsg = ''
SET @jResult =
--(SELECT @cScanNoType AS ScanNoType, @cPickSlipNo AS pickslipNo, @cOrderKey AS orderKey, @cLoadKey AS loadKey, @cZone AS Zone, @EcomSingle AS EcomSingle
--, @cDynamicRightName1 AS DynamicRightName1, @cDynamicRightValue1 AS DynamicRightValue1
--FOR JSON PATH , INCLUDE_NULL_VALUES)
----SELECT * FROM @pickSKUDetail
----FOR JSON AUTO, INCLUDE_NULL_VALUES))
(SELECT @cScanNoType AS ScanNoType,@EcomSingle AS EcomSingle,
(SELECT * FROM @pickSKUDetail
FOR JSON PATH , INCLUDE_NULL_VALUES) AS PickSkuDetail
FOR JSON PATH , INCLUDE_NULL_VALUES)

EXIT_SP:
   REVERT

SET QUOTED_IDENTIFIER OFF

GO