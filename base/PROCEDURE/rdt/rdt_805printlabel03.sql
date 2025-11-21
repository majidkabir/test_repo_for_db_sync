SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_805PrintLabel03                                 */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 05-06-2018 1.0  ChewKP    WMS-4538  Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_805PrintLabel03] (  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR( 3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR( 5)  
   ,@cStorerKey   NVARCHAR( 15)  
   ,@cType        NVARCHAR( 15)   
   ,@cStation1    NVARCHAR( 10)  
   ,@cStation2    NVARCHAR( 10)  
   ,@cStation3    NVARCHAR( 10)  
   ,@cStation4    NVARCHAR( 10)  
   ,@cStation5    NVARCHAR( 10)  
   ,@cMethod      NVARCHAR( 1)  
   ,@cCartonID    NVARCHAR( 20)  
   ,@nErrNo       INT           OUTPUT  
   ,@cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

      
   
          
   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
  
   DECLARE 
           @cPickSlipNo       NVARCHAR(10)
          ,@cUCCNo            NVARCHAR(20) 
          ,@nCartonStart      INT
          ,@nCartonEnd        INT
          ,@cVASType          NVARCHAR(10)  
          ,@cField01          NVARCHAR(10)   
          ,@cTemplate         NVARCHAR(50)  
          ,@nTranCount        INT
          ,@cPickDetailKey    NVARCHAR(10) 
          ,@cOrderKey         NVARCHAR(10) 
          ,@cLabelNo          NVARCHAR(20) 
          ,@cSKU              NVARCHAR(20)
          ,@nCartonNo         INT
          ,@cLabelLine        NVARCHAR(5) 
          ,@cGenLabelNoSP     NVARCHAR(30)  
          ,@nQty              INT
          ,@cExecStatements   NVARCHAR(4000)         
          ,@cExecArguments    NVARCHAR(4000)  
          ,@cCodeTwo          NVARCHAR(30)  
          ,@cTemplateCode     NVARCHAR(60)  
          ,@nFocusParam       INT
          ,@bsuccess          INT
          ,@nPackQTY          INT
          ,@nPickQty          INT
          ,@cWCS              NVARCHAR(1) 
          ,@cLoadKey          NVARCHAR(10) 
          ,@cDeviceType       NVARCHAR( 10)
          ,@cDeviceID         NVARCHAR( 10)
          ,@c_authority       NVARCHAR(1) 
          ,@cLoadPlanLaneDetailLoc NVARCHAR(10) 
          ,@cWCSStation       NVARCHAR(10)
          ,@cWCSMessage       NVARCHAR(MAX)
          ,@cWCSKey           NVARCHAR(10) 
          ,@cWCSSequence      NVARCHAR(2) 
          ,@nMaxCarton        INT
          ,@cPrintPackingList NVARCHAR(1)

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_805PrintLabel03 -- For rollback or commit only our own transaction
     
   -- Get CartonNo  
   SET @cPickSlipNo = ''  
   SET @nCartonNo = 0  
   SELECT TOP 1 
      @cPickSlipNo = PickSlipNo,   
      @nCartonNo = CartonNo  
   FROM dbo.PackDetail WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey   
      --AND RefNo = @cCartonID  
      AND LabelNo = @cCartonID 

   

   DECLARE @tOutBoundList AS VariableTable          
   DECLARE @tOutBoundList2 AS VariableTable          
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   
   SET @cWCS = '0'
   SET @cDeviceType = 'WCS'
   SET @cDeviceID = 'WCS'
     

   -- GET WCS Config 
   EXECUTE nspGetRight 
            @cFacility,  -- facility
            @cStorerKey,  -- Storerkey
            null,         -- Sku
            'WCS',        -- Configkey
            @bSuccess     output,
            @c_authority  output, 
            @nErrNo       output,
            @cErrMsg      output

    IF @c_authority = '1' AND @bSuccess = 1
    BEGIN
       SET @cWCS = '1' 
    END  

   -- Print Carton Label
   
   

   -- Found PickSlipNo  
   IF @cPickSlipNo <> ''  
   BEGIN  
      --SELECT @cOrderKey = OrderKey 
      --FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      --WHERE StorerKey = @cStorerKey
      --AND CartonID = @cCartonID

      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
      
      
      
      -- Print Carton Label
      SELECT @nCartonStart = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND StorerKey = @cStorerKey
      AND DropID = @cCartonID    
         
      SELECT @nCartonEnd = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo    
      AND StorerKey = @cStorerKey
      AND DropID = @cCartonID 

       -- Print Packing List Process --  
      SET @nPackQTY = 0
      SET @nPickQTY = 0
      SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
--      SELECT @nMaxCarton = MAX(CartonNo)
--      FROM dbo.PackDetail WITH (NOLOCK)
--      WHERE PickSlipNo = @cPickSlipNo    
--      AND StorerKey = @cStorerKey
      SET @cPrintPackingList = '0'
      
      IF @nPackQTY = @nPickQTY
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                            WHERE StorerKey = @cStorerKey
                            AND PickSlipNo = @cPickSlipNo 
                            AND RefNo2 = '1'  )
         BEGIN
              
               SET @cPrintPackingList = '1'
               
               UPDATE dbo.PackDetail WITH (ROWLOCK) 
               SET RefNo2 = '1'
               WHERE StorerKey = @cStorerKey
                 AND PickSlipNo = @cPickSlipNo 
                 AND DropID = @cCartonID
                 
         END
      END
      
      IF EXISTS (  SELECT 1   
                FROM dbo.DocInfo WITH (NOLOCK)  
                WHERE StorerKey = @cStorerKey  
                AND TableName = 'ORDERDETAIL'  
                AND Key1 = @cOrderKey  
                AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'  )   
      BEGIN  
         
         DECLARE CursorLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
           
         SELECT Rtrim(Substring(Docinfo.Data,31,30))   
               ,Rtrim(Substring(Docinfo.Data,61,30))  
         FROM dbo.DocInfo WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND TableName = 'ORDERDETAIL'  
         AND Key1 = @cOrderKey   
         AND Key2 = '00001'  
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'   
           
         OPEN CursorLabel              
           
         FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01  
           
           
         WHILE @@FETCH_STATUS <> -1       
         BEGIN  
              
            SET @cTemplate = ''  
              
            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT Notes, Code2  
            FROM dbo.CodeLkup WITH (NOLOCK)  
            WHERE ListName = 'UALabel'  
            AND Code  = @cField01  
            AND Short = @cVASType  
            AND StorerKey = @cStorerKey  
              
            OPEN CursorCodeLkup  
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo  
            WHILE @@FETCH_STATUS<>-1  
            BEGIN  
                 
      --         SELECT @cTemplate = ISNULL(RTRIM(Notes),'')   
      --         FROM dbo.CodeLkup WITH (NOLOCK)  
      --         WHERE ListName = 'UALabel'  
      --         AND Code  = @cField01  
      --         AND Short = @cVASType  
      --         AND StorerKey = @cStorerKey  
                 
               SET @cTemplateCode = ''  
               SET @cTemplateCode = ISNULL(RTRIM(@cField01),'')  + ISNULL(RTRIM(@cCodeTwo),'')   
                 
               IF @cTemplate = ''   
               BEGIN  
                  SET @nErrNo = 123161    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound      
                  GOTO Quit      
               END  

               
               
               DELETE FROM @tOutBoundList
               
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonStart)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonEnd)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)
               

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                  'SHIPLBLUA2', -- Report type
                  @tOutBoundList, -- Report params
                  'rdt_805PrintLabel03', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
                   
                

               IF @nErrNo <> 0
                  GOTO Quit
               
               

               FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo  
            END  
            CLOSE CursorCodeLkup  
            DEALLOCATE CursorCodeLkup  
                
            FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01     
           
         END  
         CLOSE CursorLabel              
         DEALLOCATE CursorLabel       
      END  
         
      --INSERT INTO TRACEINFO (TRaceName , TimeIN, Col1, Col2, Col3, Col4, Col5 )     
      --VALUES ( 'UALABEL', Getdate() ,@cVASType ,@cLabelFlag, @nCartonNo ,@cLabelNo ,@cPickSlipNo  )     
           
      IF EXISTS (  SELECT 1   
                   FROM dbo.DocInfo WITH (NOLOCK)  
                   WHERE StorerKey = @cStorerKey  
                   AND TableName = 'ORDERDETAIL'  
                   AND Key1 = @cOrderKey  
                   AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'  )   
      BEGIN  
           
          
           
         SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))   
         FROM dbo.DocInfo WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND TableName = 'ORDERDETAIL'  
         AND Key1 = @cOrderKey   
         AND Key2 = '00001'  
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'   
           
           
                 
         SET @cTemplate = ''  
           
         DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Notes, Code2  
         FROM dbo.CodeLkup WITH (NOLOCK)  
         WHERE ListName = 'UACCLabel'  
         AND Code  = @cVASType  
         AND StorerKey = @cStorerKey  
           
         OPEN CursorCodeLkup  
         FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo  
         WHILE @@FETCH_STATUS<>-1  
         BEGIN  
                       
            SET @cTemplateCode = ''  
            SET @cTemplateCode = ISNULL(RTRIM(@cVASType),'')  + ISNULL(RTRIM(@cCodeTwo),'')   
              
            IF @cTemplate = ''   
            BEGIN  
               SET @nErrNo = 123162  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound      
               GOTO Quit      
            END  
               
               DELETE FROM @tOutBoundList
               
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonStart)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonEnd)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)
               
               
               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                  'SHIPLBLUA2', -- Report type
                  @tOutBoundList, -- Report params
                  'rdt_805PrintLabel03', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
                  
               IF @nErrNo <> 0
                  GOTO Quit
              
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo  
              
         END  
         CLOSE CursorCodeLkup  
         DEALLOCATE CursorCodeLkup  
           
      END  
         
         
      
      
     
                  
