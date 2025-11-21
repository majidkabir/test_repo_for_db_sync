SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_838ExtVal20                                     */
/* Copyright      :                                                     */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2023-06-28 1.0  JHU151     FCR-352 Created                           */
/* 2024-10-24 1.1  TLE109     FCR-990. Packing Serial Number Validation */
/************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal20 (
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

   DECLARE @nSKUWeight Float
   DECLARE @nTTlSKUWeight Float = 0
   DECLARE @nMaxCtnWeight Float
   DECLARE @nCtnWeight Float
   DECLARE @cDefaultcartontype NVARCHAR(20)
   DECLARE @cPackSKU NVARCHAR(20)
   DECLARE @nPackQTY  INT
   DECLARE @cErrMsg1  NVARCHAR(20)

   
   SELECT
      @cSerialNo         = V_Max
	FROM rdt.rdtMobRec WITH (NOLOCK)
	WHERE Mobile = @nMobile

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 1 -- pickslip no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN            
            -- Check Pack confirmed
            IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
            BEGIN
               SET @nErrNo = 100203
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack confirmed
               GOTO Quit
            END
         END
      END
      ELSE IF @nStep = 9
      BEGIN
         IF @nInputKey = 1
         BEGIN
            DECLARE  @cAddRCPTValidtn     NVARCHAR(10)
            SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddSerialValidtn', @cStorerKey)

            IF @cAddRCPTValidtn = '1'
            BEGIN
               --alpha numeric
               IF PATINDEX('%[^0-9a-zA-Z]%', @cSerialNo) > 0
               BEGIN
                  SET @nErrNo = 100248
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --100248Invalid Serial No
                  GOTO Quit
               END

               IF EXISTS( SELECT 1 FROM dbo.SerialNo WITH(NOLOCK) WHERE StorerKey = @cStorerkey AND SKU = @cSKU AND SerialNo = @cSerialNo AND [Status] <> 1 )
               BEGIN
                  SET @nErrNo = 100249
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --100249SSerial No Cannot Be Packed
                  GOTO Quit
               END

               IF (LEFT(@cSerialNo, 6) <> @cSKU OR LEN(@cSerialNo) <= 6)
                  AND (LEFT(@cSerialNo, 10) <> @cSKU OR LEN(@cSerialNo) <= 10) 
               BEGIN
                  SET @nErrNo = 100250
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --100250Serial Confirm
                  GOTO Quit
               END


            END
         END
      END   
   END

Quit:

END

GO