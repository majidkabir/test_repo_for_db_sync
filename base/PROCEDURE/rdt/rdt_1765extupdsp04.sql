SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TM_ReplenTo_Confirm                                   */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Modifications log:                                                         */
/* Date        Rev  Author   Purposes                                         */
/* 24-08-2016  1.0  Ung      WMS-5740 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1765ExtUpdSP04] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @cUserName      NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cDropID        NVARCHAR( 20),    
   @nStep          INT,  
   @cTaskDetailKey NVARCHAR(10),  
   @nQTY           INT,  
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   IF @nStep = 4 OR -- SKU, QTY
      @nStep = 5    -- Reason code (short replen / balance replen later)
   BEGIN 
      DECLARE @nInputKey INT
      SELECT @nInputKey = InputKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cToLoc  NVARCHAR(10)   
         DECLARE @cCaseID NVARCHAR(20)   
         DECLARE @cUCCNo  NVARCHAR(20)   

         SET @cUCCNo = ''

         -- Get task info
         SELECT 
            @cToLoc = V_String1, -- due to OverrideLOC
            @cCaseID = V_UCC
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile

         -- Check if UCC scanned
         IF @cDropID = @cCaseID AND @cDropID <> '' AND @cCaseID <> ''
         BEGIN
            -- Get valid UCC 
            SELECT @cUCCNo = UCCNo
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cDropID
               AND Status IN ('1', '3')
         END
      
         -- Confirm
         EXEC rdt.rdt_TM_ReplenTo_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cTaskDetailKey,
            @cToLOC, 
            @cUCCNo, 
            @nQTY,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT
      END
   END

Quit:  
  
END    

GO