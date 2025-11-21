SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_838ExtUpdVLT                                       */
/*                                                                         */
/*                                                                         */
/* Date        Rev   Author      Purposes                                  */
/* 2024-05-17  1.0   PPA374      Inserts DROPID in the DropID table        */
/* 2024-09-13  1.1   PXL009      FCR-778 Violet Pack Changes               */  
/***************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtUpdVLT] (
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
      @LOADKEY                NVARCHAR( 20),
      @PICKSLIP               NVARCHAR( 20),
      @cOrderKey              NVARCHAR( 10),
      @cOrderConsigneeKey     NVARCHAR( 15),
      @cOrderC_Zip            NVARCHAR( 18),
      @cCustomerPalletType    NVARCHAR( 10),
      @nSKUWeight             FLOAT,
      @nSKUCube               FLOAT

   --Finding load key AND pickslip number
   -- SELECT TOP 1 @LOADKEY = LoadKey FROM ORDERS (NOLOCK) WHERE StorerKey = @cStorerKey and orderkey = (SELECT TOP 1 OrderKey FROM PICKDETAIL (NOLOCK) WHERE DropID = @cFromDropID and Storerkey = @cStorerKey)
   -- SELECT TOP 1 @PICKSLIP = PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE orderkey = (SELECT TOP 1 OrderKey FROM PICKDETAIL (NOLOCK) WHERE DropID = @cFromDropID and Storerkey = @cStorerKey)
   
   IF @nFunc = 838
   BEGIN

      SELECT TOP 1 @cOrderKey = [OrderKey]
      FROM [PickDetail] WITH (NOLOCK)
      WHERE [StorerKey] = @cStorerKey
         AND [DropID] = @cFromDropID

      SELECT TOP 1 @PICKSLIP = [PickHeaderKey]
      FROM [PICKHEADER] WITH (NOLOCK)
      WHERE [StorerKey] = @cStorerKey
         AND [OrderKey] = @cOrderKey

      SELECT TOP 1 @LOADKEY = LoadKey
         ,@cOrderConsigneeKey = [ConsigneeKey]
         ,@cOrderC_Zip        = [C_Zip]
      FROM [ORDERS] WITH (NOLOCK)
      WHERE [Orderkey] = @cOrderKey
         AND [StorerKey] = @cStorerKey

      SELECT TOP 1 @cCustomerPalletType   = [Pallet]
      FROM [STORER] WITH (NOLOCK)
      WHERE [StorerKey] = @cOrderConsigneeKey
         AND [ConsigneeFor] = @cStorerKey
         AND [Zip] = @cOrderC_Zip
         AND [Type] = 2

      SELECT TOP 1
             @nSKUWeight  = [SKU].[STDGROSSWGT] * @nQTY
            ,@nSKUCube    = [PACK].[WidthUOM3] * [PACK].[LengthUOM3] * [PACK].[HeightUOM3] * @nQTY
      FROM  [SKU]  WITH (NOLOCK)
         INNER JOIN [PACK] WITH (NOLOCK) ON  [SKU].[PACKKey] = [PACK].[PackKey] 
      WHERE  [SKU].[Sku]  = @cSKU

      --If operator is NOT printing the label for DROPID AND drop id record does NOT exist in the DropID table
      IF @nStep = 5 -- Print Label
         AND @cOption = 2 -- no
         AND NOT EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cPackDtlDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cPackDtlDropID,'','',0,'N',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
      END

      --If operator is printing the label for DROPID AND drop id record does NOT exist in the DropID table
      ELSE IF @nStep = 5 --Print Label
     AND @cOption = 1 -- Yes
     AND NOT EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cPackDtlDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cPackDtlDropID,'','',0,'Y',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
      END

      --If operator is printing the label for DROPID AND drop id record already exist in the DropID table
      ELSE IF @nStep = 5 -- Print Label
     AND @cOption = 1 -- Yes
     AND EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cPackDtlDropID AND LabelPrinted = 'N')
      BEGIN
         UPDATE dropid
         SET LabelPrinted = 'Y'
         WHERE dropid = @cPackDtlDropID
      END

     --Inserting DropID into the DropID table at SKU QTY step. Required in scenarios when label will NOT be printed.
      IF @nStep = 3 -- SKU QTY
     AND NOT EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cPackDtlDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cPackDtlDropID,'','',0,'N',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
      END

      IF @nStep = 3 
         AND @cOption = 1
         AND NOT EXISTS (SELECT 1 FROM [PALLET] (NOLOCK) WHERE [PalletKey] = @cPackDtlDropID)
      BEGIN
         INSERT [PALLET] ([PalletKey],[StorerKey],[Status],[EffectiveDate],[AddDate],[AddWho],[EditDate],[EditWho],[TrafficCop],[ArchiveCop],[TimeStamp],[Length],[Width],[Height],[GrossWgt],[PalletType])
         VALUES(@cPackDtlDropID, @cStorerKey,NULL,GETDATE(),GETDATE(),N'rdt.' + CAST(@nFunc AS NVARCHAR),GETDATE(),N'rdt.' + CAST(@nFunc AS NVARCHAR),NULL,NULL,NULL,0,0,0,0,@cCustomerPalletType)
      END

      IF @nStep = 3 
         AND @cOption = 1
         AND NOT EXISTS (SELECT 1 FROM [PALLET] (NOLOCK) WHERE [PalletKey] = @cPackDtlDropID)
      BEGIN
         UPDATE [PALLET] WITH (ROWLOCK)  SET
            [Height]       = [Height]   + @nSKUCube,
            [GrossWgt]     = [GrossWgt] + @nSKUWeight,
            [PalletType]   = @cCustomerPalletType,
            [EditWho]      = N'rdt.' + CAST(@nFunc AS NVARCHAR),
            [EditDate]     = GETDATE()
         WHERE [PalletKey] = @cPackDtlDropID  
      END

   END
END-- end sp


GO