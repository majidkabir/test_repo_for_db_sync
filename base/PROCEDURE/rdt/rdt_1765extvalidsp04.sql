SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1765ExtValidSP04                                */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Validate qty must match with suggested qty                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-08-18  1.0  James    WMS-14152. Created                         */ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1765ExtValidSP04] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @cUserName      NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cDROPID        NVARCHAR( 20),    
   @nStep          INT,  
   @cTaskDetailKey NVARCHAR(10),  
   @nQty           INT,  
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @nSuggQty       INT
   DECLARE @cToLoc         NVARCHAR( 10)
   DECLARE @cSuggToLoc     NVARCHAR( 10)
   DECLARE @cTempSKU       NVARCHAR( 20)
   DECLARE @cLocationType  NVARCHAR( 10)
   DECLARE @cLocationFlag  NVARCHAR( 10)
   DECLARE @cCommingleSku  NVARCHAR( 1)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   
   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   
   SELECT @nSuggQty = Qty, 
          @cTaskSKU = Sku, 
          @cSuggToLoc = ToLoc
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey 

   IF @nStep = 3
   BEGIN
      SELECT @cToLoc = I_Field04
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
      
      IF @cToLoc = @cSuggToLoc
         GOTO Quit 
      
      SELECT 
         @cLocationType = LocationType,
         @cLocationFlag = LocationFlag,
         @cCommingleSku = CommingleSku
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLoc
      AND   Facility = @cFacility
                        
      IF @cLocationType = 'CASE' AND @cLocationFlag = 'NONE'
      BEGIN
         -- If Loc not allow mix sku
         IF @cCommingleSku = '0'
         BEGIN
            -- Check only if loc is not empty
            SELECT TOP 1 @cTempSKU = LLI.Sku
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Loc = @cToLoc
            AND   LOC.Facility = @cFacility
            AND   LLI.QTY-LLI.QTYPicked > 0
            ORDER BY 1
                  
            IF @@ROWCOUNT > 0
            BEGIN
               IF @cTaskSKU <> @cTempSKU
               BEGIN  
                  SET @nErrNo = 157252  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix Sku
                  GOTO Quit    
               END
            END
         END
      END
      ELSE
      BEGIN  
         SET @nErrNo = 157253  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid To Loc  
         GOTO Quit    
      END
   END
         
   IF @nStep = 4 
   BEGIN 
   	IF @nQty <> @nSuggQty
      BEGIN  
         SET @nErrNo = 157251  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Not Match'  
         GOTO Quit 
      END  
   END
END   

Quit:
 

GO