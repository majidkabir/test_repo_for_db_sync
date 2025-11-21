SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdtfnc_TBLSKU_Import                                */  
/* Copyright      : IDS                                                 */  
/* FBR: 91596                                                           */  
/* Purpose: Insert TBLSKU to WMS SKU table                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Rev  Author     Purposes                                */  
/* 20-Sep-2007  1.0  James      Created                                 */  
/* 27-Apr-2010  1.1  James      Change to make compatible with RDT merge*/  
/*                              DB project (james01)                    */  
/* 12-Nov-2014  1.2  ChewKP     SOS#324045 -- ANF SKU Import (ChewKP01) */
/* 30-Sep-2016  1.3  Ung        Performance tuning                      */   
/* 05-Oct-2016  1.4  Ung        SQL2014                                 */
/* 15-Nov-2018  1.5  TungGH     Performance                             */
/************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_TBLSKU_Import](  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- RDT.RDTMobRec variables  
DECLARE  
   @nFunc          INT,  
   @nScn           INT,  
   @nStep          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nInputKey      INT,  
   @nMenu          INT,  
  
   @cStorerKey     NVARCHAR( 15),  
   @cUserName      NVARCHAR( 18),  
   @cFacility      NVARCHAR( 5),  
   @cPrinter       NVARCHAR( 10),  
  
   @cRetailSKU     NVARCHAR( 20),  
   @cTargetDB      NVARCHAR( 60),   
   @cTBLSKUDB      NVARCHAR( 60),   
   @c_SQLStatement NVARCHAR( 4000),  
   @nRetailSKU_CNT INT,  
   @cTargetStorerKey VARCHAR ( 15),  
   @nInserted      INT,  
   @cTBLSKUTBL     NVARCHAR( 60),   
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP01)  
   @cSQL                NVARCHAR(1000), -- (ChewKP01)   
   @cSQLParam           NVARCHAR(1000), -- (ChewKP01)
  
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)  
  
-- Getting Mobile information  
SELECT  
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @nMenu            = Menu,  
   @cLangCode        = Lang_code,  
  
   @cStorerKey       = StorerKey,  
   @cFacility        = Facility,  
   @cUserName        = UserName,  
   @cPrinter         = Printer,   
   
   @cExtendedUpdateSP = V_String1,    
  
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  
   @cInField15 = I_Field15,   @cOutField15 = O_Field15  
  
FROM rdt.rdtMobRec (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Screen constant  
DECLARE   
   @nStep_ScanRetailSKU INT,  @nScn_ScanRetailSKU INT,   
   @nStep_Message INT,  @nScn_Message INT   
SELECT  
   @nStep_ScanRetailSKU  = 1,  @nScn_ScanRetailSKU = 1650,   
   @nStep_Message  = 2,  @nScn_Message = 1651   
   
IF @nFunc = 960  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start          -- Menu. Func = 960  
   IF @nStep = 1  GOTO Step_ScanRetailSKU  -- Scn = 1650 Scan Retail SKU Barcode  
   IF @nStep = 2  GOTO Step_Message        -- Scn = 1651 Msg  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step_Start. Func = 960  
********************************************************************************/  
Step_Start:  
BEGIN  
    
   -- Prepare next screen var  
   SET @cOutField01 = '' -- Retail SKU Barcode  
   
    -- (ChewKP01)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
   BEGIN
      SET @cExtendedUpdateSP = ''
   END
  
   -- Go to Parent screen  
   SET @nScn = @nScn_ScanRetailSKU  
   SET @nStep = @nStep_ScanRetailSKU  
   GOTO Quit  
  
   Step_Start_Fail:  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Retail SKU Barcode  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 1580. Scan Retail SKU Barcode  
   Retail SKU Barcode    (field01, input)  
********************************************************************************/  
Step_ScanRetailSKU:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
  
      SET @cRetailSKU = @cInField01  
  
      --set target db  