--      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
--                      WHERE StorerKey = @cStorerKey  
--                      AND PickSlipNo = @cPickSlipNo  
--                      AND ISNULL(RTRIM(RefNo),'')  <> '1' )   
      IF @nPackQty = @nPickQty 
      BEGIN  
         SET @cTemplate = ''  
         
         IF @cPrintPackingList = '1'
         BEGIN
            
            
            
--            -- Pack confirm  
--            UPDATE PackHeader SET   
--               Status = '9'   
--            WHERE PickSlipNo = @cPickSlipNo  
--               AND Status <> '9'  
--            
            --IF @@ERROR <> 0  
            --BEGIN  
            --   SET @nErrNo = 123164  
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackHdrFail 
            --   GOTO RollBackTran  
            --END  
            
            --IF @nMaxCarton = @nCartonEnd
            --BEGIN
              
            IF EXISTS ( SELECT 1  
                        FROM dbo.DocInfo WITH (NOLOCK)  
                        WHERE StorerKey = @cStorerKey  
                        AND TableName = 'ORDERDETAIL'  
                        AND Key1 = @cOrderKey   
                        AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'  )   
            BEGIN  
               
               SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))   
               FROM dbo.DocInfo WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
               AND TableName = 'ORDERDETAIL'  
               AND Key1 = @cOrderKey   
               AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'   
                 
               SELECT @cTemplate = ISNULL(RTRIM(Notes),'')   
               FROM dbo.CodeLkup WITH (NOLOCK)  
               WHERE ListName = 'UAPACKLIST'  
               AND Code  = @cVASType  
               AND UDF01 <> '1'  
               AND StorerKey = @cStorerKey  
                 
               IF ISNULL(RTRIM(@cTemplate),'')  <> ''   
               BEGIN  
                       
                  
                  DELETE @tOutBoundList
                  INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
                  
                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter, 
                     'PACKLIST', -- Report type
                     @tOutBoundList, -- Report params
                     'rdt_805PrintLabel03', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                     
                  IF @nErrNo <> 0
                     GOTO Quit
                    
               END  
            END  
            
         END
         --END
           
           
           
      END  
      
      

      --- Trigger WCS
      IF @cWCS = '1'
      BEGIN
