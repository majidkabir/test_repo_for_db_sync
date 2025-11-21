SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_840CaptureInfo01                                   */  
/* Copyright      : Maersk                                                 */
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2023-03-31 1.0  James   WMS-22084. Created                              */  
/* 2023-09-06 1.1  James   WMS-23401 Extra validation to determine whether */  
/*                         need capture coo (james01)                      */  
/* 2023-11-16 1.2  James   WMS-24181 Bug fix on coo default value (james02)*/
/* 2024-08-08 1.3  James   WMS-24295 Check whether sku has unique          */
/*                         lottable01 then flow thru data capture(james03) */
/* 2024-11-08 1.4  PXL009  FCR-1118 Merged 1.3 from v0 branch              */
/***************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840CaptureInfo01](  
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15),   
   @cType        NVARCHAR( 10),  -- DISPLAY/UPDATE  
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),   
   @cRefNo       NVARCHAR( 20),                  
   @cPickSlipNo  NVARCHAR( 10),  
   @cData1       NVARCHAR( 60),  
   @cData2       NVARCHAR( 60),  
   @cData3       NVARCHAR( 60),  
   @cData4       NVARCHAR( 60),  
   @cData5       NVARCHAR( 60),  
   @cInField01   NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,     
   @cInField02   NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,     
   @cInField03   NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,     
   @cInField04   NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,     
   @cInField05   NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,     
   @cInField06   NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,    
   @cInField07   NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,    
   @cInField08   NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,    
   @cInField09   NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,    
   @cInField10   NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,    
   @cInField11   NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,   
   @cInField12   NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,   
   @cInField13   NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,   
   @cInField14   NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,   
   @cInField15   NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,   
   @cDataCaptureInfo NVARCHAR( 1)  OUTPUT,  
   @tCaptureVar  VariableTable READONLY,   
   @nErrNo       INT            OUTPUT,   
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cCode             NVARCHAR( 10)  
   DECLARE @cLabel            NVARCHAR( 20)  
   DECLARE @cColumn           NVARCHAR( 20)  
   DECLARE @cListName         NVARCHAR( 10)  
   DECLARE @cOption           NVARCHAR( 10)  
   DECLARE @cData             NVARCHAR( 20)  
   DECLARE @nCursorPos        INT  
   DECLARE @curData           CURSOR  
   DECLARE @cDataCapture      NVARCHAR( 1)  
   DECLARE @nIsDataCaptureReq INT = 1  
   DECLARE @cSKU              NVARCHAR( 20)  
   DECLARE @cOrdType          NVARCHAR( 10)  
   DECLARE @cLottable01       NVARCHAR( 18)  
   DECLARE @nRowCount         INT = 0  
   DECLARE @cDefaultSameCOO   NVARCHAR( 1)  
   DECLARE @cInSKU            NVARCHAR( 30)
   DECLARE @cSKUStatus        NVARCHAR( 10) = ''
   DECLARE @bSuccess          INT
   
   IF @cType = 'DISPLAY'  
   BEGIN  
      SET @cDefaultSameCOO = rdt.RDTGetConfig( @nFunc, 'DEFAULTSAMECOO', @cStorerKey)  
        
      SELECT @cOrdType = [Type]  
      FROM dbo.ORDERS WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
      
      -- Variable mapping  
      SELECT @cDataCapture = Value FROM @tCaptureVar WHERE Variable = '@cDataCapture'  
  
      SELECT @cInSKU = I_Field06  
      FROM rdt.RDTMOBREC WITH (NOLOCK)  
      WHERE Mobile = @nMobile  

      EXEC [RDT].[rdt_GETSKU]  
         @cStorerKey  = @cStorerkey,  
         @cSKU        = @cInSKU        OUTPUT,  
         @bSuccess    = @bSuccess      OUTPUT,  
         @nErr        = @nErrNo        OUTPUT,  
         @cErrMsg     = @cErrMsg       OUTPUT,
         @cSKUStatus  = @cSKUStatus  

      SET @cSKU = @cInSKU

      IF @nStep = 1 AND @cDataCapture <> '1'  
         SET @nIsDataCaptureReq = 0  
           
      IF @nStep = 3 AND @cDataCapture <> '3'  
         SET @nIsDataCaptureReq = 0  
  
      -- If COO = AU no need prompt  
      IF EXISTS ( SELECT 1  
                  FROM dbo.ORDERS WITH (NOLOCK)  
                  WHERE OrderKey = @cOrderKey  
                  AND   C_Country = 'AU') AND  
         NOT EXISTS ( SELECT 1  
                      FROM dbo.CODELKUP WITH (NOLOCK)   
                      WHERE ListName = 'LVSCOO'   
                      AND   Code = 'REQAUTYPE'  
                      AND   Short = @cOrdType)  
         SET @nIsDataCaptureReq = 0  
  
      -- If config turn on only need check below condition   
      -- else always prompt COO  
      IF @cDefaultSameCOO = '1' AND  
      -- If COO capture before no need prompt  
         EXISTS ( SELECT 1  
                  FROM dbo.PackDetail WITH (NOLOCK)  
                  WHERE PickSlipNo = @cPickSlipNo  
                  AND   SKU = @cSKU  
                  AND   ISNULL( RefNo, '') <> '')  
         SET @nIsDataCaptureReq = 0  
  
      IF @nIsDataCaptureReq = 0  
      BEGIN  
         SET @cDataCaptureInfo = 0  
         GOTO Quit         
      END  

      SET @cDataCaptureInfo = 1  
      SELECT @cInField01 = '', @cOutField01 = ''  
      SELECT @cInField02 = '', @cOutField02 = ''  
      SELECT @cInField03 = '', @cOutField03 = ''  
      SELECT @cInField04 = '', @cOutField04 = ''  
      SELECT @cInField05 = '', @cOutField05 = ''  
      SELECT @cInField06 = '', @cOutField06 = ''  
      SELECT @cInField07 = '', @cOutField07 = ''  
      SELECT @cInField08 = '', @cOutField08 = ''  
      SELECT @cInField09 = '', @cOutField09 = ''  
      SELECT @cInField10 = '', @cOutField10 = ''  
        
      SET @cFieldAttr02 = 'O'  
      SET @cFieldAttr04 = 'O'  
      SET @cFieldAttr06 = 'O'  
      SET @cFieldAttr08 = 'O'  
      SET @cFieldAttr10 = 'O'  
  
      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Code, Notes, UDF01, Short  
      FROM dbo.CodeLKUP WITH (NOLOCK)  
      WHERE ListName = 'RDTExtUpd'  
         AND Storerkey = @cStorerKey  
         AND Code2 = @nFunc  
      ORDER BY Code  
      OPEN @curData  
      FETCH NEXT FROM @curData INTO @cCode, @cLabel, @cListName, @cOption  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF ISNULL( @cLabel, '') <> ''  
         BEGIN  
            IF @cCode = '1' SELECT @cOutField01 = @cLabel, @cFieldAttr02 = '' ELSE  
            IF @cCode = '2' SELECT @cOutField03 = @cLabel, @cFieldAttr04 = '' ELSE  
            IF @cCode = '3' SELECT @cOutField05 = @cLabel, @cFieldAttr06 = '' ELSE  
            IF @cCode = '4' SELECT @cOutField07 = @cLabel, @cFieldAttr08 = '' ELSE  
            IF @cCode = '5' SELECT @cOutField09 = @cLabel, @cFieldAttr10 = ''  
  
            -- Get default value from CodeLKUP  
            IF CHARINDEX( 'L', @cOption) > 0  
            BEGIN  
               -- Get default value  
               SET @cData = ''  
               SELECT TOP 1  
                  @cData = Code  
               FROM CodeLKUP WITH (NOLOCK)   
               WHERE ListName = @cListName  
                  AND Short LIKE '%D%' -- Default  
                  AND StorerKey = @cStorerKey  
                  AND Code2 = @nFunc  
              
               IF @cLabel LIKE 'COO%'  
               BEGIN  
                  SELECT DISTINCT @cLottable01 = LOTTABLE01   
                  FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)   
                  JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)   
                  WHERE LLI.StorerKey = @cStorerKey  
                  AND   LLI.SKU = @cSKU   
                  AND   LLI.QTY > 0   
                    
                  SET @nRowCount = @@ROWCOUNT  
                    
                  IF @nRowCount = 1 AND  
                     ISNULL( @cLottable01, '') <> '' AND   
                     EXISTS( SELECT 1   
                             FROM dbo.CODELKUP WITH (NOLOCK)   
                             WHERE LISTNAME = 'LVSCOO'  
                             AND   Code = @cLottable01  
                             AND   Storerkey = @cStorerKey   
                             AND   LEN( Code) = 2)  
                  BEGIN
                     SET @cData = @cLottable01  

                     -- The SKU only contain 1 distinct lottable01
                     -- auto flow to data capture screen
                     SET @cDataCaptureInfo = 2
                     SET @cInField02 = @cLottable01
                  END
               END  
                 
               -- Set default value  
               IF @cData <> ''  
               BEGIN  
                  IF @cCode = '1' SELECT @cOutField02 = @cData ELSE  
                  IF @cCode = '2' SELECT @cOutField04 = @cData ELSE  
                  IF @cCode = '3' SELECT @cOutField06 = @cData ELSE  
                  IF @cCode = '4' SELECT @cOutField08 = @cData ELSE  
                  IF @cCode = '5' SELECT @cOutField10 = @cData  
               END  
            END  
         END  
           
         FETCH NEXT FROM @curData INTO @cCode, @cLabel, @cListName, @cOption  
      END  
        
      -- Position on 1st empty field  
      IF @cFieldAttr02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE  
      IF @cFieldAttr04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE  
      IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE  
      IF @cFieldAttr08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE  
      IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10   
   END  
     
   IF @cType = 'UPDATE'  
   BEGIN  
      -- Construct update columns TSQL  
      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Code, Short, Long, UDF01  
      FROM dbo.CodeLKUP WITH (NOLOCK)  
      WHERE ListName = 'RDTExtUpd'  
         AND Storerkey = @cStorerKey  
         AND Code2 = @nFunc  
      ORDER BY Code  
      OPEN @curData  
      FETCH NEXT FROM @curData INTO @cCode, @cOption, @cColumn, @cListName  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Check require field  
         IF @cOption <> ''  
         BEGIN  
            -- Get data  
            IF @cCode = '1' SELECT @cData = @cData1, @nCursorPos = 2  ELSE  
            IF @cCode = '2' SELECT @cData = @cData2, @nCursorPos = 4  ELSE  
            IF @cCode = '3' SELECT @cData = @cData3, @nCursorPos = 6  ELSE  
            IF @cCode = '4' SELECT @cData = @cData4, @nCursorPos = 8  ELSE  
            IF @cCode = '5' SELECT @cData = @cData5, @nCursorPos = 10   
              
            -- Check blank  
            IF CHARINDEX( 'R', @cOption) > 0 AND @cData = ''  
            BEGIN  
               SET @nErrNo = 198801  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need data  
               EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos  
               GOTO Quit  
            END  
  
            -- Check format  
            IF CHARINDEX( 'F', @cOption) > 0   
            BEGIN  
               IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Data' + @cCode, @cData) = 0  
               BEGIN  
                  SET @nErrNo = 198802  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format  
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos  
                  GOTO Quit  
               END  
            END  
  
            -- Check value in CodeLKUP  
            IF CHARINDEX( 'L', @cOption) > 0 AND @cListName <> ''  
            BEGIN  
               IF NOT EXISTS( SELECT TOP 1 1   
                  FROM CodeLKUP WITH (NOLOCK)   
                  WHERE ListName = @cListName  
                     AND Code = @cData  
                     AND StorerKey = @cStorerKey  
                     AND Code2 = @nFunc)  
               BEGIN  
                  SET @nErrNo = 198803  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid value  
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos  
                  GOTO Quit  
               END  
            END  
         END  
           
         FETCH NEXT FROM @curData INTO @cCode, @cOption, @cColumn, @cListName  
      END  
   END  
     
Quit:  
  
END  

GO