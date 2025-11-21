SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_VerifySKU_V7                                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Verify SKU setting                                          */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author       Purposes                               */  
/* 03-08-2015  1.0  Ung          SOS347397. Migrate from rdt_VerifySKU  */  
/* 21-09-2015  1.1  Ung          SOS350418. Update remain current screen*/  
/* 20-05-2020  1.2  YeeKung      WMS-11867 Add errno=-2  (yeekung01)    */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_VerifySKU_V7]  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 3),  
   @cStorerKey       NVARCHAR( 15),  
   @cSKU             NVARCHAR( 20),  
   @cSKUDesc         NVARCHAR( 60),  
   @cType            NVARCHAR( 15), --CHECK/UPDATE  
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount     INT  
   DECLARE @nRowRef        INT  
   DECLARE @cRowRef        NVARCHAR( 1)  
   DECLARE @nCount         INT  
   DECLARE @cFieldAttr     NVARCHAR( 1)  
   DECLARE @nPos           INT  
   DECLARE @cUpdateSKU     NVARCHAR( 1)  
   DECLARE @cUpdatePack    NVARCHAR( 1)  
   DECLARE @cSQL           NVARCHAR(MAX)  
   DECLARE @cSQLParam      NVARCHAR(MAX)  
                             
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
  
   DECLARE @cLabel         NVARCHAR( 20)  
   DECLARE @cShort         NVARCHAR( 10)  
   DECLARE @cTableField    NVARCHAR( 60)  
   DECLARE @cSP            NVARCHAR( 60)  
   DECLARE @cValue         NVARCHAR( 20)  
   DECLARE @cDefault       NVARCHAR( 20)  
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
  
   -- Copy into temp table  
   INSERT INTO @tVS (Code, Short, UDF01, UDF02, UDF03, UDF04, Value)  
   SELECT Code, Short, UDF01, UDF02, UDF03, UDF04, ''  
   FROM CodeLKUP WITH (NOLOCK)  
   WHERE ListName = 'VerifySKU'  
      AND Code2 = @nFunc  
      AND StorerKey = @cStorerKey  
   ORDER BY UDF02 -- Sequence  
  
   IF @@ROWCOUNT = 0  
      GOTO Quit  
  
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
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cSKU  
  
   -- Check SKU setting  
   IF @cType = 'CHECK'  
   BEGIN  
      -- Loop to check whether need verify  
      DECLARE @cVerifySKU NVARCHAR(1)  
      SET @cVerifySKU = 'N'  
      SET @curVS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT RowRef, Code, Short, UDF01, UDF03, Value  
         FROM @tVS  
         ORDER BY RowRef  
      OPEN @curVS  
      FETCH NEXT FROM @curVS INTO @nRowRef, @cLabel, @cShort, @cTableField, @cSP, @cValue  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Customize SP  
         IF @cSP <> ''  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cType, ' +   
               ' @cLabel OUTPUT, @cShort OUTPUT, @cValue OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
            SET @cSQLParam =  
               '@nMobile      INT,           ' +  
               '@nFunc        INT,           ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,           ' +  
               '@nInputKey    INT,           ' +  
               '@cFacility    NVARCHAR( 5),  ' +  
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cSKU         NVARCHAR( 20), ' +  
               '@cType        NVARCHAR( 15), ' +  
               '@cLabel       NVARCHAR( 30)  OUTPUT, ' +   
               '@cShort       NVARCHAR( 10)  OUTPUT, ' +   
               '@cValue       NVARCHAR( MAX) OUTPUT, ' +  
               '@nErrNo       INT            OUTPUT, ' +  
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cType,   
               @cLabel OUTPUT, @cShort OUTPUT, @cValue OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
            IF @nErrNo = -1  
               SET @cVerifySKU = 'Y'  
            IF  @nErrNo=-2  
            BEGIN   
                SET @nErrNo=0  
                GOTO QUIT  
            END  
         END  
         ELSE  
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
         END  
  
         -- Save initial value  
         UPDATE @tVS SET  
            Value = @cValue,   
            Short = @cShort  
         WHERE RowRef = @nRowRef  
  
         FETCH NEXT FROM @curVS INTO @nRowRef, @cLabel, @cShort, @cTableField, @cSP, @cValue  
      END  
  
      -- Loop fields position on screen (some could be blank)  
      IF @cVerifySKU = 'Y'  
      BEGIN  
         SET @nPOS = 0  
         SET @nCount = 1  
         SET @cOutField15 = ''  
           
         SET @curVS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT RowRef, Code, Short, UDF01, UDF03, Value  
            FROM @tVS  
            ORDER BY RowRef  
         OPEN @curVS  
         FETCH NEXT FROM @curVS INTO @nRowRef, @cLabel, @cShort, @cTableField, @cSP, @cValue  
         WHILE @nCount <= 5  
         BEGIN  
            -- Verify field to show on this position  
            IF @@FETCH_STATUS = 0  
            BEGIN  
               IF CHARINDEX( 'E', @cShort) > 0 --E=Editable  
                  SET @cFieldAttr = ''  
               ELSE  
                  SET @cFieldAttr = 'O'  
  
               -- Save sequence of verify SKU field into hidden field  
               SET @cOutField15 = @cOutField15 + CAST( @nRowRef AS NVARCHAR(1)) + ','  
            END  
            ELSE  
               -- No lottable for this position  
               SELECT @cLabel = '', @cValue = '', @cFieldAttr = 'O'  
  
            -- Output to screen  
            IF @nCount = 1 SELECT @cOutField04 = @cLabel, @cOutField05 = @cValue, @cFieldAttr05 = @cFieldAttr ELSE  
            IF @nCount = 2 SELECT @cOutField06 = @cLabel, @cOutField07 = @cValue, @cFieldAttr07 = @cFieldAttr ELSE  
            IF @nCount = 3 SELECT @cOutField08 = @cLabel, @cOutField09 = @cValue, @cFieldAttr09 = @cFieldAttr ELSE  
            IF @nCount = 4 SELECT @cOutField10 = @cLabel, @cOutField11 = @cValue, @cFieldAttr11 = @cFieldAttr ELSE  
            IF @nCount = 5 SELECT @cOutField12 = @cLabel, @cOutField13 = @cValue, @cFieldAttr13 = @cFieldAttr  
  
            -- Set cursor, input and blank field  
            IF @nPOS = 0 AND @cFieldAttr = '' AND @cValue = ''  
               SET @nPOS = 3 + (@nCount * 2)  
  
            SET @nCount = @nCount + 1  
  
            FETCH NEXT FROM @curVS INTO @nRowRef, @cLabel, @cShort, @cTableField, @cSP, @cValue  
         END  
  
     -- Prepare next screen var  
     SET @cOutField01 = @cSKU  
         SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1  
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2  
  
         EXEC rdt.rdtSetFocusField @nMobile, @nPos  
  
         SET @nErrNo = -1 -- Need verify SKU  
      END  
   END  
  
   -- Update SKU setting  
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
  
      -- Handling transaction  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_VerifySKU_V7 -- For rollback or commit only our own transaction  
        
      SET @nCount = 1  
      WHILE @nCount <= 5  
      BEGIN  
         -- Get input  
         IF @nCount = 1 SELECT @cFieldAttr = @cFieldAttr05, @cValue = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END ELSE  
         IF @nCount = 2 SELECT @cFieldAttr = @cFieldAttr07, @cValue = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END ELSE  
         IF @nCount = 3 SELECT @cFieldAttr = @cFieldAttr09, @cValue = CASE WHEN @cFieldAttr09 = '' THEN @cInField09 ELSE @cOutField09 END ELSE  
         IF @nCount = 4 SELECT @cFieldAttr = @cFieldAttr11, @cValue = CASE WHEN @cFieldAttr11 = '' THEN @cInField11 ELSE @cOutField11 END ELSE  
         IF @nCount = 5 SELECT @cFieldAttr = @cFieldAttr13, @cValue = CASE WHEN @cFieldAttr13 = '' THEN @cInField13 ELSE @cOutField13 END  
  
         -- Verify if field enable  
         IF @cFieldAttr = ''  
         BEGIN  
            -- Calc cursor pos  
            SET @nPos = 3 + (@nCount * 2)  
  
            -- Get which verify SKU field  
            SELECT @cRowRef = rdt.rdtGetParsedString( @cOutField15, @nCount, ',')  
  
            -- Get verify SKU info  
            SELECT  
               @cLabel = Code,   
               @cShort = Short,   
               @cTableField = UDF01,  
               @cSP = UDF03,  
               @cDefault = UDF04  
            FROM @tVS  
            WHERE RowRef = @cRowRef  
  
            -- Customize SP  
            IF @cSP <> ''  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cType, ' +   
                  ' @cLabel OUTPUT, @cShort OUTPUT, @cValue OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
               SET @cSQLParam =  
                  '@nMobile      INT,           ' +  
                  '@nFunc        INT,           ' +  
                  '@cLangCode    NVARCHAR( 3),  ' +  
                  '@nStep        INT,           ' +  
                  '@nInputKey    INT,           ' +  
                  '@cFacility    NVARCHAR( 5),  ' +  
                  '@cStorerKey   NVARCHAR( 15), ' +  
                  '@cSKU         NVARCHAR( 20), ' +  
                  '@cType        NVARCHAR( 15), ' +  
                  '@cLabel       NVARCHAR( 30)  OUTPUT, ' +   
                  '@cShort       NVARCHAR( 10)  OUTPUT, ' +   
                  '@cValue       NVARCHAR( MAX) OUTPUT, ' +  
                  '@nErrNo       INT         OUTPUT, ' +  
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT'  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cType,   
                  @cLabel OUTPUT, @cShort OUTPUT, @cValue OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0 AND  
                  @nErrNo <> -1  
               BEGIN  
                  EXEC rdt.rdtSetFocusField @nMobile, @nPos  
                  GOTO RollBackTran  
               END  
            END  
            ELSE  
            BEGIN  
               -- Check weight  
               IF @cTableField = 'SKU.STDGrossWGT'  
               BEGIN  
                  IF rdt.rdtIsValidQty( @cValue, 21) = 0  
                  BEGIN  
                     SET @nErrNo = 55751  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Weight  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Weight  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fWeight <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     SET @fWeight = CAST( @cValue AS FLOAT)  
                     SET @cUpdateWeight = 'Y'  
                  END  
               END  
  
               -- Check cube  
               ELSE IF @cTableField = 'SKU.STDCube'  
               BEGIN  
                  IF rdt.rdtIsValidQty( @cValue, 21) = 0  
                  BEGIN  
                     SET @nErrNo = 55752  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Cube  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Cube  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fCube <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     SET @fCube = CAST( @cValue AS FLOAT)  
                     SET @cUpdateCube = 'Y'  
                  END  
               END  
  
               -- Check shelflife  
               ELSE IF @cTableField = 'SKU.ShelfLife'  
               BEGIN  
                  IF rdt.rdtIsValidQTY( @cValue, 1) = 0  
                  BEGIN  
                     SET @nErrNo = 55753  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ShelfLife  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- ShelfLife  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @nShelfLife <> CAST( @cValue AS INT)  
                  BEGIN  
                     SET @nShelfLife = CAST( @cValue AS INT)  
                     SET @cUpdateShelfLife = 'Y'  
                  END  
               END  
  
               -- Check length  
               ELSE IF @cTableField = 'Pack.LengthUOM3'  
               BEGIN  
                  IF rdt.rdtIsValidQty( @cValue, 21) = 0  
                  BEGIN  
                     SET @nErrNo = 55754  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Length  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Length  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fLength <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     SET @fLength = CAST( @cValue AS FLOAT)  
                     SET @cUpdateLength = 'Y'  
                  END  
               END  
  
               -- Check width  
               ELSE IF @cTableField = 'Pack.WidthUOM3'  
               BEGIN  
                  IF rdt.rdtIsValidQty( @cValue, 21) = 0  
                  BEGIN  
                     SET @nErrNo = 55755  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Width  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Width  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fWidth <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     SET @fWidth = CAST( @cValue AS FLOAT)  
                     SET @cUpdateWidth = 'Y'  
                  END  
               END  
  
               -- Check height  
               ELSE IF @cTableField = 'Pack.HeightUOM3'  
               BEGIN  
                  -- Check valid  
                  IF rdt.rdtIsValidQty( @cValue, 21) = 0  
                  BEGIN  
                     SET @nErrNo = 55756  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Height  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Height  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fHeight <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     SET @fHeight = CAST( @cValue AS FLOAT)  
                     SET @cUpdateHeight = 'Y'  
                  END  
               END  
  
               -- Check inner  
               ELSE IF @cTableField = 'Pack.InnerPack'  
               BEGIN  
                  -- Check valid  
                  IF rdt.rdtIsValidQty( @cValue, 1) = 0 -- not check for zero  
                  BEGIN  
                     SET @nErrNo = 55757  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Inner  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Inner  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fInnerPack <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     -- Check inventory balance  
                     IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)  
                     BEGIN  
                        SET @nErrNo = 55758  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal  
                        EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Inner  
                        GOTO RollBackTran  
                     END  
                    
                     -- Value changed  
                     SET @fInnerPack = CAST( @cValue AS FLOAT)  
                     SET @cInnerUOM = @cDefault  
                     SET @cUpdateInnerPack = 'Y'  
                  END  
               END  
  
               -- Check case  
               ELSE IF @cTableField = 'Pack.CaseCnt'  
               BEGIN  
                  -- Check valid  
                  IF rdt.rdtIsValidQty( @cValue, 1) = 0 -- not check for zero  
                  BEGIN  
                     SET @nErrNo = 55759  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Case  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Case  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fCaseCount <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     -- Check inventory balance  
                     IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)  
                     BEGIN  
                        SET @nErrNo = 55760  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal  
                        EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Case  
                        GOTO RollBackTran  
                     END  
  
                     -- Value changed  
                     SET @fCaseCount = CAST( @cValue AS FLOAT)  
                     SET @cCaseUOM = @cDefault  
                     SET @cUpdateCaseCount = 'Y'  
                  END  
  
               END  
  
               -- Check pallet  
               ELSE IF @cTableField = 'Pack.Pallet'  
      BEGIN  
                  -- Check valid  
                  IF rdt.rdtIsValidQty( @cValue, 1) = 0  
                  BEGIN  
                     SET @nErrNo = 55761  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Pallet  
                     EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Pallet  
                     GOTO RollBackTran  
                  END  
  
                  -- Value changed  
                  IF @fPalletCount <> CAST( @cValue AS FLOAT)  
                  BEGIN  
                     -- Check inventory balance  
                     IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)  
                     BEGIN  
                        SET @nErrNo = 55762  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal  
                        EXEC rdt.rdtSetFocusField @nMobile, @nPos -- Pallet  
                        GOTO RollBackTran  
                     END  
  
                     -- Value changed  
                     SET @fPalletCount = CAST( @cValue AS FLOAT)  
                     SET @cPalletUOM = @cDefault  
                     SET @cUpdatePalletCount = 'Y'  
                  END  
               END  
            END  
         END  
  
         -- Output  
         IF @nCount = 1 SET @cOutField05 = @cValue ELSE  
         IF @nCount = 2 SET @cOutField07 = @cValue ELSE  
         IF @nCount = 3 SET @cOutField09 = @cValue ELSE  
         IF @nCount = 4 SET @cOutField11 = @cValue ELSE  
         IF @nCount = 5 SET @cOutField13 = @cValue  
  
         SET @nCount = @nCount + 1  
      END  
  
      -- Update SKU setting  
      IF @cUpdateWeight    = 'Y' OR  
         @cUpdateCube      = 'Y' OR  
         @cUpdateShelfLife = 'Y'  
      BEGIN  
         UPDATE dbo.SKU SET  
            STDGrossWGT = CASE WHEN @cUpdateWeight    = 'Y' THEN @fWeight    ELSE STDGrossWGT END,  
            STDCube     = CASE WHEN @cUpdateCube      = 'Y' THEN @fCube      ELSE STDCube     END,  
            ShelfLife   = CASE WHEN @cUpdateShelfLife = 'Y' THEN @nShelfLife ELSE ShelfLife   END  
         WHERE StorerKey = @cStorerKey  
            AND SKU = @cSKU  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 55763  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail  
            GOTO RollBackTran  
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
         UPDATE dbo.Pack SET  
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
            GOTO RollBackTran  
         END  
      END  
        
      -- Clean up hidden field  
      IF @nErrNo <> -1  
         SET @cOutField15 = ''  
        
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_VerifySKU_V7 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN     
END  

GO