--         SELECT TOP 1 @cLoadKey = LoadKey FROM dbo.LoadPlanDetail WITH (NOLOCK) 
--         WHERE OrderKey = @cOrderKey 
         SELECT TOP 1 @cLoadKey = LoadKey  
         FROM dbo.LoadPlanDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         SELECT @cLoadPlanLaneDetailLoc = LOC 
         FROM dbo.LoadPlanLaneDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey 

         SELECT @cWCSStation = Short                
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'WCSSTATION'
         AND StorerKey = @cStorerKey
         AND Code = @cLoadPlanLaneDetailLoc 
         
         SET @cWCSSequence = '01'
         
         EXECUTE dbo.nspg_GetKey
            'WCSKey',
            10 ,
            @cWCSKey           OUTPUT,
            @bSuccess          OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT
            
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 123584
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
            GOTO Quit
         END
         
         --SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)
         SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cCartonID) + '|' + @cWCSKey + '|' + @cWCSStation + '|' + CHAR(3)
         
         EXEC [RDT].[rdt_GenericSendMsg]
          @nMobile      = @nMobile      
         ,@nFunc        = @nFunc        
         ,@cLangCode    = @cLangCode    
         ,@nStep        = @nStep        
         ,@nInputKey    = @nInputKey    
         ,@cFacility    = @cFacility    
         ,@cStorerKey   = @cStorerKey   
         ,@cType        = @cDeviceType       
         ,@cDeviceID    = @cDeviceID
         ,@cMessage     = @cWCSMessage     
         ,@nErrNo       = @nErrNo       OUTPUT
         ,@cErrMsg      = @cErrMsg      OUTPUT  
         
         
         IF @nErrNo <> 0 
            GOTO Quit  
         
      END   
      
