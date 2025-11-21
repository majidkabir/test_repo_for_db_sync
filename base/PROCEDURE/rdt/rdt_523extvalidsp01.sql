SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP01                                 */  
/* Purpose: Validate  Location                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-05-21 1.0  ChewKP     SOS#340776                                */  
/* 2022-09-21 1.1  yeekung   Fix Params                                 */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_523ExtValidSP01] (  
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),  
   @cLOC             NVARCHAR( 10), 
   @cID              NVARCHAR( 18), 
   @cSKU             NVARCHAR( 20), 
   @nQTY             INT,  
   @cSuggestedLOC    NVARCHAR( 10),
   @cFinalLOC        NVARCHAR( 10),
   @cOption          NVARCHAR( 1),
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
IF @nFunc = 523  
BEGIN  
   
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    

       
    IF @nStep = '6'
    BEGIN

       SELECT @cSuggestedLOC = V_String13
       FROM rdt.rdtMobrec WITH (NOLOCK)
       WHERE Mobile = @nMobile
       
       IF RIGHT(@cSuggestedLOC,9 ) <> RIGHT(@cFinalLOC,9 )
       BEGIN
            SET @nErrNo = 93201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLoc'
            GOTO QUIT
       END
    END
    
    

   
END  
  
QUIT:  

 

GO