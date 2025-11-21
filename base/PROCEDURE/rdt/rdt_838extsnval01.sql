SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ExtSNVal01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 11-06-2019  1.0  Ung          WMS-9375 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_838ExtSNVal01]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT, 
   @cSerialNo        NVARCHAR( 30),
   @cType            NVARCHAR( 15), --CHECK/INSERT
   @cDocType         NVARCHAR( 10), 
   @cDocNo           NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10) = ''
   DECLARE @cLoadKey    NVARCHAR( 10) = ''
   DECLARE @cZone       NVARCHAR( 18) = ''
   DECLARE @cPickStatus NVARCHAR( 1)  = ''

   -- Get PickStatus
   SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)
      
   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cDocNo

   -- Discrete pack
   IF @cOrderKey <> ''
   BEGIN
      -- Check serial no in pick slip
      IF NOT EXISTS( SELECT TOP 1 1
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND (PD.Status = '5' OR PD.Status = @cPickStatus)
            AND PD.QTY > 0
            AND LA.Lottable12 = @cSerialNo)
      BEGIN
         SET @nErrNo = 100358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NotIn PSNO
         GOTO Quit
      END
   END

Quit:

END


GO