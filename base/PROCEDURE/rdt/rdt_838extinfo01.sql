SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 05-09-2017 1.0 Ung         WMS-2795 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtInfo01] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nAfterStep = 3 -- SKU QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Variable mapping
            DECLARE @cFromDropID NVARCHAR(20)
            SELECT @cFromDropID = Value FROM @tVar WHERE Variable = '@cFromDropID'
   
            IF @cFromDropID <> ''
            BEGIN
               DECLARE @cPickSlipNo NVARCHAR( 10)
               DECLARE @cPickStatus NVARCHAR( 1)
               DECLARE @cOrderKey   NVARCHAR( 10)
               DECLARE @cLoadKey    NVARCHAR( 10)
               DECLARE @cZone       NVARCHAR( 18)
               DECLARE @nPackQTY    INT
               DECLARE @nPickQTY    INT
            
               SET @cOrderKey = ''
               SET @cLoadKey = ''
               SET @cZone = ''
               SET @nPackQTY = 0
               SET @nPickQTY = 0

               -- Variable mapping
               SELECT @cPickSlipNo = Value FROM @tVar WHERE Variable = '@cPickSlipNo'
               
               -- Get storer config
               SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)
   
               -- Calc pack QTY
               SET @nPackQTY = 0
               SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
               FROM PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo
                  AND StorerKey = @cStorerKey
                  AND DropID = @cFromDropID
   
               -- Get PickHeader info
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo
   
               IF @cZone IN ('XD', 'LB', 'LP')
                  SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND (PD.Status = '5' OR PD.Status = @cPickStatus)
                     AND PD.DropID = @cFromDropID
               
               -- Discrete PickSlip
               ELSE IF @cOrderKey <> ''
                  SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.StorerKey = @cStorerKey
                     AND (PD.Status = '5' OR PD.Status = @cPickStatus)
                     AND PD.DropID = @cFromDropID
               
               -- Conso PickSlip
               ELSE IF @cLoadKey <> ''
                  SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  WHERE LPD.LoadKey = @cLoadKey
                     AND PD.StorerKey = @cStorerKey
                     AND (PD.Status = '5' OR PD.Status = @cPickStatus)
                     AND PD.DropID = @cFromDropID            
   
               -- Custom PickSlip
               ELSE
                  SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
                  FROM dbo.PickDetail PD (NOLOCK) 
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND (PD.Status = '5' OR PD.Status = @cPickStatus)
                     AND PD.DropID = @cFromDropID
                           
               DECLARE @cMsg NVARCHAR(20)
               SET @cMsg = rdt.rdtgetmessage( 114301, @cLangCode, 'DSP') --DROPID QTY: 
   
               SET @cExtendedInfo = 
                  RTRIM( @cMsg) + ' ' + 
                  RTRIM( CAST( @nPackQTY AS NVARCHAR(5))) + '/' + 
                  RTRIM( CAST( @nPickQTY AS NVARCHAR(5)))
            END
         END
      END
   END

Quit:

END

GO