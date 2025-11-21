SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Unpack_GetStat                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 05-05-2016 1.0  Ung         SOS368666 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_Unpack_GetStat] (
    @nMobile       INT
   ,@nFunc         INT
   ,@cLangCode     NVARCHAR( 3)
   ,@nStep         INT
   ,@nInputKey     INT
   ,@cFacility     NVARCHAR( 5)
   ,@cStorerKey    NVARCHAR( 15)
   ,@cType         NVARCHAR( 10)  -- CURRENT/NEXT/TOTAL
   ,@cPickSlipNo   NVARCHAR( 10)
   ,@cFromDropID   NVARCHAR( 20)
   ,@cFromSKU      NVARCHAR( 20)
   ,@cFromCartonNo NVARCHAR( 5)
   ,@nCartonNo     INT            OUTPUT
   ,@cLabelNo      NVARCHAR( 20)  OUTPUT
   ,@cCartonID     NVARCHAR( 20)  OUTPUT
   ,@nCartonSKU    INT            OUTPUT
   ,@nCartonQTY    INT            OUTPUT
   ,@nTotalCarton  INT            OUTPUT
   ,@nTotalPick    INT            OUTPUT
   ,@nTotalPack    INT            OUTPUT
   ,@nTotalShort   INT            OUTPUT
   ,@nErrNo        INT            OUTPUT
   ,@cErrMsg       NVARCHAR(250)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /***********************************************************************************************
                                                PackDetail
   ***********************************************************************************************/
   DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cRefNo      NVARCHAR( 20)

   SELECT @nTotalPack = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo

   SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
   
   IF @cType = 'CURRENT'
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cDropID = DropID, 
         @cRefNo = RefNo
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND (@cFromCartonNo = '' OR CartonNo = @cFromCartonNo)
         AND (@cFromDropID = '' OR DropID = @cFromDropID)
         AND (@cFromSKU = '' OR SKU = @cFromSKU)
      ORDER BY CartonNo
   
   IF @cType = 'NEXT'
   BEGIN
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cDropID = DropID, 
         @cRefNo = RefNo
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND (@cFromCartonNo = '' OR CartonNo = @cFromCartonNo)
         AND (@cFromDropID = '' OR DropID = @cFromDropID)
         AND (@cFromSKU = '' OR SKU = @cFromSKU)
         AND CartonNo > @nCartonNo
      ORDER BY CartonNo
   
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1 
            @nCartonNo = CartonNo, 
            @cLabelNo = LabelNo, 
            @cDropID = DropID, 
            @cRefNo = RefNo
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND (@cFromCartonNo = '' OR CartonNo = @cFromCartonNo)
            AND (@cFromDropID = '' OR DropID = @cFromDropID)
            AND (@cFromSKU = '' OR SKU = @cFromSKU)
         ORDER BY CartonNo   
   
         IF @@ROWCOUNT = 0
            SELECT 
               @nCartonNo = 0, 
               @cLabelNo = '', 
               @cDropID = '', 
               @cRefNo = ''
      END
   END
   
   SELECT 
      @nCartonSKU = COUNT( DISTINCT PD.SKU), 
      @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND (@cFromDropID = '' OR DropID = @cFromDropID)
      AND (@cFromSKU = '' OR SKU = @cFromSKU)
      AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo

   -- Get carton ID
   DECLARE @cCustomCartonID NVARCHAR(1)
   SET @cCustomCartonID = rdt.rdtGetConfig( @nFunc, 'CustomCartonID', @cStorerKey)
   
   IF @cCustomCartonID = '1'
      SELECT @cCartonID = @cDropID
   ELSE IF @cCustomCartonID = '2'
      SELECT @cCartonID = @cRefNo
   ELSE 
      SELECT @cCartonID = @cLabelNo

   /***********************************************************************************************
                                                PickDetail
   ***********************************************************************************************/
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.Status <= '5'
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.Status = '4'
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.Status <= '5'
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.Status = '4'
   END
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey  
         AND PD.Status <= '5'
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey  
         AND PD.Status = '4'
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.Status <= '5'
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.Status = '4'
   END

END

GO