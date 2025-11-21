SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdt_727ExtFncKeySP01                                   */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author   Purposes                                       */      
/* 2018-12-27 1.0  ChewKP   WMS-5803 Created                               */    
/* 2019-08-21 1.1  James    WMS-9394 Add sent wcs msg after print (james01)*/    
/***************************************************************************/      
      
CREATE PROC [RDT].[rdt_727ExtFncKeySP01] (      
 @nMobile    INT,             
 @nFunc      INT,             
 @nStep      INT,              
 @cLangCode  NVARCHAR( 3),    
 @cStorerKey NVARCHAR( 15),    
 @cOption    NVARCHAR( 1),    
 @cParam1    NVARCHAR(20),     
 @cParam2    NVARCHAR(20),     
 @cParam3    NVARCHAR(20),     
 @cParam4    NVARCHAR(20),     
 @cParam5    NVARCHAR(20),     
 @c_oFieled01  NVARCHAR(20) OUTPUT,  
 @c_oFieled02  NVARCHAR(20) OUTPUT,  
 @c_oFieled03  NVARCHAR(20) OUTPUT,  
 @c_oFieled04  NVARCHAR(20) OUTPUT,  
 @c_oFieled05  NVARCHAR(20) OUTPUT,  
 @c_oFieled06  NVARCHAR(20) OUTPUT,  
 @c_oFieled07  NVARCHAR(20) OUTPUT,  
 @c_oFieled08  NVARCHAR(20) OUTPUT,  
 @c_oFieled09  NVARCHAR(20) OUTPUT,  
 @c_oFieled10  NVARCHAR(20) OUTPUT,  
 @c_oFieled11  NVARCHAR(20) OUTPUT,  
 @c_oFieled12  NVARCHAR(20) OUTPUT,  
 @nNextPage    INT          OUTPUT,  
 @nErrNo     INT OUTPUT,      
 @cErrMsg    NVARCHAR( 20) OUTPUT  
)      
AS      
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF       
      
   DECLARE 
          @cSKU        NVARCHAR(20)  
         ,@cDropID     NVARCHAR(20) 
         ,@nRemainQty  INT
         ,@nTTLQty     INT
      
   DECLARE @nSKUCnt     INT  
          ,@b_Success   INT  
          ,@cLabelNo    NVARCHAR(20) 
          ,@cPickSlipNo NVARCHAR(10)
          ,@cPlatform   NVARCHAR(4000) 
          ,@cUserDefine03 NVARCHAR(20) 
          ,@cOrderKey   NVARCHAR(10)
          ,@cShipFlag   NVARCHAR(1)
          ,@nCartonCount INT
          ,@nPrintFlag  INT
             
   
   DECLARE @cDataWindow   NVARCHAR( 50)  
         , @cManifestDataWindow NVARCHAR( 50)  
   
   DECLARE @tOutBoundList AS VariableTable  
          
   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
          ,@cFacility     NVARCHAR( 5) 

   DECLARE @cWCSMessage   NVARCHAR( MAX)
   DECLARE @cSerialNo     NVARCHAR( 10) 
   DECLARE @cWCSKey       NVARCHAR( 10) 
   DECLARE @bSuccess      INT
   DECLARE @nTranCount    INT
   DECLARE @c_authority   NVARCHAR(1)
   DECLARE @cWCS          NVARCHAR(1)

   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
         ,@cFacility       = Facility 
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile   
             
      
            
SET @nErrNo = 0   
  

IF @cOption = '3' 
BEGIN
   IF @nStep = 3   
   BEGIN  
      SET @cLabelNo     = @cParam1   
      --SET @cUPC        = @cParam3  
      
      IF ISNULL(@cPaperPrinter,'')  = ''
      BEGIN
         SET @nErrNo = 133352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrinterReq  
         GOTO QUIT   
      END

      
      SELECT TOP 1 @cOrderKey = OrderKey 
                  ,@cPickSlipNo = PickSlipNo 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cLabelNo 
      ORDER BY Editdate Desc
      --AND Status < '5'
      
      SELECT @cShipFlag = Ecom_Single_Flag 
            ,@cUserDefine03 = UserDefine03
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE Orderkey = @cOrderKey
      
      IF @cShipFlag <> 'M'
      BEGIN
         SET @nErrNo = 133351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotMultiOrder  
         GOTO QUIT   
      END
      
      IF EXISTS ( SELECT 1 FROM rdt.rdtStdEventLog WITH (NOLOCK) 
                  WHERE UserID = @cUsername
                  AND MobileNo = @nMobile
                  AND FunctionID = @nFunc
                  AND Facility = @cFacility
                  AND StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND EventType = '0' 
                  AND EventDateTime > (GetDate() - 1 ))
         SET @nPrintFlag = 1
      
      
      IF ISNULL(@nPrintFlag,0)  = 1
         GOTO QUIT
      
      