--      SET @cTargetDB = 'PFCMODEL' (james01)  
  
     --if both input also blank  
     IF ISNULL(@cRetailSKU, '') = ''  
     BEGIN     
          SET @nErrNo = 63825  
          SET @cErrMsg = rdt.rdtgetmessage( 63825, @cLangCode, 'DSP') --SKU needed  
          GOTO Step_ScanRetailSKU_Fail  
     END  
     
         SET @cTBLSKUDB= rdt.RDTGetConfig( 0, 'TBLSKUCopyFromDB', @cStorerKey)   
     
     --if TBLSKU DB not setup  
     IF ISNULL(@cTBLSKUDB, '') = '' OR @cTBLSKUDB = '0' --return 0 if storerkey not defined  
     BEGIN     
          SET @nErrNo = 63826  
          SET @cErrMsg = rdt.rdtgetmessage( 63826, @cLangCode, 'DSP') --TargetDBXSetup  
          GOTO Step_ScanRetailSKU_Fail  
     END  
     
         --check if DB setup in storerconfig is a valid DB  
         IF DB_ID(@cTBLSKUDB) IS NULL  
     BEGIN     
          SET @nErrNo = 63832  
          SET @cErrMsg = rdt.rdtgetmessage( 63832, @cLangCode, 'DSP') --InvalidDBSetup  
          GOTO Step_ScanRetailSKU_Fail  
     END  
     
     
     IF @cExtendedUpdateSP <> ''
     BEGIN
               
           IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
           BEGIN
              
              SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
              ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cTBLSKUDB, @cRetailSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT '
              SET @cSQLParam =
                 '@nMobile        INT, ' +
                 '@nFunc          INT, ' +
                 '@cLangCode      NVARCHAR( 3), ' +
                 '@cUserName      NVARCHAR( 18), ' +
                 '@cFacility      NVARCHAR( 5), ' +
                 '@cStorerKey     NVARCHAR( 15), ' +
                 '@nStep          INT, ' +
                 '@cTBLSKUDB      NVARCHAR( 20), ' +
                 '@cRetailSKU     NVARCHAR( 20), ' +
                 '@nErrNo         INT           OUTPUT, ' + 
                 '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
         
              EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cTBLSKUDB, @cRetailSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
              IF @nErrNo <> 0 
                     GOTO QUIT
                  
           END        
     END 
     ELSE 
     BEGIN
        --check if TBLSKU table exists  
        SET @cTBLSKUTBL = RTRIM(@cTBLSKUDB) + '.dbo.TBLSKU'  
        
        IF OBJECT_ID(RTRIM(@cTBLSKUTBL), 'U') IS NULL   
        BEGIN     
             SET @nErrNo = 63833  
             SET @cErrMsg = rdt.rdtgetmessage( 63833, @cLangCode, 'DSP') --TBLSKUNotExist  
             GOTO Step_ScanRetailSKU_Fail  
        END  
     
        --check if exists inside TBLSKU table  
        SELECT @c_SQLStatement = N'SELECT @nRetailSKU_CNT = COUNT(SKU) FROM '   
        SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' ' + RTRIM(@cTBLSKUDB) + '.dbo.TBLSKU WITH (NOLOCK) '  
           + ' WHERE RetailSKU = N''' + RTRIM(@cRetailSKU) + ''''  
      --     + ' AND STORERKEY = ''' + RTRIM(@cStorerKey) + ''''  
         EXEC sp_executesql @c_SQLStatement, N'@nRetailSKU_CNT INT OUTPUT', @nRetailSKU_CNT OUTPUT     
         
            --not exists in TBLSKU  
            IF @nRetailSKU_CNT = 0  
            BEGIN  
             SET @nErrNo = 63827  
             SET @cErrMsg = rdt.rdtgetmessage( 63827, @cLangCode, 'DSP') --SKU Not Found  
             GOTO Step_ScanRetailSKU_Fail  
            END  
        
            --if multi exists in TBLSKU  
            IF @nRetailSKU_CNT > 1  
            BEGIN  
             SET @nErrNo = 63828  
             SET @cErrMsg = rdt.rdtgetmessage( 63828, @cLangCode, 'DSP') --MultiSKUFound  
             GOTO Step_ScanRetailSKU_Fail  
            END  
        
            SELECT @nInserted = 0  
        
            --check if storer config setup in rdt.storerconfig  
            IF NOT EXISTS (SELECT 1 FROM RDT.StorerConfig WITH (NOLOCK)   
               WHERE ConfigKey = 'TBLSKUCopyToStorer'  
               AND SValue = '1')  
            BEGIN  
                SET @nErrNo = 63829  
                SET @cErrMsg = rdt.rdtgetmessage( 63829, @cLangCode, 'DSP') --SetupToStorer  
                GOTO Step_ScanRetailSKU_Fail  
            END  
        
            DECLARE C_Import_TBLSKU CURSOR FAST_FORWARD READ_ONLY FOR   
            SELECT StorerKey FROM rdt.StorerConfig WITH (NOLOCK)   
            WHERE ConfigKey = 'TBLSKUCopyToStorer'  
            AND SValue = '1'  
            OPEN C_Import_TBLSKU  
            FETCH NEXT FROM C_Import_TBLSKU INTO @cTargetStorerKey  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               /* (james01)  
               --check if exists inside WMS SKU table  
             SELECT @c_SQLStatement = N'SELECT @nRetailSKU_CNT = COUNT(RETAILSKU) FROM '   
           SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' ' + RTRIM(@cTargetDB) + '.dbo.SKU WITH (NOLOCK) '  
              + ' WHERE RetailSKU = N''' + RTRIM(@cRetailSKU) + ''''  
              + ' AND STORERKEY = N''' + RTRIM(@cTargetStorerKey) + ''''  
            EXEC sp_executesql @c_SQLStatement, N'@nRetailSKU_CNT INT OUTPUT', @nRetailSKU_CNT OUTPUT     
               */  
               SELECT @nRetailSKU_CNT = COUNT(RETAILSKU) FROM dbo.SKU WITH (NOLOCK)  
               WHERE RetailSKU = @cRetailSKU  
                  AND STORERKEY = @cTargetStorerKey  
        
               --if not exists in WMS SKU table  
               IF @nRetailSKU_CNT = 0  
               BEGIN  
                  --begin insert SKU from TBLSKU to SKU  
                  BEGIN TRAN  
      --               SELECT @c_SQLStatement = N'INSERT INTO ' + RTRIM(@cTargetDB) + '.dbo.SKU '  (james01)  
                     SELECT @c_SQLStatement = N'INSERT INTO dbo.SKU '  
                     + '(StorerKey, Sku, DESCR, SUSR1, SUSR2, SUSR3, '  
                     + 'SUSR4, SUSR5, MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, '  
                     + 'STDGROSSWGT, STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, '  
                     + 'SKUGROUP, Tariffkey, BUSR1, BUSR2, BUSR3, BUSR4, '  
                     + 'BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL, LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, '  
                     + 'NOTES1, NOTES2, PickCode, StrategyKey, CartonGroup, PutCode, '  
                     + 'PutawayLoc, PutawayZone, InnerPack, [Cube], GrossWgt, NetWgt, '  
                     + 'ABC, CycleCountFrequency, LastCycleCount, ReorderPoint, ReorderQty, StdOrderCost, '  
                     + 'CarryCost, Price, Cost, ReceiptHoldCode, ReceiptInspectionLoc, OnReceiptCopyPackkey, '  
                     + 'TrafficCop, ArchiveCop, IOFlag, TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, '  
                     + 'LotxIdDetailOtherlabel3, AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, '  
                     + 'Height, weight, itemclass, ShelfLife, Facility, BUSR6, '  
                     + 'BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc, XDockReceiptLoc, PrePackIndicator, '  
                     + 'PackQtyIndicator, StackFactor, IVAS, OVAS) '  
                     + 'SELECT N''' + RTRIM(@cTargetStorerKey) + ''' AS STORERKEY, '    
                     + 'Sku, DESCR, SUSR1, SUSR2, SUSR3, '   
                     + 'SUSR4, SUSR5, MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, '  
                     + 'STDGROSSWGT, STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, '  
                     + 'SKUGROUP, Tariffkey, BUSR1, BUSR2, BUSR3, BUSR4, '  
                     + 'BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL, LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, '  
                     + 'NOTES1, NOTES2, PickCode, StrategyKey, CartonGroup, PutCode, '  
                     + 'PutawayLoc, PutawayZone, InnerPack, [Cube], GrossWgt, NetWgt, '  
                     + 'ABC, CycleCountFrequency, LastCycleCount, ReorderPoint, ReorderQty, StdOrderCost, '  
                     + 'CarryCost, Price, Cost, ReceiptHoldCode, ReceiptInspectionLoc, OnReceiptCopyPackkey, '  
                     + 'TrafficCop, ArchiveCop, IOFlag, TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, '  
                     + 'LotxIdDetailOtherlabel3, AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, '  
                     + 'Height, weight, itemclass, ShelfLife, Facility, BUSR6, '  
                     + 'BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc, XDockReceiptLoc, PrePackIndicator, '   
                     + 'PackQtyIndicator, StackFactor, IVAS, OVAS '  
                     + 'FROM '+ RTRIM(@cTBLSKUDB) + '.dbo.TBLSKU WITH (NOLOCK) '  
                     + 'WHERE RETAILSKU = RTRIM(@cRetailSKU) '  
        
                     EXEC sp_executeSql @c_SQLStatement,  
                     N'@cRetailSKU NVARCHAR(60)', @cRetailSKU  
            
                     IF @@ERROR <> 0   
                     BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 63831  
                      SET @cErrMsg = rdt.rdtgetmessage( 63831, @cLangCode, 'DSP') --InsertSKUFail  
                        CLOSE C_Import_TBLSKU  
                        DEALLOCATE C_Import_TBLSKU  
                      GOTO Step_ScanRetailSKU_Fail  
                     END          
        
                     COMMIT TRAN      
                     SELECT @nInserted = @nInserted + 1       
                  END   --@nRetailSKU_CNT = 0  
                  FETCH NEXT FROM C_Import_TBLSKU INTO @cTargetStorerKey  
            END  
            CLOSE C_Import_TBLSKU  
            DEALLOCATE C_Import_TBLSKU  
        
            IF @nInserted = 0  
            BEGIN  
             SET @nErrNo = 63830  
               SET @cErrMsg = rdt.rdtgetmessage( 63830, @cLangCode, 'DSP') --SKU Exists  
               GOTO Step_ScanRetailSKU_Fail  
            END  
     END
     
     
     SET @nScn = @nScn_Message  
     SET @nStep = @nStep_Message  
     GOTO Quit  
     
   END  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN    
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Retail SKU Barcode  
   END  
     
   GOTO Quit  
  
   Step_ScanRetailSKU_Fail:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
   
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 1651. Message Screen  
********************************************************************************/  
Step_Message:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cOutField01 = '' -- Retail SKU Barcode  
  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
  
      GOTO Quit  
   END  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN    
      SET @cOutField01 = '' -- Retail SKU Barcode  
  
      -- Go to prev screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
     
   GOTO Quit  
END  
GOTO Quit  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,  
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey    = @cStorerKey,  
      Facility     = @cFacility,  
      -- UserName     = @cUserName,  
      Printer      = @cPrinter,   
      
      V_String1    = @cExtendedUpdateSP,     
     
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  
      I_Field15 = @cInField15,  O_Field15 = @cOutField15  
   WHERE Mobile = @nMobile  
END  
  
  
SET QUOTED_IDENTIFIER OFF

GO