--      -- PackInfo not yet created  
--      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)  
--      BEGIN  
--         DECLARE @cCartonGroup NVARCHAR( 10)  
--         DECLARE @cCartonType NVARCHAR( 10)  
--         DECLARE @fCube FLOAT  
--         DECLARE @fWeight FLOAT  
--           
--         SET @cCartonGroup = ''  
--         SET @cCartonType = ''  
--         SET @fCube = 0  
--         SET @fWeight = 0  
--           
--         -- Get Carton info  
--         SELECT @cCartonGroup = CartonGroup FROM Storer WITH (NOLOCK) WHERE StorerKey = @cStorerKey  
--         SELECT TOP 1   
--            @cCartonType = CartonType,   
--            @fCube = Cube  
--         FROM Cartonization WITH (NOLOCK)  
--         WHERE CartonizationGroup = @cCartonGroup  
--         ORDER BY UseSequence  
--           
--         -- Calc Weight  
--         SELECT @fWeight = ISNULL( SUM( QTY * SKU.STDGrossWGT), 0)  
--         FROM PackDetail PD WITH (NOLOCK)  
--             JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
--         WHERE PickSlipNo = @cPickSlipNo  
--            AND CartonNo = @nCartonNo  
--           
--         -- PackInfo  
--         INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)  
--         VALUES (@cPickSlipNo, @nCartonNo, @fWeight, @fCube, @cCartonType)  
--         IF @@ERROR <> 0  
--         BEGIN    
--            SET @nErrNo = 100601    
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail    
--            GOTO Quit    
--         END    
--      END  
   END  
     
GOTO Quit


   
RollBackTran:
   ROLLBACK TRAN rdt_805PrintLabel03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_805PrintLabel03
END  


GO