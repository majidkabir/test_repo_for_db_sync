SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_JACKWExtValid02                                 */
/* Purpose: To limit total weights of a sack/tote can hold              */
/*          Return msg queue is total weight exceeded                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-29 1.0  James      Created                                   */
/* 2014-11-07 1.1  James      Remove traceinfo                          */
/* 2015-07-31 1.2  James      SOS348965-Check duplicate sack id been    */
/*                            used (james01)                            */
/* 2017-10-16 1.3  James      Change weight limit from 25 to 50 by      */
/*                            Brian Hudgson                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_JACKWExtValid02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),   
   @cCaseID          NVARCHAR( 18), 
   @cLOC             NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @cConsigneekey    NVARCHAR( 15), 
   @nQTY             INT, 
   @cToToteNo        NVARCHAR( 18), 
   @cSuggPTSLOC      NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @fSKU_Weight        Float, 
           @fTtl_Weight        Float, 
           @fSTDGROSSWGT       Float, 
           @cLoadKey           NVARCHAR( 10), 
           @cErrMsg1           NVARCHAR( 20),       
           @cErrMsg2           NVARCHAR( 20),       
           @cErrMsg3           NVARCHAR( 20),       
           @cErrMsg4           NVARCHAR( 20),       
           @cErrMsg5           NVARCHAR( 20)        

   -- Check duplicate sack id(james01)
   -- 1st check if the sack id exists in serial no. After each ToTote scanned then will insert a record into pickdetail
   IF EXISTS ( SELECT 1 FROM dbo.SerialNo WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   SerialNo = @cToToteNo)
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   AltSKU = @cToToteNo
                      AND   LOC = @cSuggPTSLOC
                      AND   Status = '5'
                      AND   ShipFlag <> 'Y')
      BEGIN
         -- If not been scanned by case from bulk before then check tote from PPA
         -- Check if the sack is open and must be in same PTS loc
         IF NOT EXISTS ( SELECT 1 FROM dbo.Dropid WITH (NOLOCK)
                         WHERE Dropid = @cToToteNo
                         AND   DropLOC = @cSuggPTSLOC
                         AND   ManifestPrinted <> 'Y')
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
   
   SELECT @fSKU_Weight = ISNULL( STDGROSSWGT, 0) FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   IF (ISNULL( @nQTY, 0) * @fSKU_Weight) > 50 
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg1 = 'SKU WEIGHT > 50KG'
      SET @cErrMsg2 = 'PLS SEE SUPERVISOR.'
      SET @cErrMsg3 = ''
      SET @cErrMsg4 = ''
      SET @cErrMsg5 = ''
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''

         GOTO Quit
      END
   END
   
   -- Get Loadkey
   SELECT @cLoadKey = D.LoadKey 
   FROM dbo.DropID D WITH (NOLOCK) 
   JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)
   WHERE DD.ChildID = @cCaseID
   AND   D.DropIDType = 'C'   
   AND   D.Status = '5'

   -- Get total weight of the tote/sacks
   SELECT @fTtl_Weight = SUM( PD.Qty * ISNULL( SKU.STDGROSSWGT, 0)) 
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
   JOIN SKU SKU WITH (NOLOCK) ON ( PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE PD.StorerKey = @cStorerKey
   AND   PD.AltSKU = @cToToteNo
   AND   PD.Status = '5'
   AND   LPD.LoadKey = @cLoadKey

   IF @fTtl_Weight > 50 
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg1 = 'SACKS WEIGHT > 50KG'
      SET @cErrMsg2 = 'PLS CLOSE SACKS.'
      SET @cErrMsg3 = ''
      SET @cErrMsg4 = ''
      SET @cErrMsg5 = ''
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''
      END
   END

QUIT:

GO