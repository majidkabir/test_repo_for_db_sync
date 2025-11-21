SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_855ExtUOM01                                     */
/* Purpose: Get prefered UOM qty from consigneesku table                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-07-19  1.0  Chermaine  WMS-17439. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_855ExtUOM01] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtUOM        VariableTable READONLY,      
   @cPUOM          NVARCHAR( 1)  OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cDropID  NVARCHAR( 20)
   DECLARE @cPPACartonIDByPickDetailCaseID NVARCHAR(1)
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1 --cartonID
      BEGIN
      	SELECT @cDropID = Value FROM @tExtUOM WHERE Variable = '@cDropID'
      	SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)
      	
      	IF @cPPACartonIDByPickDetailCaseID = '1'
      	BEGIN
      		SELECT @cPUOM = PD.UOM  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            WHERE PD.StorerKey = @cStorerKey  
               AND PD.CaseID = @cDropID  
               AND PD.ShipFlag <> 'Y' 
      	END
      	ELSE
      	BEGIN
      		SELECT @cPUOM = PD.UOM  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            WHERE PD.StorerKey = @cStorerKey  
               AND PD.DropID = @cDropID  
               AND PD.ShipFlag <> 'Y' 
      	END
      	 
         IF @cPUOM <> '2'
         BEGIN
         	SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = SUSER_NAME()
         END
      END
   END

   GOTO Quit

   Quit:

GO