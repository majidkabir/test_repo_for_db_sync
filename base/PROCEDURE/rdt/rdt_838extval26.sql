SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal26                                     */
/* Copyright      : Maersk WMS                                          */
/* Customer       : PMI                                                 */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2025-02-13 1.0  NLT013      UWP-30204 Created                        */
/************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal26 (
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

   DECLARE 
      @cPickDetailKey   NVARCHAR(18),
      @cStatus          NVARCHAR(1),
      @cUCCPickSlipNo   NVARCHAR( 10),
      @nRowCount        INT

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 8 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 @cPickDetailKey = PickDetailKey,
               @cStatus = Status
            FROM dbo.UCC WITH(NOLOCK)
            WHERE UCCNo = @cUCCNo
               AND StorerKey = @cStorerKey

            SELECT @nRowCount = @@ROWCOUNT

            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 233201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC does not exist
               GOTO Quit
            END

            IF @cStatus NOT IN ('5', '6')
            BEGIN
               SET @nErrNo = 233202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCCStatus
               GOTO Quit
            END

            SELECT TOP 1 @cUCCPickSlipNo = PickSlipNo
            FROM dbo.PickDetail WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickDetailKey = @cPickDetailKey
            
            IF @cUCCPickSlipNo <> @cPickSlipNo
            BEGIN
               SET @nErrNo = 233203
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffPickSlipNo
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO