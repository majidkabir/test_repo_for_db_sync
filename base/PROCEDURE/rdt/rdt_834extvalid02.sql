SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_834ExtValid02                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-May-2019 1.0  James       WMS-9164 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_834ExtValid02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tExtValidate   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUCCNo     NVARCHAR( 20)
   DECLARE @cStatus    NVARCHAR( 1)
   DECLARE @cOrderKey  NVARCHAR( 10)
   DECLARE @cLoadKey   NVARCHAR( 10)
   DECLARE @cZone      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)  
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @nUCCQty    INT
   DECLARE @nPD_Qty    INT
   DECLARE @nSum_Picked    INT
   DECLARE @nSum_Packed    INT


   -- Variable mapping
   SELECT @cUCCNo = Value FROM @tExtValidate WHERE Variable = '@cCtnValue'

   IF @nStep = 2 -- Carton ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)

         SELECT @nUCCQty = ISNULL( Qty, 0)
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   UCCNo = @cUCCNo

         SELECT @nPD_Qty = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   DropID = @cUCCNo

         -- Check ucc not exists in either table 
         IF ( @nUCCQty + @nPD_Qty) = 0
         BEGIN
            SET @nErrNo = 139401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NOT EXISTS
            GOTO Quit
         END

         --IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
         --            WHERE StorerKey = @cStorerKey 
         --            AND   DropID = @cUCCNo
         --            AND   UOM = '6') 
         --BEGIN
         --   SET @nErrNo = 139402
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC UOM 6
         --   GOTO Quit
         --END

         SELECT @cStatus = Status, 
                @cOrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   DropID = @cUCCNo

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 139403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NOT EXISTS
            GOTO Quit
         END

         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 139404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC SHIPPED
            GOTO Quit
         END

         -- UCC scanned
         IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE UCCNo = @cUCCNo)
         BEGIN
            SET @nErrNo = 139405
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
            GOTO Quit
         END

         SELECT @cLoadkey = LoadKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         --delete from traceinfo where tracename = '834'
         --   insert into traceinfo (tracename, timein, col1, col2, col3) values ('834', getdate(), @cUCCNo, @cOrderKey, @cLoadkey)
         SET @cPickSlipNo = ''  
         SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

         IF @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 139406
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PickSlip req
            GOTO Quit  
         END

         SELECT @cZone = Zone, 
                @cLoadKey = ExternOrderKey,
                @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)     
         WHERE PickHeaderKey = @cPickSlipNo  

         SET @nSum_Picked = 0

         -- conso picklist   
         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
         BEGIN    
            -- Calc pick QTY
            SELECT @nSum_Picked = ISNULL( SUM( QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
            AND   PD.StorerKey = @cStorerKey
            AND ( PD.Status = @cPickConfirmStatus OR PD.Status = '5')
         END
         -- Discrete PickSlip
         ELSE IF ISNULL(@cOrderKey, '') <> '' 
         BEGIN
            SELECT @nSum_Picked = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cOrderKey
            AND   PD.StorerKey = @cStorerKey
            AND ( PD.Status = @cPickConfirmStatus OR PD.Status = '5')
         END
         ELSE
         BEGIN
            SELECT @nSum_Picked = ISNULL( SUM( QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
            AND   PD.StorerKey = @cStorerKey
            AND ( PD.Status = @cPickConfirmStatus OR PD.Status = '5')
         END

         SET @nSum_Packed = 0
         SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo

         IF ( @nSum_Packed + @nUCCQty) > @nSum_Picked
         BEGIN
            SET @nErrNo = 139407
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Pack
            GOTO Quit
         END
      END
   END

   Quit:

END

GO