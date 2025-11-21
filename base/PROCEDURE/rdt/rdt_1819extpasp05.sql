SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1819ExtPASP05                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_PutawayByID                                */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2016-08-024  1.0  ChewKP   SOS#375490 Created                        */    
/************************************************************************/    

CREATE PROC [RDT].[rdt_1819ExtPASP05] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS  
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @cOrderKey NVARCHAR(10)
         , @cPutawayZone NVARCHAR(10) 
         --, @cLoc     NVARCHAR(10)
         , @cStyle     NVARCHAR(20) 
         , @cLocAisle  NVARCHAR(10) 
         , @cSuggestedLoc NVARCHAR(10) 
         , @cLocBay    NVARCHAR(10) 

            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
   --SET @cLoc = ''         
   

   
   IF @nFunc = 1819          
   BEGIN     
         
         --IF @nStep = 1
         --BEGIN       
            SET @cFitCasesInAisle = 'Y'
        
            
            SELECT @cStyle = SKU.Style , 
                   @cFromLoc = LLI.Loc
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
            WHERE LLI.StorerKey = @cStorerKey 
            AND LLI.ID = @cID
            GROUP BY SKU.Style, LLI.Loc
            ORDER BY SKU.Style, SUM(LLI.Qty) DESC
            
            SELECT TOP 1 @cLocAisle = Loc.LocAisle
                        ,@cFacility = Loc.Facility 
                        ,@cLocBay   = Loc.LocBay 
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc
            WHERE LLI.StorerKey = @cStorerKey 
            AND SKU.Style = @cStyle
            AND LLI.Loc <> @cFromLOC 
            AND LLI.Qty - (LLI.QtyAllocated + LLI.QtyPicked) > 0 
            AND Loc.Facility = @cFacility 
            --AND ISNULL(Loc.Floor,'')  = '1'
            ORDER BY Loc.LocAisle,  Loc.LocLevel
            
            
            
            IF ISNULL(@cLocAisle,'')  = ''
            BEGIN
               SET @cSuggLOC = ''
               GOTO QUIT 
            END
            
            SELECT TOP 1 @cSuggestedLoc = LOC.loc                            
            FROM LOC WITH (NOLOCK)   
            LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Loc = Loc.Loc)   
            WHERE LOC.Facility = @cFacility
            AND Loc.LocAisle = @cLocAisle               
            GROUP BY LOC.LocBay, LOC.PALogicalLoc, LOC.LOC, Loc.Floor, Loc.LocLevel
            HAVING SUM( ISNULL(LotxLocxID.Qty,0) - ISNULL(LotxLocxID.QtyPicked,0))= 0 
            AND SUM(ISNULL(LotxLocxID.PendingMoveIn,0) ) = 0
            AND SUM(ISNULL(LotxLocxID.QtyExpected,0)) = 0
            AND ISNULL(Loc.Floor,'')  = '1'
            AND Loc.LocLevel IN ( '2', '3', '4', '5' , '6' ) 
            AND Loc.LocBay = @cLocBay 
            ORDER BY LOC.LocBay, LOC.PALogicalLoc , LOC.LOC
            
            IF ISNULL(@cSuggestedLoc,'')  = '' 
            BEGIN 
               SELECT TOP 1 @cSuggestedLoc = LOC.loc                            
               FROM LOC WITH (NOLOCK)   
               LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Loc = Loc.Loc)   
               WHERE LOC.Facility = @cFacility
               AND Loc.LocAisle = @cLocAisle               
               GROUP BY LOC.LocBay, LOC.PALogicalLoc, LOC.LOC, Loc.Floor, Loc.LocLevel
               HAVING SUM( ISNULL(LotxLocxID.Qty,0) - ISNULL(LotxLocxID.QtyPicked,0))= 0 
               AND SUM(ISNULL(LotxLocxID.PendingMoveIn,0) ) = 0
               AND SUM(ISNULL(LotxLocxID.QtyExpected,0)) = 0
               AND ISNULL(Loc.Floor,'')  = '1'
               AND Loc.LocLevel IN ( '2', '3', '4', '5' , '6' ) 
               ORDER BY LOC.LocBay, LOC.PALogicalLoc , LOC.LOC
            
               IF ISNULL(@cSuggestedLoc,'')  = '' 
               BEGIN 
                  SET @cSuggLOC = ''
                  GOTO QUIT 
               END
               ELSE 
               BEGIN
                   SET @cSuggLOC = ISNULL(@cSuggestedLoc,'') 
                   GOTO QUIT 
               END
            END
            ELSE 
            BEGIN
--                INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)  
--                VALUES (@cStorerKey, '', '', @cFromLoc, @cFroID, @cSuggestedLoc, @cFroID, SUSER_SNAME(), @nQTY, '')  
--                  
--                
--                
--                IF @@ERROR <> 0  
--                BEGIN  
--                        SET @nErrNo = 97701
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsRFPAFail
--                        GOTO RollbackTran  
--                END  
                     
               SET @cSuggLOC = ISNULL(@cSuggestedLoc,'') 
                            
             
               
            END

            
         --END      
                
   END          
          

            
QUIT:       
END     


GO