SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_804PrintLabel02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 11-03-2016 1.0  Ung         SOS361967 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_804PrintLabel02] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) 
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1)
   ,@cCartonID    NVARCHAR( 20)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   
   -- Get CartonNo
   SET @cPickSlipNo = ''
   SET @nCartonNo = 0
   SELECT 
      @cPickSlipNo = PickSlipNo, 
      @nCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND RefNo = @cCartonID

   -- Found PickSlipNo
   IF @cPickSlipNo <> ''
   BEGIN
      -- PackInfo not yet created
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         DECLARE @cCartonGroup NVARCHAR( 10)
         DECLARE @cCartonType NVARCHAR( 10)
         DECLARE @fCube FLOAT
         DECLARE @fWeight FLOAT
         
         SET @cCartonGroup = ''
         SET @cCartonType = ''
         SET @fCube = 0
         SET @fWeight = 0
         
         -- Get Carton info
         SELECT @cCartonGroup = CartonGroup FROM Storer WITH (NOLOCK) WHERE StorerKey = @cStorerKey
         SELECT TOP 1 
            @cCartonType = CartonType, 
            @fCube = Cube
         FROM Cartonization WITH (NOLOCK)
         WHERE CartonizationGroup = @cCartonGroup
         ORDER BY UseSequence
         
         -- Calc Weight
         SELECT @fWeight = ISNULL( SUM( QTY * SKU.STDGrossWGT), 0)
         FROM PackDetail PD WITH (NOLOCK)
             JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         
         -- PackInfo
         INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)
         VALUES (@cPickSlipNo, @nCartonNo, @fWeight, @fCube, @cCartonType)
         IF @@ERROR <> 0
         BEGIN  
            SET @nErrNo = 100601  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail  
            GOTO Quit  
         END  
      END
   END
   
Quit:
END

GO