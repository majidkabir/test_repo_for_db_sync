SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtVal02                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking, print label                       */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 05-Mar-2018  ChewKP    1.0   WMS-3836 Created                              */
/* 18-May-2018  SPChin    1.1   INC0235582 - Bug Fixed                        */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtVal02]
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
   @cRefNo        NVARCHAR( 20), 
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
   @cReasonCode   NVARCHAR( 5), 
   @cSuggID       NVARCHAR( 18), 
   @cSuggLOC      NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPACode           NVARCHAR(10)       
          ,@nCasceCnt         INT      
          ,@nPallet           INT       
          ,@nCaseCnt          INT      
          ,@cPackKey          NVARCHAR(10)      
          ,@cABC              NVARCHAR(5)      
          ,@cPAStrategyKey01  NVARCHAR(10)       
          ,@cPAStrategyKey02  NVARCHAR(10)       
          ,@cPAStrategyKey03  NVARCHAR(10)       
          ,@cPAStrategyKey04  NVARCHAR(10)       
          ,@cPAStrategyKey05  NVARCHAR(10)    
          ,@nPutawayZoneCount INT
          ,@cPutAwayZone01    NVARCHAR(10)
          ,@cPutAwayZone02    NVARCHAR(10)
          ,@cPutAwayZone03    NVARCHAR(10)
          ,@cPutAwayZone04    NVARCHAR(10)
          ,@cPutAwayZone05    NVARCHAR(10)
          ,@nResult01         INT
          ,@nResult02         INT
          ,@nResult03         INT
          ,@nResult04         INT
          ,@nResult05         INT
          ,@cPAStrategyKey    NVARCHAR(10)   
          
          
          
   DECLARE @tPAStrategyList TABLE (PAStrategyKey NVARCHAR(10) )      
            
   
   IF @nFunc = 607 -- Return V7
   BEGIN  

    

      IF @nStep = 5 -- ID, LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND RecType = 'LOGIUT')
            BEGIN
               SET @cSuggLOC = '' 
               GOTO QUIT
            END   
            
            IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND ReceiptKey = @cReceiptKey
                        AND ToLoc = @cLOC)  
            BEGIN
               SET @nErrNo = 120402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
               GOTO Quit  
            END   

            
            
            SELECT @cPackKey = PackKey       
                  ,@cABC     = ABC      
            FROM dbo.SKU WITH (NOLOCK)      
            WHERE StorerKey = @cStorerKey      
            AND SKU = @cSKU       
                  
            SELECT @nPallet = Pallet       
                  ,@nCaseCnt = CaseCnt       
            FROM dbo.Pack WITH (NOLOCK)      
            WHERE PackKey = @cPackKey       
                  
            --SELECT @nQty '@nQty' , @nCaseCnt '@nCaseCnt'  ,@cABC '@cABC' , @nPallet '@nPallet'   
                  
                  
            IF @nQty < @nCaseCnt       
            BEGIN      
               SET @cPACode = 'LOGIRTN05'      
            END      
            ELSE IF @cABC = 'A' AND @nQty = @nPallet       
            BEGIN     
               SET @cPACode = 'LOGIRTN01'      
            END      
            ELSE IF @cABC = 'A' AND (@nQty < @nPallet AND @nQty >= @nCaseCnt )			--INC0235582      
            BEGIN      
               SET @cPACode = 'LOGIRTN02'      
            END      
            ELSE IF @cABC IN ('B','C') AND @nQty = @nPallet      
            BEGIN      
               SET @cPACode = 'LOGIRTN03'      
            END      
            ELSE IF @cABC IN ('B','C') AND (@nQty < @nPallet AND @nQty >= @nCaseCnt )	--INC0235582      
            BEGIN      
               SET @cPACode = 'LOGIRTN04'      
            END      
            
            
            
             -- Get putaway strategy      
            SELECT @cPAStrategyKey01 = ISNULL( Short, '')      
                  ,@cPAStrategyKey02 = ISNULL( UDF01, '')      
                  ,@cPAStrategyKey03 = ISNULL( UDF02, '')      
                  ,@cPAStrategyKey04 = ISNULL( UDF03, '')      
                  ,@cPAStrategyKey05 = ISNULL( UDF04, '')      
            FROM CodeLkup WITH (NOLOCK)      
            WHERE ListName = 'RDTExtPA'      
               AND Code = @cPACode      
               AND StorerKey = @cStorerKey      
                  
            IF ISNULL(@cPAStrategyKey01,'') <> ''       
               INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey01 )       
                     
            IF ISNULL(@cPAStrategyKey02,'') <> ''       
               INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey02 )       
                  
            IF ISNULL(@cPAStrategyKey03,'') <> ''       
               INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey03 )       
                  
            IF ISNULL(@cPAStrategyKey04,'') <> ''       
               INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey04 )       
                  
            IF ISNULL(@cPAStrategyKey05,'') <> ''       
               INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey05 )    
            
            SET @nResult01 = 0 
            SET @nResult02 = 0 
            SET @nResult03 = 0
            SET @nResult04 = 0 
            SET @nResult05 = 0 
            
            DECLARE C_PAStrategy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT PAStrategyKey       
            FROM @tPAStrategyList      
            ORDER BY PAStrategyKey       
                  
            OPEN C_PAStrategy        
            FETCH NEXT FROM C_PAStrategy INTO  @cPAStrategyKey      
            WHILE (@@FETCH_STATUS <> -1)        
            BEGIN        
                      
               IF EXISTS ( SELECT 1 FROM dbo.PutawayStrategyDetail WITH (NOLOCK)       
                           WHERE PutawayStrategyKey = @cPAStrategyKey )       
               BEGIN         
                  
                  SELECT 
                      @cPutAwayZone01     = PutAwayZone01,          
                      @cPutAwayZone02     = PutAwayZone02,          
                      @cPutAwayZone03     = PutAwayZone03,          
                      @cPutAwayZone04     = PutAwayZone04,          
                      @cPutAwayZone05     = PutAwayZone05           
                  FROM  PUTAWAYSTRATEGYDETAIL WITH (NOLOCK)          
                  WHERE PutAwayStrategyKey = @cPAStrategyKey    
                  
          
       
                  IF ISNULL(@cPutAwayZone01,'')  <> '' 
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                                     WHERE Facility = @cFacility
                                     AND PutawayZone = @cPutAwayZone01
                                     AND Loc = @cLoc ) 
                     BEGIN
                        SET @nResult01  = 1 
                     END
                  END
                  
                  IF ISNULL(@cPutAwayZone02,'')  <> '' 
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                                     WHERE Facility = @cFacility
                                     AND PutawayZone = @cPutAwayZone02
                                     AND Loc = @cLoc ) 
                     BEGIN
                        SET @nResult02  = 1 
                     END
                  END
                  
                  IF ISNULL(@cPutAwayZone03,'')  <> '' 
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                                     WHERE Facility = @cFacility
                                     AND PutawayZone = @cPutAwayZone03
                                     AND Loc = @cLoc ) 
                     BEGIN
                        SET @nResult03  = 1 
                     END
                  END
                  
                  IF ISNULL(@cPutAwayZone04,'')  <> '' 
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                                     WHERE Facility = @cFacility
                                     AND PutawayZone = @cPutAwayZone04
                                     AND Loc = @cLoc ) 
                     BEGIN
                        SET @nResult04  = 1 
                     END
                  END
                  
                  IF ISNULL(@cPutAwayZone05,'')  <> '' 
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                                     WHERE Facility = @cFacility
                                     AND PutawayZone = @cPutAwayZone05
                                     AND Loc = @cLoc ) 
                     BEGIN
                        SET @nResult05  = 1 
                     END
                  END
                  
                  
               END
               
               FETCH NEXT FROM C_PAStrategy INTO  @cPAStrategyKey      
            END
            CLOSE C_PAStrategy        
            DEALLOCATE C_PAStrategy     
      
            --SELECT @nResult01 '@nResult01' , @nResult02 '@nResult02' , @nResult03 '@nResult03' , @nResult04 '@nResult04' , @nResult05 '@nResult05'

            IF 1 NOT IN ( @nResult01, @nResult02, @nResult03, @nResult04, @nResult05 )
            BEGIN
               SET @nErrNo = 120401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPAZone
               GOTO Quit   
            END
            
            

         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO