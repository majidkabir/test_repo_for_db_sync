SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1631ExtInfo01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_ASN_Inquiry                                */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-03-06  1.0  ChewKP   Created                                    */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1631ExtInfo01] (    
    @nMobile      INT,           
    @nFunc        INT,           
    @cLangCode    NVARCHAR( 3),  
    @nStep        INT,           
    @nInputKey    INT,           
    @cStorerKey   NVARCHAR( 15), 
    @cReceiptKey  NVARCHAR( 10), 
    @cRefNo       NVARCHAR( 10), 
    @cOutInfo01   NVARCHAR( 60)  OUTPUT,
    @nErrNo       INT            OUTPUT, 
    @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @nVASLOC NVARCHAR(10) 
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''           
             
             
   IF @nFunc = 1631          
   BEGIN     
      
         IF @nStep = 1  -- Get Input Information   
         BEGIN           
              
         
            SET @cOutInfo01 = ''  
            SET @nVASLOC = 0 
            
            SELECT @nVASLOC = Count(RD.PutawayLoc) FROM ReceiptDetail RD WITH (NOLOCK) 
            INNER JOIN Loc Loc WITH (NOLOCK) ON LOC.Loc = RD.PutawayLoc 
            WHERE RD.ReceiptKey = @cReceiptKey
            AND LOC.LocationCategory = 'VAS'
            
            IF @nVASLOC > 0 
            BEGIN
               
               SET @cOutInfo01 = N'[急貨改包]' -- 'REPACK : Y'
            END
            ELSE 
            BEGIN
               SET @cOutInfo01 = '' --'REPACK : N'
            END
                      
         END      
                
   END          
          

            
       
END     

GO