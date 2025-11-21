SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdt_600DimWghtValVLT                                       */
/*                                                                             */
/*                                                                             */
/* Date         Rev     Author   Purposes                                      */
/* 10/01/2024   1.0     PPA374   Check dimension value for being over cap      */
/* 31/10/2024   1.1.0   PPA374   UWP-26437 Formatting                          */
/*******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_600DimWghtValVLT] (
   @nMobile      INT,              
   @nFunc        INT,              
   @cLangCode    NVARCHAR( 3),     
   @nStep        INT,              
   @nInputKey    INT,              
   @cFacility    NVARCHAR( 5),     
   @cStorerKey   NVARCHAR( 15),    
   @cSKU         NVARCHAR( 20),    
   @cType        NVARCHAR( 15),    
   @cLabel       NVARCHAR( 30)  OUTPUT,     
   @cShort       NVARCHAR( 10)  OUTPUT,     
   @cValue       NVARCHAR( MAX) OUTPUT,    
   @nErrNo       INT            OUTPUT,    
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
) AS

BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowRef        INT  
   DECLARE @cPackKey       NVARCHAR( 10)  
   DECLARE @fWeight        FLOAT  
   DECLARE @fCube          FLOAT  
   DECLARE @fLength        FLOAT  
   DECLARE @fWidth         FLOAT  
   DECLARE @fHeight        FLOAT  
   DECLARE @fInnerPack     FLOAT  
   DECLARE @fCaseCount     FLOAT  
   DECLARE @fPalletCount   FLOAT  
   DECLARE @nShelfLife     INT  
   DECLARE @cPackUOM2      NVARCHAR( 10)  
   DECLARE @cPackUOM1      NVARCHAR( 10)  
   DECLARE @cPackUOM4      NVARCHAR( 10)  
   DECLARE @cInnerUOM      NVARCHAR( 10)  
   DECLARE @cCaseUOM       NVARCHAR( 10)  
   DECLARE @cPalletUOM     NVARCHAR( 10)  
   DECLARE @cTableField    NVARCHAR( 60)  
   DECLARE @curVS          CURSOR  

   -- Temp table for VerifySKU  
   DECLARE @tVS TABLE  
   (  
      RowRef   INT            IDENTITY( 1,1),  
      Code     NVARCHAR( 30)  NOT NULL, -- Label  
      Short    NVARCHAR( 10)  NOT NULL, -- Option  
      UDF01    NVARCHAR( 60)  NOT NULL, -- Table.Column  
      UDF02    NVARCHAR( 60)  NOT NULL, -- Sequence  
      UDF03    NVARCHAR( 60)  NOT NULL, -- SP  
      UDF04    NVARCHAR( 60)  NOT NULL, -- Default value  
      Value    NVARCHAR( MAX) NOT NULL  
   )  

      -- Get SKU info  
   SELECT  
      @fWeight      = SKU.STDGrossWGT,  
      @fCube        = SKU.STDCube,  
      @nShelfLife   = SKU.ShelfLife,  
      @fLength      = Pack.LengthUOM3,  
      @fWidth       = Pack.WidthUOM3,  
      @fHeight      = Pack.HeightUOM3,  
      @fInnerPack   = Pack.InnerPack,  
      @fCaseCount   = Pack.CaseCnt,  
      @fPalletCount = Pack.Pallet,  
      @cPackKey     = Pack.PackKey,  
      @cPackUOM2    = Pack.PackUOM2,  
      @cPackUOM1    = Pack.PackUOM1,  
      @cPackUOM4    = Pack.PackUOM4  
   FROM dbo.SKU WITH (NOLOCK)  
   INNER JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cSKU  

   -- Copy into temp table  
   INSERT INTO @tVS (Code, Short, UDF01, UDF02, UDF03, UDF04, Value)  
   SELECT Code, Short, UDF01, UDF02, UDF03, UDF04, ''  
   FROM dbo.CodeLKUP WITH (NOLOCK)  
   WHERE ListName = 'VerifySKU'  
      AND Code2 = @nFunc  
      AND StorerKey = @cStorerKey  
   ORDER BY UDF02 -- Sequence
   
   IF @cType = 'CHECK'
   BEGIN  
      -- Loop to check whether need verify  
      DECLARE @cVerifySKU NVARCHAR(1)  
      SET @cVerifySKU = 'N'  
      SET @curVS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT RowRef, Code, Short, UDF01, Value  
         FROM @tVS  
         ORDER BY RowRef  
      OPEN @curVS  
      FETCH NEXT FROM @curVS INTO @nRowRef, @cLabel, @cShort, @cTableField, @cValue  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         BEGIN  
            -- Check standard field  
            IF @cTableField  = 'SKU.STDGrossWGT' SELECT @cValue = rdt.rdtFormatFloat( @fWeight     ), @cVerifySKU = CASE WHEN @fWeight      = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'SKU.STDCube'     SELECT @cValue = rdt.rdtFormatFloat( @fCube       ), @cVerifySKU = CASE WHEN @fCube        = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'SKU.ShelfLife'   SELECT @cValue = CAST( @nShelfLife AS NVARCHAR(5) ), @cVerifySKU = CASE WHEN @nShelfLife   = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'Pack.LengthUOM3' SELECT @cValue = rdt.rdtFormatFloat( @fLength     ), @cVerifySKU = CASE WHEN @fLength      = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'Pack.WidthUOM3'  SELECT @cValue = rdt.rdtFormatFloat( @fWidth      ), @cVerifySKU = CASE WHEN @fWidth       = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'Pack.HeightUOM3' SELECT @cValue = rdt.rdtFormatFloat( @fHeight     ), @cVerifySKU = CASE WHEN @fHeight      = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'Pack.InnerPack'  SELECT @cValue = rdt.rdtFormatFloat( @fInnerPack  ), @cVerifySKU = CASE WHEN @fInnerPack   = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'Pack.CaseCnt'    SELECT @cValue = rdt.rdtFormatFloat( @fCaseCount  ), @cVerifySKU = CASE WHEN @fCaseCount   = 0 THEN 'Y' ELSE @cVerifySKU END ELSE  
            IF @cTableField  = 'Pack.Pallet'     SELECT @cValue = rdt.rdtFormatFloat( @fPalletCount), @cVerifySKU = CASE WHEN @fPalletCount = 0 THEN 'Y' ELSE @cVerifySKU END  
            
         IF @cVerifySKU = 'Y' SET @nErrNo = -1

       END    
         FETCH NEXT FROM @curVS INTO @nRowRef, @cLabel, @cShort, @cTableField, @cValue  
      END  
   GOTO Quit
   END
   
   IF @cType = 'UPDATE'
   BEGIN  
      DECLARE @cUpdateWeight      NVARCHAR( 1)  
      DECLARE @cUpdateCube        NVARCHAR( 1)  
      DECLARE @cUpdateShelfLife   NVARCHAR( 1)  
      DECLARE @cUpdateLength      NVARCHAR( 1)  
      DECLARE @cUpdateWidth       NVARCHAR( 1)  
      DECLARE @cUpdateHeight      NVARCHAR( 1)  
      DECLARE @cUpdateInnerPack   NVARCHAR( 1)  
      DECLARE @cUpdateCaseCount   NVARCHAR( 1)  
      DECLARE @cUpdatePalletCount NVARCHAR( 1)
      DECLARE @nTranCount     INT

     SET @nTranCount = @@TRANCOUNT  

     IF EXISTS (SELECT 1 FROM rdt.RDTMOBREC WITH(NOLOCK) WHERE Mobile = @nMobile AND 
      (CAST(I_Field05 AS FLOAT) > (SELECT TOP 1 short FROM CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQDIMVAL' AND code = 'Height') 
      OR CAST(I_Field07 AS FLOAT) > (SELECT TOP 1 short FROM CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQDIMVAL' AND code = 'Length')
      OR CAST(I_Field13 AS FLOAT) > (SELECT TOP 1 short FROM CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQDIMVAL' AND code = 'Width')
      OR (CAST(I_Field05 AS FLOAT) * CAST(I_Field07 AS FLOAT) * CAST(I_Field13 AS FLOAT))/1000000 > (SELECT TOP 1 short FROM CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQDIMVAL' AND code = 'Cube')
      ))
     BEGIN
         SET @nErrNo = 218044
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
         GOTO Quit
     END

     IF EXISTS (SELECT 1 FROM rdt.RDTMOBREC WITH(NOLOCK) WHERE Mobile = @nMobile AND 
      (CAST(I_Field11 AS FLOAT) > (SELECT TOP 1 short FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQDIMVAL' AND code = 'Weight')))
     BEGIN
         SET @nErrNo = 218045
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
         GOTO Quit
     END

     BEGIN  
      -- Check weight  
         IF @cLabel = 'Weight'  
         BEGIN  
            IF rdt.rdtIsValidQty( @cValue, 21) = 0  
            BEGIN  
               SET @nErrNo = 55751  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Weight   
               GOTO Quit
            END  
  
            -- Value changed  
            IF @fWeight <> CAST( @cValue AS FLOAT)  
            BEGIN  
               SET @fWeight = CAST( @cValue AS FLOAT)  
               SET @cUpdateWeight = 'Y'
               GOTO Quit
            END  
         END  
  
         -- Check cube
         ELSE IF @cLabel = 'Cube'
         BEGIN
            IF rdt.rdtIsValidQty( @cValue, 21) = 0
            BEGIN
               SET @nErrNo = 55752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Cube
               GOTO Quit
            END
  
         -- Value changed
         IF @fCube <> CAST( @cValue AS FLOAT)
         BEGIN
            SET @fCube = CAST( @cValue AS FLOAT)
            SET @cUpdateCube = 'Y'
            END
         END  
  
         -- Check shelflife  
         ELSE IF @cLabel = 'ShelfLife'  
         BEGIN  
            IF rdt.rdtIsValidQTY( @cValue, 1) = 0  
            BEGIN  
               SET @nErrNo = 55753  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ShelfLife  
               GOTO Quit
            END  
  
            -- Value changed  
            IF @nShelfLife <> CAST( @cValue AS INT)  
            BEGIN  
               SET @nShelfLife = CAST( @cValue AS INT)  
               SET @cUpdateShelfLife = 'Y'  
            END  
         END  
  
         -- Check length  
         ELSE IF @cLabel = 'Length'  
         BEGIN  
            IF rdt.rdtIsValidQty( @cValue, 21) = 0  
            BEGIN  
               SET @nErrNo = 55754  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Length  
               GOTO Quit
            END  
  
            -- Value changed  
            IF @fLength <> CAST( @cValue AS FLOAT)  
            BEGIN  
               SET @fLength = CAST( @cValue AS FLOAT)  
               SET @cUpdateLength = 'Y'  
               END  
            END  
  
            -- Check width  
            ELSE IF @cLabel = 'Width'  
            BEGIN  
               IF rdt.rdtIsValidQty( @cValue, 21) = 0  
               BEGIN  
                  SET @nErrNo = 55755  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Width  
                  GOTO Quit
               END  
  
               -- Value changed  
               IF @fWidth <> CAST( @cValue AS FLOAT)  
               BEGIN  
                  SET @fWidth = CAST( @cValue AS FLOAT)  
                  SET @cUpdateWidth = 'Y'  
               END  
            END  
  
            -- Check height  
            ELSE IF @cLabel = 'Height'  
            BEGIN  
            -- Check valid  
               IF rdt.rdtIsValidQty( @cValue, 21) = 0  
               BEGIN  
                  SET @nErrNo = 55756  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Height  
                  GOTO Quit
               END  
  
               -- Value changed  
               IF @fHeight <> CAST( @cValue AS FLOAT)  
               BEGIN  
                  SET @fHeight = CAST( @cValue AS FLOAT)  
                  SET @cUpdateHeight = 'Y'  
               END  
            END  
  
            -- Check inner  
            ELSE IF @cLabel = 'InnerPack'  
            BEGIN  
            -- Check valid  
               IF rdt.rdtIsValidQty( @cValue, 1) = 0 -- not check for zero  
               BEGIN  
                  SET @nErrNo = 55757  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Inner  
                  GOTO Quit
               END  
  
               -- Value changed  
               IF @fInnerPack <> CAST( @cValue AS FLOAT)  
               BEGIN  
                  -- Check inventory balance  
                  IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)  
                  BEGIN  
                     SET @nErrNo = 55758  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal  
                     GOTO Quit
                  END  
                    
                  -- Value changed  
                  SET @fInnerPack = CAST( @cValue AS FLOAT)  
                  SET @cInnerUOM = 0  
                  SET @cUpdateInnerPack = 'Y'  
               END  
            END  
  
            -- Check case  
            ELSE IF @cLabel = 'Case'  
            BEGIN  
               -- Check valid  
               IF rdt.rdtIsValidQty( @cValue, 1) = 0 -- not check for zero  
               BEGIN  
                  SET @nErrNo = 55759  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Case  
                  GOTO Quit
               END  
  
               -- Value changed  
               IF @fCaseCount <> CAST( @cValue AS FLOAT)  
               BEGIN  
                  -- Check inventory balance  
                  IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)  
                  BEGIN  
                     SET @nErrNo = 55760  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal  
                     GOTO Quit
                  END  
  
                  -- Value changed  
                  SET @fCaseCount = CAST( @cValue AS FLOAT)  
                  SET @cCaseUOM = 0  
                  SET @cUpdateCaseCount = 'Y'  
               END
            END
  
            -- Check pallet  
            ELSE IF @cLabel = 'Pallet'  
            BEGIN  
               -- Check valid  
               IF rdt.rdtIsValidQty( @cValue, 1) = 0  
               BEGIN  
                  SET @nErrNo = 55761  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Pallet  
                  GOTO Quit
               END  
  
               -- Value changed  
               IF @fPalletCount <> CAST( @cValue AS FLOAT)  
               BEGIN  
                  -- Check inventory balance  
                  IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)  
                  BEGIN  
                     SET @nErrNo = 55762  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal 
                     GOTO Quit
                  END  
  
                  -- Value changed  
                  SET @fPalletCount = CAST( @cValue AS FLOAT)  
                  SET @cPalletUOM = 0  
                  SET @cUpdatePalletCount = 'Y'  
               END  
            END  
         END

     -- Update Pack setting  
      IF @cUpdateLength      = 'Y' OR  
      @cUpdateWidth       = 'Y' OR  
      @cUpdateHeight      = 'Y' OR  
      @cUpdateInnerPack   = 'Y' OR  
      @cUpdateCaseCount   = 'Y' OR  
      @cUpdatePalletCount = 'Y'    
      BEGIN                     
         UPDATE dbo.Pack WITH(ROWLOCK) SET  
         LengthUOM3 = CASE WHEN @cUpdateLength      = 'Y' THEN @fLength       ELSE LengthUOM3  END,  
         WidthUOM3  = CASE WHEN @cUpdateWidth       = 'Y' THEN @fWidth        ELSE WidthUOM3   END,  
         HeightUOM3 = CASE WHEN @cUpdateHeight      = 'Y' THEN @fHeight       ELSE HeightUOM3  END,  
         InnerPack  = CASE WHEN @cUpdateInnerPack   = 'Y' THEN @fInnerPack    ELSE InnerPack   END,  
         CaseCNT    = CASE WHEN @cUpdateCaseCount   = 'Y' THEN @fCaseCount    ELSE CaseCNT     END,  
         Pallet     = CASE WHEN @cUpdatePalletCount = 'Y' THEN @fPalletCount  ELSE Pallet      END,  
         PackUOM2   = CASE WHEN @cUpdateInnerPack   = 'Y' AND @cPackUOM2 = '' THEN @cInnerUOM  ELSE @cPackUOM2 END,  
         PackUOM1   = CASE WHEN @cUpdateCaseCount   = 'Y' AND @cPackUOM1 = '' THEN @cCaseUOM   ELSE @cPackUOM1 END,  
         PackUOM4   = CASE WHEN @cUpdatePalletCount = 'Y' AND @cPackUOM4 = '' THEN @cPalletUOM ELSE @cPackUOM4 END  
         WHERE PackKey = @cPackKey  
      
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 55764  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Pack Fail  
            GOTO Quit
         END  
      END
   END  
Quit:  
END

GO