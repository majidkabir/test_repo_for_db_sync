SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_511ExtUpd04                                     */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-05-20 1.0  James      WMS13214. Created                         */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_511ExtUpd04] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cFromID        NVARCHAR( 18), 
   @cFromLOC       NVARCHAR( 10), 
   @cToLOC         NVARCHAR( 10), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   
   DECLARE @cLocationType     NVARCHAR( 10)
   DECLARE @cLocationCategory NVARCHAR( 10)
   DECLARE @bSuccess          INT
   
   IF @nFunc = 511 -- Move by ID
   BEGIN  
      IF @nStep = 3 -- ToLOC
      BEGIN
         --ops move the pallet to AGV stage in_loc 
         SELECT @cLocationType = LocationType, 
                @cLocationCategory = LocationCategory
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE Loc = @cToLOC 
         AND   Facility = @cFacility
         
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE LISTNAME = 'AGVSTG'
                     AND   Code = @cLocationType
                     AND   Storerkey = @cStorerKey) AND 
            EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE LISTNAME = 'AGVCAT'
                     AND   Code = @cLocationCategory
                     AND   Storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 0
            EXEC [dbo].[isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound]
                  @c_StorerKey   = @cStorerKey
                , @c_PalletId    = @cFromID
                , @c_Facility    = @cFacility
                , @b_Debug       = 0
                , @b_Success     = @bSuccess OUTPUT  
                , @n_Err         = @nErrNo  OUTPUT  
                , @c_ErrMsg      = @cErrMsg OUTPUT  
            
            IF @nErrNo <> 0 
            BEGIN
               SET @nErrNo = 152801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AGV API Error
               GOTO Quit
            END

         END
      END
   END  
  
Quit:  

END

GO