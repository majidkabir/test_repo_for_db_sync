SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_834ExtValid01                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-Mar-2019 1.0  James       WMS-9064 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_834ExtValid01] (
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
   DECLARE @cErrMsg1       NVARCHAR(20)
   DECLARE @cErrMsg2       NVARCHAR(20)

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

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 139251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NOT EXISTS
            GOTO Quit
         END

         SELECT @cStatus = Status, 
                @cOrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   DropID = @cUCCNo

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 139252
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NOT READY
            GOTO Quit
         END

         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 139253
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC SHIPPED
            GOTO Quit
         END

         -- UCC scanned
         IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE UCCNo = @cUCCNo)
         BEGIN
            SET @nErrNo = 139254
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
            GOTO Quit
         END

         SELECT @cLoadkey = Loadkey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SET @cPickSlipNo = ''  
         SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

         IF @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 139255
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PickSlip req
            GOTO Quit  
         END

         SELECT @cZone = Zone, 
                @cLoadKey = ExternOrderKey,
                @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)     
         WHERE PickHeaderKey = @cPickSlipNo  

         SET @nSum_Picked = 0
         SET @nSum_Packed = 0

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
            AND   PD.UOM = '2'

            SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail PAD WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK)
                         JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON (PID.PickDetailKey = RKL.PickDetailKey)
                         WHERE RKL.PickSlipNo = @cPickSlipNo
                         AND   PID.StorerKey = @cStorerKey
                         AND ( PID.Status = @cPickConfirmStatus OR PID.Status = '5')
                         AND   PID.UOM = '2'
                         AND   PAD.RefNo = PID.DropID)
         END
         -- Discrete PickSlip
         ELSE IF ISNULL(@cOrderKey, '') <> '' 
         BEGIN
            SELECT @nSum_Picked = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cOrderKey
            AND   PD.StorerKey = @cStorerKey
            AND ( PD.Status = @cPickConfirmStatus OR PD.Status = '5')
            AND   PD.UOM = '2'

            SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail PAD WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK)
                         WHERE PID.OrderKey = @cOrderKey
                         AND   PID.StorerKey = @cStorerKey
                         AND ( PID.Status = @cPickConfirmStatus OR PID.Status = '5')
                         AND   PID.UOM = '2'
                         AND   PAD.RefNo = PID.DropID)
         END
         ELSE
         BEGIN
            SELECT @nSum_Picked = ISNULL( SUM( QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
            AND   PD.StorerKey = @cStorerKey
            AND ( PD.Status = @cPickConfirmStatus OR PD.Status = '5')
            AND   PD.UOM = '2'

            SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail PAD WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK)
                         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PID.OrderKey = LPD.OrderKey)    
                         WHERE LPD.LoadKey = @cLoadKey
                         AND   PID.StorerKey = @cStorerKey
                         AND ( PID.Status = @cPickConfirmStatus OR PID.Status = '5')
                         AND   PID.UOM = '2'
                         AND   PAD.RefNo = PID.DropID)
         END

         IF ( @nSum_Packed + @nUCCQty) > @nSum_Picked
         BEGIN
            SET @nErrNo = 139256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Pack
            GOTO Quit
         END
      END
   END

   IF @nStep = 4 -- Pack Info
   BEGIN
      IF @nInputKey = 0
      BEGIN
         SET @cErrMsg1 = rdt.rdtgetmessage( 139257, @cLangCode, 'DSP') --NEED PACKINFO
         SET @cErrMsg2 = rdt.rdtgetmessage( 139258, @cLangCode, 'DSP') --CANNOT PRESS ESC
            
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2

         SET @nErrNo = -1
         SET @cErrMsg = ''
      END
   END

   Quit:

END

GO