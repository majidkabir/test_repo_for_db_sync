SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtValVLT                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 5/17/2024  1.0  PPA374   Packing validations - DROP ID number AND    */
/*                            usage of options.                         */
/* 6/20/2024  1.1  WSE016   Packing validations - Client Pack Matrix    */
/* 2024-10-08 1.2  PXL009   FCR-778 Violet Pack Changes                 */
/************************************************************************/

CREATE    PROCEDURE [RDT].[rdt_838ExtValVLT] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cPickSlipNo     NVARCHAR( 10),
   @cFromDropID     NVARCHAR( 20),
   @nCartonNo       INT,
   @cLabelNo        NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cUCCNo          NVARCHAR( 20),
   @cCartonType     NVARCHAR( 10),
   @cCube           NVARCHAR( 10),
   @cWeight         NVARCHAR( 10),
   @cRefNo          NVARCHAR( 20),
   @cSerialNo       NVARCHAR( 30),
   @nSerialQTY      INT,
   @cOption         NVARCHAR( 1),
   @cPackDtlRefNo   NVARCHAR( 20),
   @cPackDtlRefNo2  NVARCHAR( 20),
   @cPackDtlUPC     NVARCHAR( 30),
   @cPackDtlDropID  NVARCHAR( 20),
   @cPackData1      NVARCHAR( 30),
   @cPackData2      NVARCHAR( 30),
   @cPackData3      NVARCHAR( 30),
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cLabelCode                      NVARCHAR (30),
      @nSkuLimit                       INT,
      @nSkuCheck01                     NVARCHAR (30),
      @cOrderKey                       NVARCHAR( 10),
      @cSerialNoCapture                NVARCHAR( 1),
      @nSKUWeight                      FLOAT,
      @nSKUCube                        FLOAT,
      @cSKUBrand                       NVARCHAR( 10),
      @cOrderConsigneeKey              NVARCHAR( 15),
      @cOrderC_Zip                     NVARCHAR( 18),
      @cDefaultConsigneeKey            NVARCHAR( 15),
      @cCustomerPalletType             NVARCHAR( 10),
      @cCustomerPalletCube             NVARCHAR( 20),
      @cCustomerPalletHeight           NVARCHAR( 20),
      @cCustomerPalletWeight           NVARCHAR( 20),
      @cCustomerPalletMixBrands        NVARCHAR( 20),
      @cCustomerPalletProductGrouping  NVARCHAR( 18),
      @cAddPackValidtn                 NVARCHAR( 20)

   IF @nFunc = 838
   BEGIN
      SELECT TOP 1 @cSerialNoCapture = SerialNoCapture FROM dbo.SKU WITH(NOLOCK) WHERE sku = @cSKU and StorerKey = @cStorerKey
      SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.PICKDETAIL WITH(NOLOCK) WHERE DropID = @cFromDropID and StorerKey = @cStorerKey

      -- get ConsigneeKey for Client Print Matrix
      SELECT TOP 1 @cOrderConsigneeKey = ConsigneeKey,@cOrderC_Zip=[C_Zip] FROM dbo.ORDERS WITH(NOLOCK) WHERE storerkey = @cStorerKey AND OrderKey = @cOrderKey

      -- get Client Pack Matrix
      SELECT
         @cLabelCode = Short,
         @nSkuLimit = UDF01
      FROM dbo.CODELKUP WITH(NOLOCK)
      WHERE LISTNAME ='PackMatrix'
         AND Code = @cOrderConsigneeKey
		 AND StorerKey = @cStorerKey

      -- get SKU for Client Pack Matrix
      SELECT @nSkuCheck01 = ISNULL(COUNT(DISTINCT(SKU)),0) FROM dbo.PackDetail WITH(NOLOCK) WHERE CartonNo = @nCartonNo AND DropID = @cPackDtlDropID AND PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey
      -- WS_20062024 END

      IF @nStep = 1
      BEGIN
         IF @cFromDropID = '' OR @cPackDtlDropID = ''
         BEGIN
            SET @nErrNo = 223601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --BothDropIDNeeded
            GOTO Quit
         END

         ELSE IF CHARINDEX(' ',@cPackDtlDropID)>0 OR LEN(@cPackDtlDropID)<>18 OR CONVERT(NVARCHAR(30),substring(@cPackDtlDropID,1,3)) <> '050'
         BEGIN
            SET @nErrNo = 223602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Invalid Format
            GOTO Quit
         END

         ELSE IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH(NOLOCK) WHERE Dropid = @cPackDtlDropID AND OrderKey <> @cOrderKey AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 223603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --OtherOrderDropID
            GOTO Quit
         END

         ELSE IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH(NOLOCK) WHERE Dropid = @cPackDtlDropID AND PickSlipNo <> @cPickSlipNo AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 223604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --ToDropIDISUsed
            GOTO Quit
         END

         ELSE IF (1 IN (SELECT short FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPICCHK' AND storerkey = @cStorerKey)
            AND 0 NOT IN (SELECT short FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPICCHK' AND storerkey = @cStorerKey)) AND
            EXISTS
            (SELECT Loc FROM dbo.PICKDETAIL PD WITH(NOLOCK)
            WHERE Storerkey = @cStorerKey 
			AND orderkey = @cOrderKey
            AND (not exists
            (SELECT 1 FROM dbo.MBOL WITH(NOLOCK)
            WHERE Facility = @cFacility AND PD.Loc = MBOL.OtherReference 
		    AND mbolkey = 
            (SELECT TOP 1 MbolKey FROM dbo.ORDERS WITH(NOLOCK) WHERE Storerkey = @cStorerKey AND orderkey = @cOrderKey))
            AND NOT EXISTS (SELECT LOC FROM dbo.LOC L WITH(NOLOCK) WHERE Storerkey = @cStorerKey AND L.Loc = PD.Loc AND 
		    EXISTS (SELECT 1 FROM dbo.CODELKUP CLU WITH(NOLOCK) WHERE CLU.Code = L.PutawayZone and Storerkey = @cStorerKey AND LISTNAME = 'VASZONHUSQ'))))
         BEGIN
            SET @nErrNo = 223605
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --OrderNotStaged
            GOTO Quit
         END
      END

      -- WS_20062024 Client Pack Validation Matrix
      IF @nStep = 1 AND @cLabelCode = 'SINGLE'  AND @nSkuLimit < @nSkuCheck01
      BEGIN
         SET @nErrNo = 223606
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --SingleSKULimit
         GOTO Quit
      END

      IF @nStep = 1 AND @cLabelCode = 'MULTI' AND @nSkuLimit < @nSkuCheck01
      BEGIN
         SET @nErrNo = 223607
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --MultSKULimit
         GOTO Quit
      END

      -- WS_20062024
      IF @nStep = 3 AND @cSerialNoCapture IN (N'1',N'3') AND @nQTY > 1
      BEGIN
         SET @nErrNo = 223608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Pack 1 EA
         GOTO Quit
      END

      IF @nStep = 2 AND @cOption IN (2,3) AND NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH(NOLOCK) WHERE CartonNo = @nCartonNo and StorerKey = @cStorerKey
	  AND DropID = @cPackDtlDropID AND PickSlipNo = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 223609
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --InvCon/DropID
         GOTO Quit
      END

      -- WS_03072024 Client Pack Validation Matrix -> SKU screen check
      IF @nStep = 3 AND @cLabelCode = 'SINGLE'
	     AND not exists (select 1 FROM dbo.PackDetail WITH(NOLOCK) WHERE CartonNo = @nCartonNo AND DropID = @cPackDtlDropID 
         AND PickSlipNo = @cPickSlipNo and StorerKey = @cStorerKey and @cSKU = isnull(sku,''))
         AND @nSkuLimit <= @nSkuCheck01
      BEGIN
         SET @nErrNo = 223610
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --SingleSKULimit
         GOTO Quit
      END

      IF @nStep = 3 AND @cLabelCode = 'MULTI'
	     AND not exists (select 1 FROM dbo.PackDetail WITH(NOLOCK) WHERE @cSKU = isnull(sku,'') and CartonNo = @nCartonNo AND DropID = @cPackDtlDropID AND PickSlipNo = @cPickSlipNo and StorerKey = @cStorerKey)
         AND @nSkuLimit <= @nSkuCheck01
      BEGIN
         SET @nErrNo = 223611
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --MultSKULimit
         GOTO Quit
      END
      -- WS_03072024  END
      IF @nStep = 2 AND @cOption = 1 AND EXISTS (SELECT 1 FROM dbo.PackDetail WITH(NOLOCK) WHERE CartonNo = @nCartonNo AND DropID = @cPackDtlDropID AND PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 223612
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Exists,UseEdit
         GOTO Quit
      END

      SET @cAddPackValidtn = [rdt].[RDTGetConfig]( @nFunc, 'AddPackValidtn', @cStorerKey)
      SET @cDefaultConsigneeKey = [rdt].[RDTGetConfig]( @nFunc, N'AddPackValidtnDefCNEE', @cStorerKey)
      IF ISNULL(@cDefaultConsigneeKey, N'') = N'' OR @cDefaultConsigneeKey = N'0'
      BEGIN
         SET @cDefaultConsigneeKey = N'0000000001'
      END

      IF @nStep = 3
         AND ISNULL(@cSKU, N'') <> N''
         AND @nQTY > 0
         AND @cAddPackValidtn = N'1'
      BEGIN
         -- Get info
         SELECT TOP 1
              @nSKUWeight  = [SKU].[STDGROSSWGT] * @nQTY
             ,@nSKUCube    = [PACK].[WidthUOM3] * [PACK].[LengthUOM3] * [PACK].[HeightUOM3] * @nQTY
             ,@cSKUBrand   = CASE WHEN [CLASS] = N'FLY' THEN N'Flymo' ELSE N'Gardena' END
         FROM  [dbo].[SKU]  WITH (NOLOCK)
            INNER JOIN [dbo].[PACK] WITH (NOLOCK) ON  [SKU].[PACKKey] = [PACK].[PackKey]
         WHERE  [SKU].[Sku]  = @Csku

         SELECT @cCustomerPalletType         = [Pallet]
            ,@cCustomerPalletCube            = [SUSR1]
            ,@cCustomerPalletHeight          = [SUSR2]
            ,@cCustomerPalletWeight          = [SUSR3]
            ,@cCustomerPalletMixBrands       = [SUSR4]
            ,@cCustomerPalletProductGrouping = [CreditLimit]
         FROM [dbo].[STORER] WITH (NOLOCK)
         WHERE [Address1] = @cOrderConsigneeKey
            AND [ConsigneeFor] = @cStorerKey
            AND [Zip] = @cOrderC_Zip
            AND [Type] = 2

         SELECT @cCustomerPalletType         = CASE WHEN ISNULL(@cCustomerPalletType, N'')            = N'' THEN [Pallet]      ELSE @cCustomerPalletType            END
            ,@cCustomerPalletCube            = CASE WHEN ISNULL(@cCustomerPalletCube, N'')            = N'' THEN [SUSR1]       ELSE @cCustomerPalletCube            END
            ,@cCustomerPalletHeight          = CASE WHEN ISNULL(@cCustomerPalletHeight, N'')          = N'' THEN [SUSR2]       ELSE @cCustomerPalletHeight          END
            ,@cCustomerPalletWeight          = CASE WHEN ISNULL(@cCustomerPalletWeight, N'')          = N'' THEN [SUSR3]       ELSE @cCustomerPalletWeight          END
            ,@cCustomerPalletMixBrands       = CASE WHEN ISNULL(@cCustomerPalletMixBrands, N'')       = N'' THEN [SUSR4]       ELSE @cCustomerPalletMixBrands       END
            ,@cCustomerPalletProductGrouping = CASE WHEN ISNULL(@cCustomerPalletProductGrouping, N'') = N'' THEN [CreditLimit] ELSE @cCustomerPalletProductGrouping END
         FROM [dbo].[STORER] WITH (NOLOCK)
         WHERE [StorerKey] = @cDefaultConsigneeKey
            AND [ConsigneeFor] = @cStorerKey
            AND [Type] = 2

         -- check if first SKU added into the Pack DropID
         IF NOT EXISTS(SELECT 1 FROM [dbo].[PackDetail] WITH(NOLOCK) WHERE [StorerKey] = @cStorerKey AND [DropID] = @cPackDtlDropID)
         BEGIN
            IF ISNULL(@cCustomerPalletWeight, '') <> '' AND @nSKUWeight > CAST(@cCustomerPalletWeight AS FLOAT)
            BEGIN
               SET @nErrNo = 223614
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Weight limit exceeded
               GOTO Quit
            END

            IF ISNULL(@cCustomerPalletCube, '') <> '' AND @nSKUCube > CAST(@cCustomerPalletCube AS FLOAT)
            BEGIN
               SET @nErrNo = 223613
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Cube limit exceeded
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF ISNULL(@cCustomerPalletWeight, '') <> '' AND EXISTS(SELECT 1 FROM [dbo].[PALLET] WITH(NOLOCK) WHERE [PalletKey] = @cPackDtlDropID AND [GrossWgt] + @nSKUWeight > CAST(@cCustomerPalletWeight AS FLOAT))
            BEGIN
               SET @nErrNo = 223616
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Weight limit exceeded
               GOTO Quit
            END

            IF ISNULL(@cCustomerPalletCube, '') <> '' AND EXISTS(SELECT 1 FROM [dbo].[PALLET] WITH(NOLOCK) WHERE [PalletKey] = @cPackDtlDropID AND [Height] + @nSKUCube > CAST(@cCustomerPalletCube AS FLOAT))
            BEGIN
               SET @nErrNo = 223615
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Cube limit exceeded
               GOTO Quit
            END

            IF ISNULL(@cCustomerPalletProductGrouping, N'') NOT IN (N'0', N'')
               AND CAST(@cCustomerPalletProductGrouping AS INT) < (SELECT ISNULL(COUNT(DISTINCT(SKU)),0) FROM [dbo].[PackDetail] WITH(NOLOCK) WHERE [StorerKey] = @cStorerKey AND [DropID] = @cPackDtlDropID AND [Sku] <> @cSKU) + 1
            BEGIN
               SET @nErrNo = 223617
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Product Grouping limit exceeded
               GOTO Quit
            END

            IF @cCustomerPalletMixBrands = N'N'
               AND EXISTS( SELECT 1
                           FROM [dbo].[PackDetail] WITH(NOLOCK)
                           INNER JOIN [dbo].[SKU] WITH(NOLOCK) ON [PackDetail].[Sku] = [SKU].[Sku] AND [PackDetail].[StorerKey] = [SKU].[StorerKey]
                           WHERE [PackDetail].[DropID] = @cPackDtlDropID
                              AND [PackDetail].[StorerKey]   =  @cStorerKey
                              AND CASE WHEN [SKU].[CLASS] = N'FLY' THEN N'Flymo' ELSE N'Gardena' END <> @cSKUBrand
               )
            BEGIN
               SET @nErrNo = 223618
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, N'DSP') --Mixed Brands limit exceeded
               GOTO Quit
            END
         END
      END
   END

   GOTO Quit

Quit:
END


GO