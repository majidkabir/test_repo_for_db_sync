SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_973ExtValid01                                   */
/* Purpose: Check duplicate sack id been used                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-08-05 1.0  James      Created-SOS348965                         */
/* 2015-09-07 1.1  James      Add Check packdetail                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_973ExtValid01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFromTote       NVARCHAR( 20), 
   @cToTote         NVARCHAR( 20), 
   @cSKU            NVARCHAR( 20), 
   @nQtyMV          INT, 
   @cConsoOption    NVARCHAR( 1), 
   @nErrNo          INT OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cPTS_LOC    NVARCHAR( 10), 
           @cErrMsg1           NVARCHAR( 20),       
           @cErrMsg2           NVARCHAR( 20),       
           @cErrMsg3           NVARCHAR( 20),       
           @cErrMsg4           NVARCHAR( 20),       
           @cErrMsg5           NVARCHAR( 20)        

   IF LEN( RTRIM( @cToTote)) <> 10 AND LEN( RTRIM( @cFromTote)) <> 8
      GOTO Quit

   SELECT @cPTS_LOC = V_LOC FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   
   -- Check duplicate sack id
   -- 1st check if the sack id exists in serial no. After each ToTote scanned then will insert a record into pickdetail
   IF EXISTS ( SELECT 1 FROM dbo.SerialNo WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   SerialNo = @cToTote)
   BEGIN
      -- Check if scanned by case from bulk
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   AltSKU = @cToTote
                      AND   Status = '5'
                      AND   LOC = @cPTS_LOC
                      AND   ShipFlag <> 'Y')
      BEGIN
         -- If not been scanned by case from bulk before then check tote from PPA
         -- Check if the sack is open
         IF NOT EXISTS ( SELECT 1 FROM dbo.Dropid WITH (NOLOCK)
                         WHERE Dropid = @cToTote
                         AND   DropLOC = @cPTS_LOC
                         AND   ManifestPrinted <> 'Y')
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
                            JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                            WHERE PD.DROPID = @cToTote
                            AND   PD.StorerKey = @cStorerKey
                            AND   PH.Status = '0')
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = 'SACK SCANNED BEFORE'
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = 'PLS SEE SUPERVISOR.'
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  GOTO Quit
               END                      
            END
         END
      END
   END

QUIT:

GO