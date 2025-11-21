SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_608ExtInfo01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_TM_TotePicking                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2016-08-08  1.0  ChewKP   SOS#374476 Created                         */    
/* 2022-09-08  1.1  Ung      WMS-20348 Expand RefNo to 60 chars         */
/************************************************************************/    

CREATE   PROC [RDT].[rdt_608ExtInfo01] (    
  @nMobile       INT,           
  @nFunc         INT,           
  @cLangCode     NVARCHAR( 3),  
  @nStep         INT,           
  @nAfterStep    INT,           
  @nInputKey     INT,           
  @cFacility     NVARCHAR( 5),  
  @cStorerKey    NVARCHAR( 15), 
  @cReceiptKey   NVARCHAR( 10), 
  @cPOKey        NVARCHAR( 10), 
  @cRefNo        NVARCHAR( 60), 
  @cID           NVARCHAR( 18), 
  @cLOC          NVARCHAR( 10), 
  @cMethod       NVARCHAR( 1),  
  @cSKU          NVARCHAR( 20), 
  @nQTY          INT,           
  @cLottable01   NVARCHAR( 18), 
  @cLottable02   NVARCHAR( 18), 
  @cLottable03   NVARCHAR( 18), 
  @dLottable04   DATETIME,      
  @dLottable05   DATETIME,      
  @cLottable06   NVARCHAR( 30), 
  @cLottable07   NVARCHAR( 30), 
  @cLottable08   NVARCHAR( 30), 
  @cLottable09   NVARCHAR( 30), 
  @cLottable10   NVARCHAR( 30), 
  @cLottable11   NVARCHAR( 30), 
  @cLottable12   NVARCHAR( 30), 
  @dLottable13   DATETIME,      
  @dLottable14   DATETIME,      
  @dLottable15   DATETIME,      
  @cRDLineNo     NVARCHAR( 10), 
  @cExtendedInfo NVARCHAR(20)  OUTPUT, 
  @nErrNo        INT           OUTPUT, 
  @cErrMsg       NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @cOrderKey NVARCHAR(10)
         , @cPutawayZone NVARCHAR(10) 
         --, @cLoc     NVARCHAR(10)
         
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
   SET @cLoc = ''         
   
   
   IF @nFunc = 608          
   BEGIN     

         
         IF @nStep = 4
         BEGIN       
            
            SELECT @cLoc = V_String28 
            FROM rdt.rdtMobrec WITH (NOLOCK) 
            WHERE Mobile = @nMobile
            
            SELECT @cPutawayZone = PutawayZone
            FROM dbo.Loc WITH (NOLOCK) 
            WHERE Facility = @cFacility
            AND Loc = @cLoc
            
            SET @cExtendedInfo = 'ZONE:' +  @cPutawayZone
         END      
                
   END          
          

            
       
END     

GO