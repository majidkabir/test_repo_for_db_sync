SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/            
/* Store procedure: rdt_1768ExtInfo01                                   */            
/* Copyright      : IDS                                                 */            
/*                                                                      */            
/* Purpose: Show total qty scanned on tm cc sku                         */            
/*                                                                      */            
/* Called from:                                                         */            
/*                                                                      */            
/* Exceed version: 5.4                                                  */            
/*                                                                      */            
/* Modifications log:                                                   */            
/*                                                                      */            
/* Date       Rev  Author   Purposes                                    */            
/* 2015-10-01 1.0  James    SOS350672 Created                           */            
/* 2020-01-10 1.1  James    WMS-11550 Add Lot06-Lot15 (james01)         */       
/* 2022-01-20 1.2  YeeKung  JSM-47364 Fix qty change after esc (yeekung01)*/     
/************************************************************************/            
            
CREATE PROCEDURE [RDT].[rdt_1768ExtInfo01]            
   @nMobile          INT,         
   @nFunc            INT,         
   @cLangCode        NVARCHAR( 3),         
   @nStep            INT,         
   @nInputKey        INT,         
   @cStorerKey       NVARCHAR( 15),         
   @cTaskDetailKey   NVARCHAR( 10),         
   @cCCKey           NVARCHAR( 10),         
   @cCCDetailKey     NVARCHAR( 10),         
   @cLoc             NVARCHAR( 10),         
   @cID              NVARCHAR( 18),         
   @cSKU             NVARCHAR( 20),         
   @nActQTY          INT,          
   @cLottable01      NVARCHAR( 18),         
   @cLottable02      NVARCHAR( 18),         
   @cLottable03      NVARCHAR( 18),         
   @dLottable04      DATETIME,         
   @dLottable05      DATETIME,         
   @cLottable06      NVARCHAR( 30),         
   @cLottable07      NVARCHAR( 30),         
   @cLottable08      NVARCHAR( 30),         
   @cLottable09      NVARCHAR( 30),         
   @cLottable10      NVARCHAR( 30),         
   @cLottable11      NVARCHAR( 30),         
   @cLottable12      NVARCHAR( 30),         
   @dLottable13      DATETIME,         
   @dLottable14      DATETIME,         
   @dLottable15      DATETIME,        
   @cExtendedInfo    NVARCHAR( 20) OUTPUT         
        
AS            
BEGIN            
   SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET ANSI_NULLS OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
               
   DECLARE @cScan    NVARCHAR( 20)        
        
   SELECT @cScan = O_Field15 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile        
   SET @cScan = RTRIM( SUBSTRING( @cScan, 10, 5))        
        
   SET @cExtendedInfo = 'TTL QTY: '        
         
   IF @nInputKey=0 --(yeekung01)    
   BEGIN      
      IF ISNULL( @cScan, '') = ''        
         SET @cExtendedInfo = @cExtendedInfo + '1'        
      ELSE      
         SET @cExtendedInfo = @cExtendedInfo + @cScan      
   END      
   ELSE      
   BEGIN    
      IF @nStep =2  
      BEGIN    
         IF ISNULL( @cScan, '') = ''        
            SET @cExtendedInfo = @cExtendedInfo + '1'        
         ELSE         
            IF RDT.rdtIsValidQTY( @cScan, 1) = 1        
            BEGIN        
               SET @cScan = CAST( @cScan AS INT) + 1        
               SET @cExtendedInfo = @cExtendedInfo + @cScan         
            END      
      END    
   END      
QUIT:            
END -- End Procedure 

GO