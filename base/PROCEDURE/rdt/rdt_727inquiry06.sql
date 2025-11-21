SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/          
/* Store procedure: rdt_727Inquiry06                                       */          
/*                                                                         */  
/* Purpose:                                                                */  
/* 1. Inquiry Caseid and trackingNo                                        */  
/*                                                                         */          
/* Modifications log:                                                      */          
/*                                                                         */          
/* Date       Rev  Author   Purposes                                       */          
/* 2019-09-17 1.0  YeeKung   WMS-10536 Created                             */        
/***************************************************************************/          
          
CREATE PROC [RDT].[rdt_727Inquiry06] (          
 @nMobile    INT,                 
 @nFunc      INT,                 
 @nStep      INT,                  
 @cLangCode  NVARCHAR( 3),        
 @cStorerKey NVARCHAR( 15),        
 @cOption    NVARCHAR( 1),        
 @cParam1Label    NVARCHAR(20),   
 @cParam2Label    NVARCHAR(20),     
 @cParam3Label    NVARCHAR(20),     
 @cParam4Label    NVARCHAR(20),    
 @cParam5Label    NVARCHAR(20),    
 @cParam1         NVARCHAR(20),     
 @cParam2         NVARCHAR(20),     
 @cParam3         NVARCHAR(20),     
 @cParam4         NVARCHAR(20),     
 @cParam5         NVARCHAR(20),            
 @cOutField01  NVARCHAR(20) OUTPUT,      
 @cOutField02  NVARCHAR(20) OUTPUT,      
 @cOutField03  NVARCHAR(20) OUTPUT,      
 @cOutField04  NVARCHAR(20) OUTPUT,      
 @cOutField05  NVARCHAR(20) OUTPUT,      
 @cOutField06  NVARCHAR(20) OUTPUT,      
 @cOutField07  NVARCHAR(20) OUTPUT,      
 @cOutField08  NVARCHAR(20) OUTPUT,      
 @cOutField09  NVARCHAR(20) OUTPUT,      
 @cOutField10  NVARCHAR(20) OUTPUT,  
 @cOutField11  NVARCHAR(20) OUTPUT,  
 @cOutField12  NVARCHAR(20) OUTPUT,  
 @cFieldAttr02 NVARCHAR( 1) OUTPUT,    
 @cFieldAttr04 NVARCHAR( 1) OUTPUT,    
 @cFieldAttr06 NVARCHAR( 1) OUTPUT,    
 @cFieldAttr08 NVARCHAR( 1) OUTPUT,    
 @cFieldAttr10 NVARCHAR( 1) OUTPUT,          
 @nNextPage    INT          OUTPUT,      
 @nErrNo     INT OUTPUT,          
 @cErrMsg    NVARCHAR( 20) OUTPUT      
)          
AS          
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF   
     
  DECLARE @cCaseID         NVARCHAR(20)      
         ,@cTrackingNo     NVARCHAR(20)  
         ,@cPickSlipNo     NVARCHAR(20)           
             
SET @nErrNo = 0           
      
IF @cOption = '1'       
BEGIN  
   IF @nStep = 2       
   BEGIN    
      SET @cCaseID = @cParam1   
      SET @cTrackingNo = @cParam3  
        
      IF ISNULL(@cCaseID,'')=''  
      BEGIN  
         SET @nErrNo = 143951       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID     
         GOTO QUIT   
      END    
  
      IF ISNULL(@cTrackingNo,'')=''  
      BEGIN  
         SET @nErrNo = -1      
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- TrackingNO   
         GOTO QUIT   
      END   
  
      SELECT TOP 1 @cPickSlipNo=pickslipno  
      FROM PACKDETAIL (NOLOCK)  
      WHERE DROPID=@cCaseID  
      AND Storerkey=@cStorerkey  
  
      IF NOT EXISTS (SELECT 1 FROM Packheader PH (NOLOCK) JOIN ORDERS O (NOLOCK)  
                     ON PH.OrderKey=O.OrderKey   
                     WHERE PH.pickslipno=@cPickSlipNo   
                        AND O.TrackingNo=@cTrackingNo  
                        AND O.Storerkey=@cStorerkey)  
      BEGIN  
         SET @nErrNo = 143953       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CID&TKNoNotMatch  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- TrackingNO  
         SET @cOutField02 = ''      
         SET @cOutField06 = ''     
         GOTO QUIT     
      END  
  
      SET @cOutField01 = 'Case ID:'        
      SET @cOutField02 = @cCaseID         
      SET @cOutField03 = 'Tracking No:'       
      SET @cOutField04 = @cTrackingNo     
      SET @cOutField08 = 'CaseID&TrackNo Match'    
       
      SET @nNextPage = 0              
   END      
     
END      
QUIT:   

GO