--      SELECT @cDataWindow = DataWindow,    
--            @cTargetDB = TargetDB    
--      FROM rdt.rdtReport WITH (NOLOCK)    
--      WHERE StorerKey = @cStorerKey    
--      AND   ReportType = 'EMPACKLIST'    
      
--      DECLARE GI_ECOMMLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
--      SELECT PD.OrderKey
--      FROM dbo.PickDetail PD WITH (NOLOCK)    
--      --INNER JOIN dbo.PackDetail PackD WITH (NOLOCK) ON PackD.PickSlipNo = PD.PickSlipNo AND PackD.StorerKey = PD.StorerKey 
--      WHERE PD.StorerKey = @cStorerKey 
--      AND   PD.PickSlipNo = @cPickSlipNo    
--      GROUP BY PD.OrderKey 
--      
--      
--    
--      OPEN GI_ECOMMLOG    
--      FETCH NEXT FROM GI_ECOMMLOG INTO  @cOrderKey 
--      WHILE (@@FETCH_STATUS <> -1)    
--      BEGIN    
               
        IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> '' --JYHBIN  
        BEGIN
--            EXEC RDT.rdt_BuiltPrintJob    
--             @nMobile,    
--             @cStorerKey,    
--             'EMPACKLIST',              -- ReportType    
--             'rdt_727ExtFncKeySP01',    -- PrintJobName    
--             @cDataWindow,    
--             @cPaperPrinter,    
--             @cTargetDB,    
--             @cLangCode,    
--             @nErrNo  OUTPUT,    
--             @cErrMsg OUTPUT,    
--             @cPickSlipNo,    
--             ''--@cLabelNo   
             
             DELETE FROM @tOutBoundList
       
             INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
   
              
             -- Print label
             EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter, 
                'EMPACKLIST', -- Report type
                @tOutBoundList, -- Report params
                'rdt_727ExtFncKeySP01', 
                @nErrNo  OUTPUT,
                @cErrMsg OUTPUT
            
            IF @nErrNo <> 0 
               GOTO QUIT 
               
            EXEC RDT.rdt_STD_EventLog
              @cActionType = '1', -- Sign in function
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerkey,
              @cPickSlipNo = @cPickslipNo,
              @cDropID     = @cLabelNo
              
            
        END
      
         SET @cWCS = '0'

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
    
      -- (james01)
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_727ExtFncKeySP01

      IF @cWCS = '1'
      BEGIN
         SET @cWCSKey = ''
         SET @bSuccess = 1   
         SET @nErrNo = 0
         EXECUTE   nspg_getkey    
           @KeyName     = 'WCSKey'    
         , @fieldlength = 10    
         , @keystring   = @cWCSKey     OUTPUT    
         , @b_Success   = @bSuccess    OUTPUT    
         , @n_err       = @nErrNo      OUTPUT    
         , @c_errmsg    = @cErrMsg     OUTPUT 

         IF @bSuccess <> 1
            GOTO RollBackTran

         SET @cWCSMessage = CHAR(2) + @cWCSKey + '|01||' + @cPickSlipNo + '|' + 'RELBATCH' + '|' + CHAR(3)

         SET @nErrNo = 0
         EXEC [RDT].[rdt_GenericSendMsg]
          @nMobile      = 0      
         ,@nFunc        = 0        
         ,@cLangCode    = 'ENG'    
         ,@nStep        = 0        
         ,@nInputKey    = 0    
         ,@cFacility    = ''    
         ,@cStorerKey   = @cStorerKey   
         ,@cType        = 'WCS'       
         ,@cDeviceID    = 'WCS'
         ,@cMessage     = @cWCSMessage     
         ,@nErrNo       = @nErrNo         OUTPUT
         ,@cErrMsg      = @cErrMsg        OUTPUT  

         IF @nErrNo <> 0
             GOTO RollBackTran  
      END
      
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT D.Dropid
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      LEFT JOIN dbo.DropidDetail DD WITH (NOLOCK) ON DD.ChildID=PD.DropID
      LEFT JOIN dbo.Dropid D WITH (NOLOCK) ON D.Dropid = DD.Dropid
      WHERE PD.StorerKey = @cStorerKey 
      AND PD.PickSlipNo = @cPickSlipNo  
      AND ISNULL(PD.DropID,'')  <> '' 
      AND D.Status='0' 
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cDropID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.Dropid WITH (ROWLOCK) SET 
            [Status] = '9'
         WHERE Dropid = @cDropID
            
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 133354  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd DropID Err  
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD            
            GOTO RollBackTran  
         END
            
         FETCH NEXT FROM CUR_UPD INTO @cDropID
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   
      GOTO Quit_Tran

      RollBackTran:
         ROLLBACK TRAN rdt_727ExtFncKeySP01
      Quit_Tran:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Quit

--         FETCH NEXT FROM GI_ECOMMLOG INTO  @cOrderKey
--      END
      
      SET @nErrNo = 133353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrintJobSent  
      SET @nNextPage = 0  
        
   END  
END  
QUIT:  
          

        

GO