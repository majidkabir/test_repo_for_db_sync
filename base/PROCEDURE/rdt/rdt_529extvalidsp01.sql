SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_529ExtValidSP01                                 */  
/* Purpose: Validate Weight Cube                                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-02-10 1.2  ChewKP     SOS#302191 Created                        */  
/* 2017-06-06 1.3  ChewKP     WMS-2116 Allow Conso Packed item(ChewKP01)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_529ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cFromTote   NVARCHAR(20),   -- (ChewKP01) 
   @cToTote     NVARCHAR(20),   -- (ChewKP01) 
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 529  
BEGIN  
   

    DECLARE  @nValidationPass INT
           , @cFromToteConsignee  NVARCHAR(18) 
           , @cToToteConsignee    NVARCHAR(18)
           , @cCode               NVARCHAR(30)
           , @cFromToteBuyerPO    NVARCHAR(20)
           , @cToToteBuyerPO      NVARCHAR(20)
           , @cShort              NVARCHAR(10)
           , @cFromToteSectionKey NVARCHAR(10) 
           , @cToToteSectionKey   NVARCHAR(10)

    
    SET @nValidationPass = 0
    SET @nErrNo = 0 
    SET @cErrMsg = ''
    SET @cFromToteConsignee  = ''
    SET @cToToteConsignee    = ''
    SET @cCode               = ''
    SET @cFromToteBuyerPO    = ''
    SET @cToToteBuyerPO      = ''
    SET @cShort              = ''
    SET @cFromToteSectionKey = ''
    SET @cToToteSectionKey   = ''
    

    
    
    SELECT TOP 1 @cFromToteConsignee = OD.UserDefine02
                ,@cFromToteBuyerPO   = O.BuyerPO
                ,@cFromToteSectionKey = O.SectionKey
    FROM dbo.PackDetail PackD WITH (NOLOCK) 
    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.CaseID = PackD.LabelNo
    INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
    INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber  
    WHERE PackD.DropID = @cFromTote
    AND PD.Status = '5'
    Order by OD.UserDefine02
    
    SELECT TOP 1 @cToToteConsignee = OD.UserDefine02
                ,@cToToteBuyerPO = O.BuyerPO
                ,@cToToteSectionKey = O.SectionKey
    FROM dbo.PackDetail PackD WITH (NOLOCK) 
    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.CaseID = PackD.LabelNo
    INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
    INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber  
    WHERE PackD.DropID = @cToTote
    AND PD.Status = '5'
    Order by OD.UserDefine02


    
    DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
    SELECT Code, Short 
    FROM dbo.Codelkup WITH (NOLOCK) 
    WHERE Listname = 'ToteConso'  
    
    OPEN CUR_CODELKUP 
    
    FETCH NEXT FROM CUR_CODELKUP INTO @cCode, @cShort
    WHILE @@FETCH_STATUS <> -1
    BEGIN
    
      IF @cCode = 'ValidateStoreDiff' AND @cShort = '1'
      BEGIN
         
         IF ISNULL(RTRIM(@cFromToteConsignee),'') <> ISNULL(RTRIM(@cToToteConsignee ),'' ) 
         BEGIN
             SET @nErrNo = 84901
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffConsignee'
             BREAK
         END
      END
      
      IF @cCode = 'ValidatePriorityDiff' AND @cShort = '1'
      BEGIN
         IF ISNULL(RTRIM(@cFromToteBuyerPO),'') <> ISNULL(RTRIM(@cToToteBuyerPO ),'' ) 
         BEGIN
             SET @nErrNo = 84902
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffBuyerPO'
             BREAK
         END
      END
      
      IF @cCode = 'ValidateGenderDiff' AND @cShort = '1'
      BEGIN
         IF ISNULL(RTRIM(@cFromToteSectionKey),'') <> ISNULL(RTRIM(@cToToteSectionKey ),'' ) 
         BEGIN
             SET @nErrNo = 84903
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffGender'
             BREAK
         END
      END
      
        
      FETCH NEXT FROM CUR_CODELKUP INTO @cCode, @cShort
      
    END
    CLOSE CUR_CODELKUP
    DEALLOCATE CUR_CODELKUP
    

   
END  
  
QUIT:  

 

GO