SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store procedure: rdt_1723DecodCtnSP02                                      */    
/* Copyright: LF Logistics                                                    */    
/*                                                                            */    
/* Purpose: Decode carton id                                                  */    
/*                                                                            */    
/* Called from: rdtfnc_PalletConsolidate_SSCC                                 */    
/*                                                                            */    
/*                                                                            */    
/* Date        Author    Ver.  Purposes                                       */    
/* 12-10-2021  Chermaine 1.0   WMS-18008 - Created                            */   
/* 10-01-2023  YeeKung   1.1   WMS-20759 Add qty picked (yeekung01)           */
/******************************************************************************/    
    
CREATE    PROC [RDT].[rdt_1723DecodCtnSP02] (    
   @nMobile         INT,     
   @nFunc           INT,     
   @cLangCode       NVARCHAR( 3),     
   @nStep           INT,      
   @nInputKey       INT,     
   @cStorerKey      NVARCHAR( 15),     
   @cFromID         NVARCHAR( 18),     
   @cToID           NVARCHAR( 18),     
   @cOption         NVARCHAR( 10),     
   @cSKU            NVARCHAR( 20)  OUTPUT,     
   @nQty            INT            OUTPUT,     
   @cCartonBarcode  NVARCHAR( 60)  OUTPUT,     
   @nErrNo          INT            OUTPUT,     
   @cErrMsg         NVARCHAR( 20)  OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cBarcode    NVARCHAR( 60),    
           @cUPC        NVARCHAR( 30),    
           @cItemClass  NVARCHAR( 10),    
           @cFacility   NVARCHAR( 5)    
    
   DECLARE @nStartPos   INT,    
           @nEndPos     INT    
    
   DECLARE @cErrMsg1    NVARCHAR( 20),     
           @cErrMsg2    NVARCHAR( 20),    
           @cErrMsg3    NVARCHAR( 20),     
           @cErrMsg4    NVARCHAR( 20),    
           @cErrMsg5    NVARCHAR( 20)    
    
   DECLARE @nQTY_Avail     INT    
   DECLARE @nQTY_Alloc     INT    
   DECLARE @nQTY_Pick      INT    
   DECLARE @nPUOM_Div      INT    
   DECLARE @nQTY_Scanned   INT    
   DECLARE @nBalQty        INT    
   DECLARE @nMBalQty       INT    
   DECLARE @nPBalQty       INT    
   DECLARE @cUserName      NVARCHAR( 20)    
   DECLARE @cPUOM          NVARCHAR( 10)    
   DECLARE @cLottable01    NVARCHAR( 18)    
   DECLARE @cLot           NVARCHAR( 10)    
   DECLARE @cBatchNo       NVARCHAR( 20)    
   DECLARE @cInField12     NVARCHAR( 60)    
   DECLARE @cInField14     NVARCHAR( 60)   
   DECLARE @cSSCC          NVARCHAR( 20)   
   
   SELECT 
      @cFacility = Facility
   FROM rdt.rdtmobrec WITH (NOLOCK)
   WHERE mobile = @nMobile       
         
   IF @nStep  in(4, 6) --cartonID
   BEGIN
   	IF @nInputKey = 1 -- ENTER    
      BEGIN
         IF ISNULL(@cCartonBarcode,'')<>''
         BEGIN
      	   IF SUBSTRING(@cCartonBarcode,1,2)='95'
      	   BEGIN
      		   --(95)030244893132694952   if len after'95' <> 18 prompt error
               IF LEN(@cCartonBarcode)-2 <> 18
               BEGIN
                  SET @nErrNo = 176801 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr
                  goto quit
               END
                  	
               SET @cCartonBarcode = SUBSTRING( @cCartonBarcode,  3, 18)

               DECLARE @cLottable09 NVARCHAR(30)

      	      -- Get SSCC
               SELECT TOP 1 @cLottable09 = LA.lottable09
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN lotattribute LA (NOLOCK) ON ( LLI.lot=LA.lot and LLI.SKU=LA.SKU)
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.ID = @cFromID 
               AND   LLI.SKU = @CSKU
               AND   LLI.Qty > 0
               AND   LLI.Qtypicked > 0

               IF NOT EXISTS (SELECT 1 from UCC (NOLOCK)
                              WHERE UCCNO=@cCartonBarcode
                              AND SKU=@cSKU
                              AND Userdefined03=@cLottable09
                              AND storerkey=@cStorerKey)
               BEGIN
                  SET @nErrNo = 176801 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr
                  GOTO QUIT
               END

                IF EXISTS (SELECT 1 from rdt.rdtDPKLog (NOLOCK)
                              WHERE caseid=@cCartonBarcode
                              AND fromid=@cFromID
                              AND dropid=@cToID) --(yeekung01)
               BEGIN
                  SET @nErrNo = 176807
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCScanned
                  GOTO QUIT
               END

      	   END    
            ELSE
            BEGIN
      		   SET @nErrNo = 176805
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SSCC
               GOTO Quit  
      	   END
         END
      END
   END 

   IF @nStep = 8 --SSCC
   BEGIN
   	IF @nInputKey = 1 -- ENTER    
      BEGIN
      	IF left( @cCartonBarcode,2) = '00' 
      	BEGIN
      		--IF LEN (@cCartonBarcode) > 18
            IF SUBSTRING( @cCartonBarcode,21,2) = '93'
            BEGIN

      		   SET @cCartonBarcode = SUBSTRING( @cCartonBarcode,  3, 18)
      	
      	      -- Get SSCC
               SELECT TOP 1 @cSSCC = LA.Lottable09, 
                              @cSKU = LLI.SKU,
                              @cLot = LLI.Lot
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.ID = @cFromID 
               AND   LLI.Qty > 0
               AND   LLI.Qtypicked > 0
               AND   LOC.Facility = @cFacility
         
         
               IF @cSSCC <> @cCartonBarcode
               BEGIN
                  SET @nErrNo = 176802
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SSCC NotMatch
                  GOTO Quit    
               END

               IF EXISTS (SELECT 1
                           FROM SKU (NOLOCK) 
                           WHERE SKU = @cSKU
                           AND storerkey= @cStorerKey
                           AND Lottable09Label ='SSCC') --(yeekung01)
               BEGIN
         
                  IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND Userdefined03 = @cCartonBarcode)
                  BEGIN
         	         IF EXISTS (SELECT 1
                                 FROM dbo.PickDetail PD WITH (NOLOCK) 
                                 JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                                 WHERE PD.StorerKey = @cStorerKey
                                 AND   PD.ID = @cFromID 
                                 AND   PD.Lot = @cLot
                                 AND   PD.SKU = @cSKU
                                 AND   PD.Status < '9'
                                 AND   LOC.Facility = @cFacility )
                     BEGIN
            	         SET @cCartonBarcode =  @cCartonBarcode
                     END
                     ELSE
                     BEGIN
            	         SET @cCartonBarcode = ''
                     END
                  END
                  ELSE
                  BEGIN
                     SET @cCartonBarcode = ''
                  END
               END
               ELSE
               BEGIN
                  SET @cCartonBarcode =  @cCartonBarcode
               END
            END
            ELSE
      	   BEGIN
      		   SET @nErrNo = 176806
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SSCC
               GOTO Quit    
      	   END
      	END
      	ELSE
      	BEGIN
      		SET @nErrNo = 176804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SSCC
            GOTO Quit  
      	END
      END
   END 
    
Quit:    
    
END 


GO