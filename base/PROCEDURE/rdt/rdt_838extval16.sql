SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal16                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2023-08-23 1.0  Ung     WMS-22913 Created                            */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtVal16] (
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
      IF @nStep = 2 -- Statistics
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check Drop ID packed
            IF @cFromDropID <> '' AND @cOption = '1' -- NEW
            BEGIN
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                     AND DropID = @cFromDropID)
               BEGIN
                  SET @nErrNo = 198151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID packed
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO