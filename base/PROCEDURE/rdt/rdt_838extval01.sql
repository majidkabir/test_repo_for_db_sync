SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 15-11-2016 1.0  Ung         WMS-458 Created                          */
/* 24-05-2017 1.1  Ung         WMS-1919 Param change                    */
/* 04-04-2019 1.2  Ung         WMS-8134 Add PackData1..3 parameter      */
/************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal01 (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 8 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get UCC info
            SELECT TOP 1 
               @cCartonType = LEFT( UserDefined01, 10), 
               @cWeight = LEFT( UserDefined02, 10)
            FROM UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND UCCNo = @cUCCNo
         
            -- Check carton type
            IF @cCartonType = ''
            BEGIN
               SET @nErrNo = 105151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
               GOTO Quit
            END
         
            -- Check weight
            IF @cWeight = ''
            BEGIN
               SET @nErrNo = 105152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
               GOTO Quit
            END
         
            -- Check weight
            IF rdt.rdtIsValidQTY( @cWeight, 20) = 0
            BEGIN
               SET @nErrNo = 105153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO