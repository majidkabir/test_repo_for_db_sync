SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdtVFPPAExtUpd                                      */    
/* Purpose: Print dispatch label                                        */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2013-01-03 1.0  Ung        SOS265337. Created                        */    
/* 2014-06-03 1.1  Ung        SOS303019. Add InputKey param             */    
/* 2014-07-16 1.2  Ung        SOS316336. Add pick and pack QTY check    */    
/* 2015-01-30 3.4  Ung        SOS331668 Add Print packing list screen   */    
/* 2017-06-02 3.5  James      Add new param (james01)                   */   
/* 2019-06-25 3.6  Shong      Performance Tuning (SWT01)                */   
/* 2019-09-18 3.7  LZG        INC0844811 - Add optional params (ZG01)   */    
/* 2022-09-08 3.8  James      WMS-20689 - Add Reasonkey (james02)       */    
/*                            Step 2 skip print label if found variance */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdtVFPPAExtUpd] (    
   @nMobile     INT,    
   @nFunc       INT,     
   @cLangCode   NVARCHAR( 3),     
   @nStep       INT,     
   @nInputKey   INT,     
   @cStorerKey  NVARCHAR( 15),    
   @cRefNo      NVARCHAR( 10),     
   @cPickSlipNo NVARCHAR( 10),    
   @cLoadKey    NVARCHAR( 10),    
   @cOrderKey   NVARCHAR( 10),     
   @cDropID     NVARCHAR( 20),    
   @cSKU        NVARCHAR( 20),    
   @nQty        INT,    
   @cOption     NVARCHAR( 1),     
   @nErrNo      INT       OUTPUT,     
   @cErrMsg     NVARCHAR( 20) OUTPUT,    
   @cID             NVARCHAR( 18) = '',    -- ZG01    
   @cTaskDetailKey  NVARCHAR( 10) = '',     -- ZG01    
   @cReasonCode  NVARCHAR(20) OUTPUT
)    
AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @cLabelPrinter       NVARCHAR( 10)    
   DECLARE @cDataWindow         NVARCHAR( 50)     
   DECLARE @cTargetDB           NVARCHAR( 20)     
   DECLARE @cPrintDispatchLabel NVARCHAR( 1)    
   DECLARE @nCartonNo           INT    
   DECLARE @cFacility           NVARCHAR( 5)
   DECLARE @cPUOM               NVARCHAR( 10)
   
   -- Get Order info    
   DECLARE @cSOStatus NVARCHAR(10)    
   SET @cSOStatus = '' -- SWT01    
       
   --SELECT      
   --   @cStorerKey = O.StorerKey,     
   --   @cOrderKey = O.OrderKey,     
   --   @cSOStatus = O.SOStatus    
   --FROM dbo.Orders O WITH (NOLOCK)     
   --JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
   --WHERE PD.PickSlipNo = @cPickSlipNo    
    
   -- SWT01     
   --SELECT TOP 1     
   --   @cStorerKey = O.StorerKey,     
   --   @cOrderKey = O.OrderKey,     
   --   @cSOStatus = O.SOStatus    
   --FROM dbo.Orders O WITH (NOLOCK)        
   --WHERE EXISTS(SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)     
   --             WHERE PD.PickSlipNo = @cPickSlipNo     
   --             AND O.OrderKey = PD.OrderKey )      
       
   IF @nStep = 1 -- DropID    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         -- Get PickSlipNo    
         SELECT TOP 1 @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cDropID    

         SELECT TOP 1     
            @cStorerKey = O.StorerKey,     
            @cOrderKey = O.OrderKey,     
            @cSOStatus = O.SOStatus    
         FROM dbo.Orders O WITH (NOLOCK)        
         WHERE EXISTS(SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)     
                      WHERE PD.PickSlipNo = @cPickSlipNo     
                      AND O.OrderKey = PD.OrderKey )    
                
         IF @cDropID <> ''    
         BEGIN    
            IF EXISTS( SELECT TOP 1 1    
               FROM     
               (    
                  SELECT SKU, ISNULL( SUM( QTY), 0) QTY    
                  FROM dbo.PickDetail WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey     
                     AND DropID = @cDropID     
                     AND Status <> '4'    
                  GROUP BY SKU    
               ) A FULL OUTER JOIN     
               (    
                  SELECT SKU, ISNULL( SUM( QTY), 0) QTY    
                  FROM dbo.PackDetail WITH (NOLOCK)     
                  WHERE LabelNo = @cDropID     
                     AND PickSlipNo = @cPickSlipNo    
                  GROUP BY SKU    
               ) B ON (A.SKU = B.SKU)    
               WHERE A.SKU IS NULL    
                  OR B.SKU IS NULL    
               OR A.QTY <> B.QTY)    
            BEGIN    
               SET @nErrNo = 78712    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PK&PackQTYDiff    
               GOTO Fail    
            END    
         END    
      END    
   END    
    
   IF @nStep = 2 -- PPA stat    
   BEGIN    
      IF @nInputKey = 0 -- ESC    
      BEGIN    
         -- Get printer    
         SELECT     
            @cLabelPrinter = Printer,    
            @cStorerKey = StorerKey, 
            @cFacility = Facility, 
            @cPUOM = V_UOM  
         FROM rdt.rdtMobRec WITH (NOLOCK)    
         WHERE Mobile = @nMobile  
         
         ---- Order cancel not print dispatch label and packing list    
         --IF @cSOStatus = 'CANC'    
         --   GOTO Quit     

         DECLARE @nVariance INT
         SELECT @nVariance = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, 
            @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorerKey, @cFacility, @cPUOM,
            @nVariance = @nVariance OUTPUT
         IF @nVariance = 1
            GOTO Quit

         -- Get storer config    
         SET @cPrintDispatchLabel = rdt.rdtGetConfig( @nFunc, 'DispatchLabel', @cStorerKey)    
       
         -- Print dispatch label    
         IF @cPrintDispatchLabel = '1'    
         BEGIN    
            -- Check label printer blank    
            IF @cLabelPrinter = ''    
            BEGIN    
               SET @nErrNo = 78701    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
               GOTO Quit    
            END    
          
            -- Get packing list report info    
            SET @cDataWindow = ''    
            SET @cTargetDB = ''    
            SELECT     
               @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
               @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
            FROM RDT.RDTReport WITH (NOLOCK)     
            WHERE StorerKey = @cStorerKey    
               AND ReportType = 'DESPATCHTK'    
                   
            -- Check data window    
            IF ISNULL( @cDataWindow, '') = ''    
            BEGIN    
               SET @nErrNo = 78702    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
               SET @nErrNo = 0 -- Not stopping error    
               GOTO Quit    
            END    
          
            -- Check database    
            IF ISNULL( @cTargetDB, '') = ''    
            BEGIN    
               SET @nErrNo = 78703    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set    
               SET @nErrNo = 0 -- Not stopping error    
               GOTO Quit    
            END    
                   
            -- Get CartonNo    
            SELECT TOP 1 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE DropID = @cDropID    

            SELECT TOP 1     
               @cStorerKey = O.StorerKey,     
               @cOrderKey = O.OrderKey,     
               @cSOStatus = O.SOStatus    
            FROM dbo.Orders O WITH (NOLOCK)        
            WHERE EXISTS(SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)     
                         WHERE PD.PickSlipNo = @cPickSlipNo     
                         AND O.OrderKey = PD.OrderKey )    

            -- Order cancel not print dispatch label and packing list    
            IF @cSOStatus = 'CANC'    
               GOTO Quit     

            -- Insert print job    
            EXEC RDT.rdt_BuiltPrintJob    
               @nMobile,    
               @cStorerKey,    
               'DESPATCHTK',       -- ReportType    
               'PRINT_DESPATCHTK', -- PrintJobName    
               @cDataWindow,    
               @cLabelPrinter,    
               @cTargetDB,    
               @cLangCode,    
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT,     
               @cPickSlipNo,     
               @nCartonNo,  -- Start CartonNo    
               @nCartonNo,  -- End CartonNo    
               '',          -- Start LabelNo    
               ''           -- End LabelNo    
                
            -- Update DropID    
            IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)    
            BEGIN    
               -- Insert DropID    
               INSERT INTO dbo.DropID (DropID, LabelPrinted, Status) VALUES (@cDropID, '1', '9')    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 78704    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail    
                  GOTO Fail    
               END    
            END    
            ELSE    
            BEGIN    
               -- Update DropID    
               UPDATE dbo.DropID SET    
                  LabelPrinted = '1'    
               WHERE DropID = @cDropID    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 78705    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail    
                  GOTO Fail    
               END    
            END    
         END    
       
         -- Send message to WCS    
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cDropID, @cOrderKey    
      END    
   END    
       
   IF @nStep = 4 -- Discrepancy    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         SELECT TOP 1 
            @cPickSlipNo = PickSlipNo, 
            @nCartonNo = CartonNo 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID    

         SELECT TOP 1     
            @cStorerKey = O.StorerKey,     
            @cOrderKey = O.OrderKey,     
            @cSOStatus = O.SOStatus    
         FROM dbo.Orders O WITH (NOLOCK)        
         WHERE EXISTS(SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)     
                        WHERE PD.PickSlipNo = @cPickSlipNo     
                        AND O.OrderKey = PD.OrderKey )    

         IF @cOption = '1' -- Discrepency found, send to QC    
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cDropID, @cOrderKey, 'QC'    
             
         IF @cOption = '2' -- Discrepency found, exit anyway    
            GOTO Quit    
      END    
  END    
       
   IF @nStep = 5 -- Print packing list    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         IF @cOption = '1' OR @cOption = '9' -- Yes,No    
         BEGIN    
            -- Get storer config    
            SET @cPrintDispatchLabel = rdt.rdtGetConfig( @nFunc, 'DispatchLabel', @cStorerKey)    
          
            -- Print dispatch label    
            IF @cPrintDispatchLabel = '1'    
            BEGIN    
               -- Get printer    
               SELECT     
                  @cLabelPrinter = Printer,    
                  @cStorerKey = StorerKey    
               FROM rdt.rdtMobRec WITH (NOLOCK)    
               WHERE Mobile = @nMobile    
                   
               -- Check label printer blank    
               IF @cLabelPrinter = ''    
               BEGIN    
                  SET @nErrNo = 78706    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
                  GOTO Quit    
               END    
             
               -- Get packing list report info    
               SET @cDataWindow = ''    
               SET @cTargetDB = ''    
               SELECT     
                  @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
               FROM RDT.RDTReport WITH (NOLOCK)     
               WHERE StorerKey = @cStorerKey    
                  AND ReportType = 'DESPATCHTK'    
                      
               -- Check data window    
               IF ISNULL( @cDataWindow, '') = ''    
               BEGIN    
                  SET @nErrNo = 78707    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
                  SET @nErrNo = 0 -- Not stopping error    
                  GOTO Quit    
               END    
             
               -- Check database    
               IF ISNULL( @cTargetDB, '') = ''    
               BEGIN    
                  SET @nErrNo = 78708    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set    
                  SET @nErrNo = 0 -- Not stopping error    
                  GOTO Quit    
               END    
                      
               -- Get CartonNo    
               SELECT TOP 1 
                  @cPickSlipNo = PickSlipNo,
                  @nCartonNo = CartonNo 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE DropID = @cDropID    

               SELECT TOP 1     
                  @cStorerKey = O.StorerKey,     
                  @cOrderKey = O.OrderKey,     
                  @cSOStatus = O.SOStatus    
               FROM dbo.Orders O WITH (NOLOCK)        
               WHERE EXISTS(SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)     
                              WHERE PD.PickSlipNo = @cPickSlipNo     
                              AND O.OrderKey = PD.OrderKey )    

               -- Insert print job    
               EXEC RDT.rdt_BuiltPrintJob    
                  @nMobile,    
                  @cStorerKey,    
                  'DESPATCHTK',       -- ReportType    
                  'PRINT_DESPATCHTK', -- PrintJobName    
                  @cDataWindow,    
                  @cLabelPrinter,    
                  @cTargetDB,    
                  @cLangCode,    
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT,     
                  @cPickSlipNo,     
                  @nCartonNo,  -- Start CartonNo    
                  @nCartonNo,  -- End CartonNo    
                  '',     -- Start LabelNo    
                  ''           -- End LabelNo    
                   
               -- Update DropID    
               IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)    
               BEGIN    
                  -- Insert DropID    
                  INSERT INTO dbo.DropID (DropID, LabelPrinted, Status) VALUES (@cDropID, '1', '9')    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 78709    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail    
                     GOTO Fail    
                  END    
               END    
               ELSE    
               BEGIN    
                  -- Update DropID    
                  UPDATE dbo.DropID SET    
                     LabelPrinted = '1'    
                  WHERE DropID = @cDropID    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 78710    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail    
                     GOTO Fail    
                  END    
               END    
            END    
                
            -- Send message to WCS    
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cDropID, @cOrderKey    
         END    
      END    
   END    
       
Fail:    
   RETURN    
Quit:    
   SET @nErrNo = 0 -- Not stopping error

GO