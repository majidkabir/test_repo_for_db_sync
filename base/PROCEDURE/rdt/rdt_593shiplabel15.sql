SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdt_593ShipLabel15                                     */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author     Purposes                                     */      
/* 2021-05-03 1.0  Chermaine  WMS-16883 Created                            */     
/***************************************************************************/      
      
CREATE PROC [RDT].[rdt_593ShipLabel15] (      
   @nMobile    INT,      
   @nFunc      INT,      
   @nStep      INT,      
   @cLangCode  NVARCHAR( 3),      
   @cStorerKey NVARCHAR( 15),      
   @cOption    NVARCHAR( 1),      
   @cParam1    NVARCHAR(20),  -- LoadKey      
   @cParam2    NVARCHAR(20),        
   @cParam3    NVARCHAR(20),  -- LabelNo      
   @cParam4    NVARCHAR(20),      
   @cParam5    NVARCHAR(20),      
   @nErrNo     INT OUTPUT,      
   @cErrMsg    NVARCHAR( 20) OUTPUT
      
)      
AS     
BEGIN
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF           
 
      
   DECLARE @b_Success     INT      
   DECLARE @cLabelPrinter NVARCHAR( 10)      
   DECLARE @cPaperPrinter NVARCHAR( 10)      
   DECLARE @cLabelType    NVARCHAR( 20)      
   DECLARE @cUserName     NVARCHAR( 18)       
     
   DECLARE @cLabelNo      NVARCHAR(20)    
         , @cDropid       NVARCHAR(20) 
         , @cPrintCartonLabel NVARCHAR(1)   
         , @cOrderCCountry    NVARCHAR(30)  
         , @cOrderType        NVARCHAR(10)  
         , @cLoadKey      NVARCHAR(10)   
         , @cTargetDB     NVARCHAR(20)    
         , @cVASType      NVARCHAR(10)  
         , @cField01      NVARCHAR(10)   
         , @cTemplate     NVARCHAR(50)   
         , @cOrderKey     NVARCHAR(10)  
         , @cPickSlipNo   NVARCHAR(10)   
         , @nCartonNo     INT  
         , @cCodeTwo      NVARCHAR(30)  
         , @cTemplateCode NVARCHAR(60)  
         , @cPasscode     NVARCHAR(20)
         , @cDataWindow   NVARCHAR( 50)
         , @cTrackingno   NVARCHAR(20)         
         , @cConsigneeKey NVARCHAR(20) 
         , @cTMODE        NVARCHAR(20)
		   , @bSuccess      INT
		   , @nFocusParam   INT      
         ,  @nTranCount   INT      
 
   SELECT       
      @cUserName = UserName,     
      @cLabelPrinter = Printer,       
      @cPaperPrinter = Printer_Paper      
   FROM rdt.rdtMobRec WITH (NOLOCK)      
   WHERE Mobile = @nMobile  

   DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        

   SELECT  PickSlipNo, 
            cartonno
   FROM dbo.PackDetail  (NOLOCK) 
   WHERE PICKSLIPNO = @cParam1 
   AND   STORERKEY = @cStorerKey   
   AND   CARTONNO >= @cParam2
   AND   CARTONNO <= @cParam3
   GROUP BY PickSlipNo,cartonno
   ORDER BY PickSlipNo,cartonno
                    
   OPEN CursorCodeLkup        
   FETCH NEXT FROM CursorCodeLkup INTO @cPickSlipNo, @nCartonNo        
   WHILE @@FETCH_STATUS<>-1            
   BEGIN
      SET @cLabelType = 'SHIPPLBLLV'    

      EXEC dbo.isp_BT_GenBartenderCommand         
            @cLabelPrinter                               
         , @cLabelType                               
         , @cUserName                                
         , @cPickSlipNo  
         , @nCartonNo  
         , @nCartonNo                        
         , 'S' -- @cField01   
         , ''  
         , ''   
         , ''                                        
         , ''                  
         , ''     
         , ''      
         , @cStorerKey    
         , '1'    
         , '0'    
         , 'N'                                         
         , @nErrNo  OUTPUT                           
         , @cERRMSG OUTPUT    

             
      EXEC dbo.isp_BT_GenBartenderCommand         
            @cLabelPrinter                               
         , @cLabelType                               
         , @cUserName                                
         , @cPickSlipNo  
         , @nCartonNo  
         , @nCartonNo                        
         , 'C' -- @cField01   
         , ''  
         , ''                                   
         , ''                                        
         , ''                                        
         , ''     
         , ''      
         , @cStorerKey    
         , '1'    
         , '0'    
         , 'N'                                         
         , @nErrNo  OUTPUT                           
         , @cERRMSG OUTPUT   

      FETCH NEXT FROM CursorCodeLkup INTO @cPickSlipNo, @nCartonNo         
                       
   END        
   CLOSE CursorCodeLkup        
   DEALLOCATE CursorCodeLkup    

   GOTO QUIT         

--RollBackTran:            
--   ROLLBACK TRAN rdtABLabel -- Only rollback change made here            
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam      

Quit: 
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
   --   COMMIT TRAN rdtABLabel          
   --EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
END

GO