SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store procedure: rdt_1723DecodCtnSP01                                      */    
/* Copyright: LF Logistics                                                    */    
/*                                                                            */    
/* Purpose: Decode carton id                                                  */    
/*                                                                            */    
/* Called from: rdtfnc_PalletConsolidate_SSCC                                 */    
/*                                                                            */    
/*                                                                            */    
/* Date        Author    Ver.  Purposes                                       */    
/* 30-03-2016  James     1.0   SOS357366 - Created                            */    
/* 29-08-2016  James     1.1   Add decode logic for step 8 (james01)          */    
/* 02-07-2018  James     1.2   WMS5526-Add new decode logic (james02)         */   
/* 02-07-2020  YeeKung   1.3   WMS13961-Add new decode logic (yeekung01)      */    
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_1723DecodCtnSP01] (    
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
       
       
   SELECT @cFacility = Facility,     
          @cUserName = UserName,    
          @cPUOM = V_UOM,    
          @cInField12 = I_Field12,    
          @cInField14 = I_Field14    
   FROM RDT.RDTMOBREC WITH (NOLOCK)     
   WHERE Mobile = @nMobile    
    
   IF @nStep IN (4, 6) -- Carton id    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         IF @cCartonBarcode LIKE 'C%'    
         BEGIN    
            SET @cCartonBarcode = SUBSTRING( @cCartonBarcode, 2, 20)    
            GOTO Quit    
         END    
    
         IF @cCartonBarcode = 'NA'    
         BEGIN    
            IF @cOption NOT IN ('1', '2', '3')    
               GOTO Quit    
    
            SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),    
                   @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),    
                   @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)     
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)    
            WHERE LLI.StorerKey = @cStorerKey     
            AND   LLI.ID = @cFromID     
            AND   LOC.Facility = @cFacility    
            AND   SKU = @cSKU    
    
            SET @nQTY_Avail = CASE WHEN @cOption <> '1' THEN 0 ELSE @nQTY_Avail END    
            SET @nQTY_Alloc = CASE WHEN @cOption <> '2' THEN 0 ELSE @nQTY_Alloc END    
            SET @nQTY_Pick  = CASE WHEN @cOption <> '3' THEN 0 ELSE @nQTY_Pick END    
    
            SET @nBalQty = CASE WHEN @cOption = '1' THEN @nQTY_Avail     
                                WHEN @cOption = '2' THEN @nQTY_Alloc     
                                WHEN @cOption = '3' THEN @nQTY_Pick     
                           END    
    
            SELECT @nQTY_Scanned = ISNULL( SUM( QtyMove), 0)     
            FROM rdt.rdtDPKLog WITH (NOLOCK)     
            WHERE FromID = @cFromID    
            AND   DropID = @cToID    
            AND   SKU = @cSKU    
            AND   UserKey = @cUserName    
  
            SET @nErrNo=-2  
  
            GOTO Quit     
         END    
             
         -- During consolidation, possible to have 1 bottle with no case    
         -- So no barcode to scan then need harcode a value for it    
         IF @cCartonBarcode = 'HNA'    
         BEGIN    
            -- Get SKU QTY    
            SET @nQTY_Avail = 0     
            SET @nQTY_Alloc = 0    
            SET @nQTY_Pick = 0    
    
            -- Get required qty    
            SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),    
                     @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),    
                     @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)     
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)    
            WHERE LLI.StorerKey = @cStorerKey     
            AND   LLI.ID = @cFromID     
            AND   LOC.Facility = @cFacility    
            AND   SKU = @cSKU    
    
            SELECT @nPUOM_Div = CAST( Pack.CaseCNT AS INT)     
            FROM dbo.SKU S (NOLOCK)     
            JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)    
            WHERE StorerKey = @cStorerKey    
            AND SKU = @cSKU    
    
            SET @nQTY_Avail = CASE WHEN @cOption <> '1' THEN 0 ELSE @nQTY_Avail END    
            SET @nQTY_Alloc = CASE WHEN @cOption <> '2' THEN 0 ELSE @nQTY_Alloc END    
            SET @nQTY_Pick  = CASE WHEN @cOption <> '3' THEN 0 ELSE @nQTY_Pick END    
    
            -- Get scanned qty    
            SELECT @nQTY_Scanned = ISNULL( SUM( QtyMove), 0)     
            FROM rdt.rdtDPKLog WITH (NOLOCK)     
            WHERE FromID = @cFromID    
            AND   DropID = @cToID    
            AND   SKU = @cSKU    
            AND   UserKey = @cUserName    
    
            SET @nBalQty = CASE WHEN @cOption = '1' THEN @nQTY_Avail     
                                 WHEN @cOption = '2' THEN @nQTY_Alloc     
                                 WHEN @cOption = '3' THEN @nQTY_Pick     
                           END    
    
            SET @nBalQty = @nBalQty - @nQTY_Scanned    
    
            -- Only the remainder can process    
            -- For example 1 pallet 11 bottle, casecnt = 2, remainder = 1    
            IF @nBalQty % @nPUOM_Div = 0 OR @nBalQty >= @nPUOM_Div    
            BEGIN    
               SET @nErrNo = 98465    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOTLAST BOTTLE    
               GOTO Quit    
            END      
    
            IF @nStep = 4    
            BEGIN    
               IF @cInField14 = ''    
                  SET @nErrNo = -1    
    
               EXEC rdt.rdtSetFocusField @nMobile, 14    
            END    
            ELSE    
            BEGIN    
               IF @cInField12 = ''    
                  SET @nErrNo = -1    
    
               EXEC rdt.rdtSetFocusField @nMobile, 12    
            END    
    
            GOTO Quit                 
         END    
        
         SELECT @cItemClass = ItemClass    
         FROM dbo.SKU WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND   SKU = @cSKU    
             
         IF SUBSTRING( @cCartonBarcode, 1, 3) = '010' AND     
            LEN( RTRIM( @cCartonBarcode)) > 15    
         BEGIN    
            SET @cUPC = SUBSTRING( @cCartonBarcode, 4, 13)    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.UPC WITH (NOLOCK)     
                            WHERE StorerKey = @cStorerKey    
                            AND   UPC = @cUPC    
                            AND   SKU = @cSKU)    
            BEGIN    
               SET @nErrNo = 0    
               SET @cErrMsg1 = rdt.rdtgetmessage( 98451, @cLangCode, 'DSP')     
               SET @cErrMsg2 = ''    
               SET @cErrMsg3 = ''    
               SET @cErrMsg4 = ''    
               SET @cErrMsg5 = ''    
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1    
               IF @nErrNo = 1    
                  SET @cErrMsg1 = ''    
    
               -- Return an error to stop the subsequent process    
               SET @nErrNo = 98451    
    
               GOTO Quit    
            END    
         END    
    
         IF SUBSTRING( @cCartonBarcode, 1, 2) = '01' AND     
            SUBSTRING( @cCartonBarcode, 3, 1) <> '0' AND     
            LEN( RTRIM( @cCartonBarcode)) > 15    
         BEGIN    
            SET @cUPC = SUBSTRING( @cCartonBarcode, 3, 14)    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.UPC WITH (NOLOCK)     
                            WHERE StorerKey = @cStorerKey    
                            AND   UPC = @cUPC    
                            AND   SKU = @cSKU)    
            BEGIN    
               SET @nErrNo = 0    
               SET @cErrMsg1 = rdt.rdtgetmessage( 98452, @cLangCode, 'DSP')     
               SET @cErrMsg2 = ''    
               SET @cErrMsg3 = ''    
               SET @cErrMsg4 = ''    
               SET @cErrMsg5 = ''    
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1    
               IF @nErrNo = 1    
                  SET @cErrMsg1 = ''    
    
               -- Return an error to stop the subsequent process    
               SET @nErrNo = 98452    
    
               GOTO Quit    
            END    
         END    
    
         IF SUBSTRING( @cCartonBarcode, 1, 1) = 'C'    
         BEGIN    
            SET @cCartonBarcode = SUBSTRING( RTRIM( @cCartonBarcode), 2, LEN( RTRIM( @cCartonBarcode)) - 1)    
            GOTO Quit    
         END    
    
         IF @cCartonBarcode <> '' AND @cCartonBarcode <> 'NA'  AND @cItemClass = '001'   
         BEGIN    
  
            SET @cBarcode = @cCartonBarcode    
  
            IF ((CHARINDEX ( '[10' , @cBarcode) <> 0))  
            BEGIN  
   
               /*    
               Logic to decode the carton ID.    
               01032459900099242188899[10907705    
               1. If can detect [10 in scanned data, take all characters after [10 as carton ID (max 20 characters)    
               2. Else try detect 10 at position 17 of scanned data, and take all characters after 10 until next [ as carton ID    
              -- 3. Else try detect 10 at position 16 of scanned data, and take all characters after 10 as carton ID (max 20 characters)    
               4. Else prompt error ôCTN ID No Read, Key Inö    
               */    
    
               -- Logic 1    
               SET @nStartPos =  CHARINDEX ( '[10' , @cBarcode)     
  
               IF ( @nStartPos + 3) > 3     
               BEGIN    
                  SET @nStartPos = @nStartPos + 3  -- start grep the data after value [10    
                  SET @nEndPos = CHARINDEX ( '[' , @cBarcode, @nStartPos + 1)    
                  IF @nEndPos > 0  
                  BEGIN    
                     SET @cBatchNo = SUBSTRING( @cBarcode, @nStartPos, @nEndPos - @nStartPos)    
                  END  
                  ELSE   
                  BEGIN  
            SET @cBatchNo = SUBSTRING( @cBarcode, @nStartPos, 20)    
                  END  
               END          
                 
               IF  SUBSTRING( @cBarcode, 17, 2) = '21'  
                  set @nStartPos = 19     
               SET @nEndPos=  CHARINDEX ( '[10' , @cBarcode)        
                 
               SET @cCartonBarcode= SUBSTRING( @cBarcode, @nStartPos,(@nEndPos-@nStartPos))                
            END  
            ELSE IF ((CHARINDEX ( '[21' , @cBarcode) <> 0))  
            BEGIN  
  
               /*    
               Logic to decode the carton ID.    
    
               1. If can detect [21 in scanned data, take all characters after [21 as carton ID (max 20 characters)    
               2. Else try detect 21 at position 17 of scanned data, and take all characters after 21 until next [ as carton ID    
               3. Else try detect 21 at position 16 of scanned data, and take all characters after 21 as carton ID (max 20 characters)    
               4. Else prompt error ôCTN ID No Read, Key Inö    
               */    
                
               -- Logic   
               SET @nStartPos =  CHARINDEX ( '[21' , @cBarcode)     
    
               IF ( @nStartPos + 3) > 3     
               BEGIN    
                  SET @nStartPos = @nStartPos + 3  -- start grep the data after value [21     
                  SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, 20)    
               END  
  
               IF SUBSTRING( @cBarcode, 17, 2) = '10'    
                  SET @nStartPos = 19     
               SET @nEndPos=CHARINDEX ( '[21' , @cBarcode)     
                 
               SET @cBatchNo= SUBSTRING( @cBarcode, (@nStartPos), (@nEndPos-@nStartPos))    
  
            END    
            ELSE  
            BEGIN  
    
               -- Logic 2    
               IF SUBSTRING( @cBarcode, 17, 2) = '21'    
                  SET @nStartPos = 17    
               ELSE IF SUBSTRING( @cBarcode, 16, 2) = '21'    
                  SET @nStartPos = 16    
               ELSE    
                  SET @nStartPos = 0     
    
               SET @nEndPos = CHARINDEX ( '[' , @cBarcode)     
    
               IF @nStartPos = 17 AND ( @nEndPos > @nStartPos)    
               BEGIN    
                  SET @nStartPos = @nStartPos + 2  -- start grep the data after value 21    
                  SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, @nEndPos - @nStartPos)   
                  SET @cBatchNo= SUBSTRING( @cBarcode, @nStartPos, @nEndPos - @nStartPos)    
               END    
    
               -- Logic 3    
               ELSE IF @nStartPos = 16    
               BEGIN    
                  SET @nStartPos = @nStartPos + 2  -- start grep the data after value 21    
                  SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, 20)   
                  SET @cBatchNo= SUBSTRING( @cBarcode, @nStartPos, 20)     
               END    
               ELSE  
               BEGIN  
                  SET @cCartonBarcode=''  
                  SET @cBatchNo=''  
               END  
            END   
  
            IF @cCartonBarcode=''  
            BEGIN  
                   
               SET @nErrNo = 0    
               SET @cErrMsg1 = rdt.rdtgetmessage( 98453, @cLangCode, 'DSP')     
               SET @cErrMsg2 = rdt.rdtgetmessage( 98454, @cLangCode, 'DSP')     
               SET @cErrMsg3 = ''    
               SET @cErrMsg4 = ''    
               SET @cErrMsg5 = ''    
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2    
               IF @nErrNo = 1    
               BEGIN    
                  SET @cErrMsg1 = ''    
                  SET @cErrMsg2 = ''    
               END    
    
               -- Return an error to stop the subsequent process    
               SET @nErrNo = 98453   
            END  
  
            -- Check to pallet ( if to pallet already exists)      
            IF EXISTS ( SELECT 1       
               FROM dbo.PICKDETAIL WITH (NOLOCK)      
               WHERE StorerKey = @cStorerKey      
               AND   ID = @cFromID      
               AND   Status < '9'      
               AND   Sku = @cSKU)      
            BEGIN                  
               -- 1 Pallet 1 orders      
               SELECT TOP 1 @cLot = LOT      
               FROM dbo.PICKDETAIL WITH (NOLOCK)      
               WHERE StorerKey = @cStorerKey      
               AND   ID = @cfromID      
               AND   Status < '9'      
               AND   Sku = @cSKU      
               ORDER BY 1      
                     
               SELECT @cLottable01 = Lottable01      
               FROM dbo.LOTATTRIBUTE WITH (NOLOCK)      
               WHERE Lot = @cLot      
      
               IF @cBatchNo <> @cLottable01      
               BEGIN      
                  SET @nErrNo = 0      
                  SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 98463, @cLangCode, 'DSP'), 7, 14)        
      
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2      
                  IF @nErrNo = 1      
                  BEGIN      
                     SET @cErrMsg1 = ''      
                     SET @cErrMsg2 = ''      
                  END      
      
                  GOTO Quit      
               END        
            END  
         END    
      END  
   END    
    
   -- (james01)    
   IF @nStep = 8 -- SSCC    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         -- Remember current barcode value    
         SET @cBarcode = @cCartonBarcode    
    
         -- SSCC    
         IF LEN( @cBarcode) > 18    
         BEGIN    
            DECLARE @cSSCC  NVARCHAR( 60)    
            DECLARE @cCode  NVARCHAR( 10)    
            DECLARE @cShort NVARCHAR( 10)    
            DECLARE @cLong  NVARCHAR( 250)    
            DECLARE @cUDF01 NVARCHAR( 60)    
                   
            -- Get SSCC decode rule (SOS 361419)    
            SELECT     
               @cCode = Code,                -- Prefix of barcode    
               @cShort = ISNULL( Short, 0),  -- Lenght of string to take, after the prefix     
               @cLong = ISNULL( Long, ''),   -- String indicate don't need to decode (not used)     
               @cUDF01 = ISNULL( UDF01, '')  -- Prefix of actual string after decode    
            FROM dbo.CodeLKUP WITH (NOLOCK)     
            WHERE ListName = 'SSCCDECODE'    
               AND StorerKey = @cStorerKey    
    
            -- Check rule valid    
            IF @@ROWCOUNT <> 1    
            BEGIN    
               SET @nErrNo = 98455    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CodeLKUP    
               GOTO Quit    
            END    
    
            -- Check valid prefix    
            IF @cCode <> SUBSTRING( @cBarCode, 1, LEN( @cCode))    
            BEGIN    
               SET @nErrNo = 98456    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix    
               GOTO Quit    
            END    
                      
            -- Check valid length    
            IF rdt.rdtIsValidQty( @cShort, 1) = 0    
            BEGIN    
               SET @nErrNo = 98457    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length    
               GOTO Quit    
            END    
                      
            -- Get actual string    
            SET @cSSCC = SUBSTRING( @cBarcode, LEN( @cCode) + 1, CAST( @cShort AS INT))    
                      
            -- Check valid length    
            IF LEN( @cSSCC) <> @cShort    
            BEGIN    
               SET @nErrNo = 98458    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid length    
               GOTO Quit    
            END    
                   
            -- Check actual string prefix    
            IF @cUDF01 <> SUBSTRING( @cSSCC, 1, LEN( @cUDF01))    
            BEGIN    
               SET @nErrNo = 98459    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid prefix    
               GOTO Quit    
            END          
                      
            -- Check actual string is numeric    
            DECLARE @i INT    
            DECLARE @c NVARCHAR(1)    
            SET @i = 1    
            WHILE @i <= LEN( RTRIM( @cSSCC))    
            BEGIN    
               SET @c = SUBSTRING( @cSSCC, @i, 1)    
               IF NOT (@c >= '0' AND @c <= '9')    
               BEGIN    
                  SET @nErrNo = 98460    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC    
                  GOTO Quit    
               END    
               SET @i = @i + 1    
            END       
                      
            SET @cCartonBarcode = @cSSCC    
         END    
         ELSE    
            SET @cCartonBarcode = @cBarcode    
      END    
    
   END    
    
Quit:    
IF LEN( RTRIM( @cCartonBarcode)) >=18    
   SET @cCartonBarcode = SUBSTRING( RTRIM( @cCartonBarcode), 1, 18)    
    
Fail:    
END 

GO