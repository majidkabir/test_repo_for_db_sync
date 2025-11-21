SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/        
/* Store procedure: rdt_593PrintLOGITECH                                   */        
/*                                                                         */        
/* Modifications log:                                                      */        
/*                                                                         */        
/* Date       Rev  Author   Purposes                                       */        
/* 2017-08-02 1.0  ChewKP   WMS-1931 Created                               */  
/* 2021-02-03 1.1  Ung      WMS-18794 Add bundle SKU label                 */    
/***************************************************************************/        
        
CREATE   PROC [RDT].[rdt_593PrintLOGITECH] (        
   @nMobile    INT,        
   @nFunc      INT,        
   @nStep      INT,        
   @cLangCode  NVARCHAR( 3),        
   @cStorerKey NVARCHAR( 15),        
   @cOption    NVARCHAR( 1),        
   @cParam1    NVARCHAR(20),  -- OrderKey     
   @cParam2    NVARCHAR(20),      
   @cParam3    NVARCHAR(20),         
   @cParam4    NVARCHAR(20),        
   @cParam5    NVARCHAR(20),        
   @nErrNo     INT OUTPUT,        
   @cErrMsg    NVARCHAR( 20) OUTPUT        
)        
AS        
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF         
        
   DECLARE @b_Success     INT,        
           @cWorkOrderNo      NVARCHAR( 10),    
           @cFromSKUInput     NVARCHAR( 20),       
           @cToSKUInput       NVARCHAR( 20),       
           @cSerialNo         NVARCHAR( 20),    
           @nSKUCnt           INT,    
           @cFromSKU          NVARCHAR( 20),    
           @cToSKU            NVARCHAR( 20),     
           @cBatchKey         NVARCHAR( 10),    
           @n9LQty            INT,    
           @nInnerQty         INT,    
           @nMasterQty        INT,    
           @c9LNewLabel       NVARCHAR(1),    
           @cInnerNewLabel    NVARCHAR(1),    
           @cMasterNewLabel   NVARCHAR(1),    
           @n9LCount          INT,    
           @cToSerialNo       NVARCHAR(20),    
           @nInnerCount       INT,    
           @nMasterCount      INT,    
           @nRowRef           INT,    
           @cFromSerialNo     NVARCHAR(20),    
           @cParentSerialNo   NVARCHAR(20),    
           @cInnerSerialNo    NVARCHAR(20),    
           @cMasterSerialNo   NVARCHAR(20),     
           @nMasterSerialNoKey INT,    
           @cSKU              NVARCHAR(20),    
           @cSKUInput         NVARCHAR(20),    
           @c9LSerialNo       NVARCHAR(20),    
           @cRemarks          NVARCHAR(20),    
           @cGenSerialSP      NVARCHAR(30),    
           @cSQL              NVARCHAR(1000),     
           @cSQLParam         NVARCHAR(1000),     
           @cPrinter9L        NVARCHAR( 20),          
           @cPrinterInner     NVARCHAR( 20),          
           @cPrinterMaster    NVARCHAR( 20),          
           @cPrinterGTIN      NVARCHAR( 20),    
           @cStatus           NVARCHAR( 10),    
           @cLocationCode     NVARCHAR( 10),    
           @nMasterUnitQty    INT,    
           --@nMasterQty        INT,    
           @cGenerateLabel    NVARCHAR(1),    
           @cWorkOrderSKU     NVARCHAR(20),    
           @cPackKey          NVARCHAR(10),    
           @nInnerPack        INT,    
           @nCaseCnt          INT,    
           @cSerialType       NVARCHAR(1),    
           @cChildSerialNo    NVARCHAR(20),    
           @cPassed           NVARCHAR(1),    
           @nScanCount        INT,    
           @nCLabelQty        INT,    
           @cExtendedUpdateSP NVARCHAR(30),     
           @nFromFunc         INT,    
           @nFocusParam       INT,    
           @cFacility         NVARCHAR( 5),    
           @nTranCount        INT,    
           @cUserName         NVARCHAR(18),    
           @nCount            INT,    
           @nInputKEy         INT,    
           @cDataWindow     NVARCHAR( 50),      
 @cTargetDB      NVARCHAR( 20),    
           @nSKULength        INT,    
           @cDataWindowGTIN   NVARCHAR( 50),    
           @cReportType       NVARCHAR( 10),    
           @nNoOfCopy         INT    
       
    
       
       
   SELECT @cFacility = Facility     
         ,@cUserName = UserName    
         ,@nInputKey = InputKey    
   FROM rdt.rdtMobRec WITH (NOLOCK)     
   WHERE Mobile = @nMobile     
    
       
    
   SET @cGenSerialSP = ''      
   SET @cGenSerialSP = rdt.RDTGetConfig( @nFunc, 'GenSerialSP', @cStorerKey)      
   IF @cGenSerialSP = '0'        
   BEGIN      
      SET @cGenSerialSP = ''      
   END       
    
   IF @cOption IN ( '1','2','3', '9')    
   BEGIN    
      SET @cWorkOrderNo       = @cParam1    
      SET @cSKUInput          = @cParam3    
      SET @nMasterQty         = @cParam5    
       
      IF @cWorkOrderNo = ''    
      BEGIN    
         SET @nErrNo = 113301          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WorkOrdeRNoReq        
         SET @nFocusParam = 1    
         GOTO Quit      
      END    
             
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)      
                      WHERE StorerKey = @cStorerKey      
                      AND Facility = @cFacility      
                      AND WorkOrderKey = @cWorkOrderNo )       
      BEGIN      
         SET @nErrNo = 113302          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvdWorkOrder    
         SET @nFocusParam = 1    
         GOTO Quit      
      END        
          
      IF @cSKUInput = ''          
      BEGIN          
         SET @nErrNo = 113303          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'    
         SET @nFocusParam = 6    
         GOTO Quit         
      END          
          
      -- Get SKU barcode count        
      --DECLARE @nSKUCnt INT        
      EXEC rdt.rdt_GETSKUCNT        
          @cStorerKey  = @cStorerKey        
         ,@cSKU        = @cSKUInput        
         ,@nSKUCnt     = @nSKUCnt       OUTPUT        
         ,@bSuccess    = @b_Success     OUTPUT        
         ,@nErr        = @nErrNo        OUTPUT        
         ,@cErrMsg     = @cErrMsg       OUTPUT        
          
      -- Check SKU/UPC        
      IF @nSKUCnt = 0        
      BEGIN        
         SET @nErrNo = 113304        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU      
         SET @nFocusParam = 6    
         GOTO Quit         
      END        
          
      -- Check multi SKU barcode        
      IF @nSKUCnt > 1        
      BEGIN        
         SET @nErrNo = 113305     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod        
         SET @nFocusParam = 6    
         GOTO Quit        
      END        
          
      -- Get SKU code        
      EXEC rdt.rdt_GETSKU        
          @cStorerKey  = @cStorerKey        
         ,@cSKU        = @cSKUInput     OUTPUT        
         ,@bSuccess    = @b_Success     OUTPUT        
         ,@nErr        = @nErrNo        OUTPUT        
         ,@cErrMsg     = @cErrMsg       OUTPUT        
          
      IF @nErrNo = 0     
      BEGIN    
         SET @cSKU = @cSKUInput    
      END    
          
      SELECT     
                 
            @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')    
      FROM dbo.WorkOrder WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND WorkOrderKey = @cWorkOrderNo     
          
      SELECT TOP 1 @cGenerateLabel = ISNULL(WKORDUDef1,'')     
      FROM dbo.WorkOrderDetail WITH (NOLOCK)     
      WHERE WorkOrderKey = @cWorkOrderNo     
                
          
      IF @cSKU <> @cWorkOrderSKU    
      BEGIN    
         SET @nErrNo = 113306    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU        
         SET @nFocusParam = 2    
         GOTO Quit      
      END    
          
          
      --IF @nMasterQty = ''    
      --BEGIN    
 --   SET @nErrNo = 109808    
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QtyReq'    
      --   SET @nMasterQty = 0     
      --   EXEC rdt.rdtSetFocusField @nMobile, 2    
      --   GOTO Step_2_Fail    
      --END    
          
      IF RDT.rdtIsValidQTY( @nMasterQty, 1) = 0    
      BEGIN    
         SET @nErrNo = 113307    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'    
         SET @nFocusParam = 10    
         GOTO Quit      
      END    
   END    
       
          
   SET @nTranCount = @@TRANCOUNT          
             
   BEGIN TRAN          
   SAVE TRAN rdt_593PrintLOGITECH          
       
   SELECT @cPrinter9L = UDF01     
         ,@cPrinterInner = UDF02     
         ,@cPrinterMaster = UDF03    
         ,@cPrinterGTIN = UDF04    
   FROM dbo.CodeLkup WITH (NOLOCK)     
   WHERE ListName = 'SERIALPRN'    
   AND StorerKey = @cStorerKey    
   AND Code = @cUserName     
       
   SELECT @cPackKey = PackKey    
   FROM dbo.SKU WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND SKU         = @cSKU    
       
   SELECT @nInnerPack = ISNULL(InnerPack,0)     
         ,@nCaseCnt  = ISNULL(CaseCnt,0)     
   FROM dbo.Pack WITH (NOLOCK)     
   WHERE PackKey = @cPackKey     
       
   SET @n9LQty     = 0     
   SET @nInnerQty  = 0     
       
       
   --SET @n9LQty = @nMasterQty * @nCaseCnt    
       
   --IF @nInnerPack > 0     
   --BEGIN    
   --    SET @nInnerQty  = @nMasterQty * ( @nCaseCnt / @nInnerPack )     
   --END     
             
   IF @cOption = '1'     
   BEGIN     
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderDetail WITH (NOLOCK)     
                     WHERE WorkOrderKey = @cWorkOrderNo     
                     AND Unit = '9L'    
                     AND WkOrdUDef1 = '1' )     
         BEGIN                 
            -- Print 9L     
            SET @nCount = 1     
            WHILE @nCount <= @nMasterQty    
            BEGIN    
                  
    
               SET @c9LSerialNo = ''    
                   
               IF @cGenSerialSP <> ''      
               BEGIN      
                    IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')      
                    BEGIN      
                              
    
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +      
                                    ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'      
                        SET @cSQLParam =      
                           ' @nMobile                   INT,                     '+    
                           ' @nFunc                     INT,                     '+    
                           ' @cLangCode                 NVARCHAR( 3),            '+    
                           ' @nStep                     INT,                     '+    
                           ' @nInputKey                 INT,                     '+    
                           ' @cStorerkey                NVARCHAR( 15),           '+    
                           ' @cFromSKU                  NVARCHAR( 20),           '+    
                           ' @cToSKU                    NVARCHAR( 20),           '+    
                           ' @cSerialNo                 NVARCHAR( 20),           '+    
                           ' @cSerialType               NVARCHAR( 10),           '+    
                           ' @cWorkOrderKey             NVARCHAR( 10),           '+    
                           ' @cBatchKey                 NVARCHAR( 10),           '+    
                           ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+    
                           ' @nErrNo                    INT           OUTPUT,    '+    
                           ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '    
                               
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                           @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cSKU ,@cSKU ,@cSerialNo ,'EACHES' ,@cWorkOrderNo ,@cBatchKey ,@c9LSerialNo OUTPUT,@nErrNo OUTPUT ,@cErrMsg OUTPUT    
                     
                            
    
                        IF @nErrNo <> 0       
                        BEGIN      
                           SET @nErrNo = 113308        
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'        
                           SET @nFocusParam = 1    
                           GOTO RollBackTran      
                        END      
                    END      
               END     
                   
               SELECT @cDataWindow = DataWindow,         
               @cTargetDB = TargetDB         
         FROM rdt.rdtReport WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND   ReportType = 'LOG9LLABEL'       
             
         -- Bartender No Datawindow Required (SHONG)    
         IF ISNULL(@c9LSerialNo,'')  <> ''      
         BEGIN    
            EXEC RDT.rdt_BuiltPrintJob          
                         @nMobile,          
                         @cStorerKey,          
                         'LOG9LLABEL',  -- ReportType          
                         'Serial9L',    -- PrintJobName          
                         @cDataWindow,          
                         @cPrinter9L,          
                         @cTargetDB,          
                         @cLangCode,          
                         @nErrNo  OUTPUT,          
                         @cErrMsg OUTPUT,     
                         @c9LSerialNo     
                             
         END    
                   
               SET @nCount = @nCount + 1     
            END     
         END    
          
   END           
       
   IF @cOption = '2'     
   BEGIN     
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderDetail WITH (NOLOCK)     
                     WHERE WorkOrderKey = @cWorkOrderNo     
                     AND Unit = 'Inner'    
                     AND WkOrdUDef1 = '1' )     
         BEGIN      
            SET @nCount = 1     
            WHILE @nCount <= @nMasterQty    
            BEGIN    
               SET @cInnerSerialNo = ''    
               IF @cGenSerialSP <> ''      
               BEGIN      
                     
                 IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')      
                 BEGIN      
                           
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +      
                     ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'      
                     SET @cSQLParam =      
                        ' @nMobile                   INT,                     '+    
                        ' @nFunc                     INT,                     '+    
                        ' @cLangCode                 NVARCHAR( 3),            '+    
                        ' @nStep                     INT,                     '+    
                        ' @nInputKey                 INT,                     '+    
                        ' @cStorerkey                NVARCHAR( 15),           '+    
                        ' @cFromSKU                  NVARCHAR( 20),           '+    
                        ' @cToSKU                    NVARCHAR( 20),           '+    
                        ' @cSerialNo                 NVARCHAR( 20),           '+    
                        ' @cSerialType               NVARCHAR( 10),           '+    
                        ' @cWorkOrderKey             NVARCHAR( 10),           '+    
                        ' @cBatchKey                 NVARCHAR( 10),           '+    
                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+    
                        ' @nErrNo                    INT           OUTPUT,    '+    
                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '    
                            
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cSKU ,@cSKU ,@cSerialNo ,'INNER' ,@cWorkOrderNo ,@cBatchKey ,@cInnerSerialNo OUTPUT,@nErrNo OUTPUT ,@cErrMsg OUTPUT    
                     
                         
    
                     IF @nErrNo <> 0       
                     BEGIN      
                        SET @nErrNo = 113309        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'        
                        SET @nFocusParam = 1    
                        GOTO RollBackTran      
                     END      
                 END      
                     
               END     
                   
               -- Print LabelNo     
               SELECT @cDataWindow = DataWindow,         
               @cTargetDB = TargetDB         
         FROM rdt.rdtReport WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND   ReportType = 'LOGMASTLBL'       
             
         -- Bartender No Datawindow Required (SHONG)    
         IF ISNULL(@cInnerSerialNo,'')  <> '' AND @nInnerPack > 0     
         BEGIN    
            EXEC RDT.rdt_BuiltPrintJob          
                         @nMobile,          
                         @cStorerKey,          
                         'LOGMASTLBL',    -- ReportType          
                         'SerialInnner',    -- PrintJobName          
                         @cDataWindow,          
                         @cPrinterInner,          
                         @cTargetDB,          
                         @cLangCode,          
                         @nErrNo  OUTPUT,          
                         @cErrMsg OUTPUT,     
                         @cStorerKey,    
                       @cSKU,       
                       @cWorkOrderNo,    
                       @nInnerPack,    
                       @cInnerSerialNo    
         END    
               SET @nCount = @nCount + 1     
            END               
         END    
   END    
       
   IF @cOption = '3'     
   BEGIN     
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderDetail WITH (NOLOCK)     
                     WHERE WorkOrderKey = @cWorkOrderNo     
                     AND Unit = 'Master'    
                     AND WkOrdUDef1 = '1' )     
         BEGIN          
            SET @nCount = 1     
            WHILE @nCount <= @nMasterQty    
            BEGIN    
               SET @cMasterSerialNo = ''    
               IF @cGenSerialSP <> ''      
               BEGIN      
                         
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')      
                     BEGIN      
                              
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +      
                        ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'      
                        SET @cSQLParam =      
                           ' @nMobile                   INT,                     '+    
                           ' @nFunc                     INT,                     '+    
                           ' @cLangCode                 NVARCHAR( 3),            '+    
                           ' @nStep                     INT,                     '+    
                           ' @nInputKey                 INT,     '+    
                           ' @cStorerkey                NVARCHAR( 15),           '+    
                           ' @cFromSKU                  NVARCHAR( 20),           '+    
                           ' @cToSKU                    NVARCHAR( 20),           '+    
                           ' @cSerialNo                 NVARCHAR( 20),           '+    
                           ' @cSerialType               NVARCHAR( 10),           '+    
                           ' @cWorkOrderKey             NVARCHAR( 10),           '+    
                           ' @cBatchKey                 NVARCHAR( 10),           '+    
                           ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+    
                           ' @nErrNo                    INT           OUTPUT,    '+    
                           ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '    
                               
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                           @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cSKU ,@cSKU ,@cSerialNo ,'MASTER' ,@cWorkOrderNo ,@cBatchKey ,@cMasterSerialNo OUTPUT, @nErrNo OUTPUT ,@cErrMsg OUTPUT    
               
                            
    
                        IF @nErrNo <> 0       
                        BEGIN      
                           SET @nErrNo = 113310        
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'        
                           SET @nFocusParam = 1    
                           GOTO RollBackTran      
                        END      
                    END      
               END     
                   
               -- Print LabelNo     
               SELECT @cDataWindow = DataWindow,         
               @cTargetDB = TargetDB         
         FROM rdt.rdtReport WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND   ReportType = 'LOGMASTLBL'       
             
         -- Bartender No Datawindow Required (SHONG)     
         IF ISNULL(@cMasterSerialNo,'')  <> ''     
         BEGIN    
            EXEC RDT.rdt_BuiltPrintJob          
                         @nMobile,          
                         @cStorerKey,          
                         'LOGMASTLBL',    -- ReportType          
                         'SerialMaster',    -- PrintJobName          
                         @cDataWindow,          
                         @cPrinterMaster,          
                         @cTargetDB,          
                         @cLangCode,          
                         @nErrNo  OUTPUT,          
                         @cErrMsg OUTPUT,     
                         @cStorerKey,    
                       @cSKU,       
                       @cWorkOrderNo,    
                       @nCaseCnt,    
                       @cMasterSerialNo    
         END    
                   
               SET @nCount = @nCount + 1     
            END    
         END    
   END    
       
   IF @cOption = '4'    
   BEGIN    
      SET @cSerialNo = @cParam1    
          
      IF @cSerialNo = ''     
      BEGIN    
         SET @nErrNo = 113311        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SerialNoReq'        
         SET @nFocusParam = 1    
         GOTO RollBackTran      
      END    
          
      IF  RIGHT ( @cSerialNo, 1 ) <> 'C'     
      BEGIN    
         SET @nErrNo = 113312    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidSerialNo'        
         SET @nFocusParam = 1    
         GOTO RollBackTran      
      END    
          
          
      EXEC RDT.rdt_BuiltPrintJob          
           @nMobile,          
           @cStorerKey,          
           'LOG9LLABEL',  -- ReportType          
           'Serial9L',    -- PrintJobName          
           @cDataWindow,          
           @cPrinter9L,          
           @cTargetDB,          
           @cLangCode,          
           @nErrNo  OUTPUT,          
           @cErrMsg OUTPUT,     
           @cSerialNo     
          
          
   END    
       
   IF @cOption = '5'    
   BEGIN    
      SET @cSKUInput = @cParam1    
      SET @nNoOfCopy = @cParam3    
    
      IF @cSKUInput = ''          
  BEGIN          
         SET @nErrNo = 113313          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'    
         SET @nFocusParam = 1    
         GOTO RollBackTran         
      END          
          
          
      -- Get SKU barcode count        
      --DECLARE @nSKUCnt INT        
      EXEC rdt.rdt_GETSKUCNT        
          @cStorerKey  = @cStorerKey        
         ,@cSKU        = @cSKUInput        
         ,@nSKUCnt     = @nSKUCnt       OUTPUT        
         ,@bSuccess    = @b_Success     OUTPUT        
         ,@nErr        = @nErrNo        OUTPUT        
         ,@cErrMsg     = @cErrMsg       OUTPUT        
          
      -- Check SKU/UPC        
      IF @nSKUCnt = 0        
      BEGIN        
         SET @nErrNo = 113314        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU      
         SET @nFocusParam = 1    
         GOTO RollBackTran         
      END        
          
      -- Check multi SKU barcode        
      IF @nSKUCnt > 1        
      BEGIN        
         SET @nErrNo = 113315     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod        
         SET @nFocusParam = 1    
         GOTO RollBackTran        
      END        
          
      -- Get SKU code        
      EXEC rdt.rdt_GETSKU        
          @cStorerKey  = @cStorerKey        
         ,@cSKU        = @cSKUInput     OUTPUT        
         ,@bSuccess    = @b_Success     OUTPUT        
         ,@nErr        = @nErrNo        OUTPUT        
         ,@cErrMsg     = @cErrMsg       OUTPUT        
          
      IF @nErrNo = 0     
      BEGIN    
         SET @cSKU = @cSKUInput    
      END    
          
      SELECT @nSKULength = LEN(ManufacturerSKU )     
  FROM dbo.SKU WITH (NOLOCK)     
  WHERE StorerKey = @cStorerKey    
  AND SKU = @cSKU     
    
      --INSERT INTO TraceInfo (TraceName , TimeIn , Col1, Col2 )     
      --VALUES ( 'rdt_593PrintLOGITECH' , Getdate() , @cSKU , @nSKULength )     
      
  IF @nSKULength NOT IN ( 12, 13 )     
  BEGIN    
     SET @nErrNo = 113316    
         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLength        
         SET @cErrMsg = @nSKULength       
         SET @nFocusParam = 1    
         GOTO RollBackTran        
    END    
        
    IF ISNULL(@nNoOfCopy, 0 ) = 0     
    BEGIN    
       SET @nNoOfCopy = 1     
    END    
    ELSE    
    BEGIN    
       IF rdt.rdtIsValidQTY( @nNoOfCopy, 0) = 0    
         BEGIN    
            SET @nErrNo = 95495    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidValues'    
            --EXEC rdt.rdtSetFocusField @nMobile, 6    
            SET @nFocusParam = 2    
            GOTO RollBackTran    
         END    
             
         IF @nNoOfCopy > 100     
         BEGIN    
            SET @nErrNo = 95496    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidValues'    
            --EXEC rdt.rdtSetFocusField @nMobile, 6    
            SET @nFocusParam = 2    
            GOTO RollBackTran    
         END    
      END    
        
    IF @nSKULength = 12     
    BEGIN    
         SELECT @cDataWindowGTIN = DataWindow,         
                  @cTargetDB = TargetDB         
       FROM rdt.rdtReport WITH (NOLOCK)         
     WHERE StorerKey = @cStorerKey        
     AND   ReportType = 'LOGGTINLBL'    
    
         SET @cReportType = 'LOGGTINLBL'     
    
    END    
    ELSE IF @nSKULength = 13    
    BEGIN    
       SELECT @cDataWindowGTIN = DataWindow,         
                  @cTargetDB = TargetDB         
       FROM rdt.rdtReport WITH (NOLOCK)         
     WHERE StorerKey = @cStorerKey        
     AND   ReportType = 'LOGGTINLBA'    
    
         SET @cReportType = 'LOGGTINLBA'     
    END    
      
  SET @nCount = 0     
      
  WHILE @nCount < @nNoOfCopy     
  BEGIN    
          
          EXEC RDT.rdt_BuiltPrintJob          
         @nMobile,          
         @cStorerKey,          
        @cReportType,    -- ReportType          
         'GTIN',    -- PrintJobName          
         @cDataWindowGTIN,          
         @cPrinterGTIN,          
         @cTargetDB,          
         @cLangCode,          
         @nErrNo  OUTPUT,          
         @cErrMsg OUTPUT,     
         @cStorerKey,    
         @cSKU    
          
       SET @nCount = @nCount + 1     
           
    END    
          
   END    
       
   IF @cOption = '9'
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.WorkOrderDetail WITH (NOLOCK)
                  WHERE WorkOrderKey = @cWorkOrderNo
                  AND Unit = '9L-BUNDLE'
                  AND WkOrdUDef1 = '1' )
      BEGIN
         DECLARE @t9LBundleLabel AS VariableTable

         -- Print 9L
         SET @nCount = 1
         WHILE @nCount <= @nMasterQty
         BEGIN
            SET @c9LSerialNo = ''

            IF @cGenSerialSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, ' + 
                     ' @cFromSKU, @cToSKU, @cSerialNo, @cSerialType, @cWorkOrderKey, @cBatchKey, ' +
                     ' @cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT '
                  SET @cSQLParam =
                     ' @nMobile        INT,                  '+
                     ' @nFunc          INT,                  '+
                     ' @cLangCode      NVARCHAR( 3),         '+
                     ' @nStep          INT,                  '+
                     ' @nInputKey      INT,                  '+
                     ' @cStorerkey     NVARCHAR( 15),        '+
                     ' @cFromSKU       NVARCHAR( 20),        '+
                     ' @cToSKU         NVARCHAR( 20),        '+
                     ' @cSerialNo      NVARCHAR( 20),        '+
                     ' @cSerialType    NVARCHAR( 10),        '+
                     ' @cWorkOrderKey  NVARCHAR( 10),        '+
                     ' @cBatchKey      NVARCHAR( 10),        '+
                     ' @cNewSerialNo   NVARCHAR( 20) OUTPUT, '+
                     ' @nErrNo         INT           OUTPUT, '+
                     ' @cErrMsg        NVARCHAR( 20) OUTPUT   '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey,
                     @cSKU, @cSKU, @cSerialNo, 'EACHES', @cWorkOrderNo, @cBatchKey,
                     @c9LSerialNo OUTPUT, @nErrNo OUTPUT ,@cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 113308
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'
                     SET @nFocusParam = 1
                     GOTO RollBackTran
                  END
               END
            END

            -- Bartender No Datawindow Required (SHONG)
            IF ISNULL(@c9LSerialNo,'')  <> ''
            BEGIN
               -- Get work order info
               DECLARE @cWkOrdUdef1 NVARCHAR( 18)
               DECLARE @cWkOrdUdef2 NVARCHAR( 18)
               SELECT
                  @cWkOrdUdef1 = ISNULL( WkOrdUdef1, ''), 
                  @cWkOrdUdef2 = ISNULL( WkOrdUdef2, '')
               FROM dbo.WorkOrder WITH (NOLOCK)
               WHERE WorkOrderKey = @cWorkOrderNo
               
               -- Common params
               DELETE @t9LBundleLabel
               INSERT INTO @t9LBundleLabel (Variable, Value) VALUES   
                  ( '@cStorerKey',     @cStorerKey),   
                  ( '@cSKU',           @cSKU),   
                  ( '@c9LSerialNo',    @c9LSerialNo),   
                  ( '@cWkOrdUdef1',    @cWkOrdUdef1),   
                  ( '@cWkOrdUdef2',    @cWkOrdUdef2)  
     
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPrinterMaster, '',   
                  'LOG9LBLBL',     -- Report type  
                  @t9LBundleLabel, -- Report params  
                  'rdt_593PrintLOGITECH',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
               IF @nErrNo <> 0  
                  GOTO Quit  
            END

            SET @nCount = @nCount + 1
         END
      END
   END

   GOTO QUIT           
             
RollBackTran:          
   ROLLBACK TRAN rdt_593PrintLOGITECH -- Only rollback change made here          
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam    
   
Quit:          
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started          
      COMMIT TRAN rdt_593PrintLOGITECH        
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam     

GO