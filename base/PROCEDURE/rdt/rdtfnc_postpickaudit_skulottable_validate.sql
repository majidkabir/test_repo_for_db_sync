SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdtfnc_PostPickAudit_SKULottable_Validate           */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: Comfirm Pick                                                */      
/*                                                                      */      
/* Called from: rdtfnc_Pick_SKULottable                                 */      
/*                                                                      */      
/* Exceed version: 5.4                                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2010-10-20 1.0  ChewKP   Created                                     */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_PostPickAudit_SKULottable_Validate] (    
     @nMobile        INT    
    ,@nFunc          INT    
    ,@cStorerKey     NVARCHAR(15)    
    ,@cUserName      NVARCHAR(18)    
    ,@cFacility      NVARCHAR(5)  
    ,@cRefNo         NVARCHAR(10)
    ,@cPickslipNo    NVARCHAR(10)
    ,@cLoadkey       NVARCHAR(10)  
    ,@cOrderkey      NVARCHAR(10)  
    ,@cDropID        NVARCHAR(18)
    ,@cLottable      NVARCHAR(1)
    ,@cLLottableValue NVARCHAR(18)
    ,@cSKU           NVARCHAR(20)    
    ,@cPPAType       NVARCHAR(1) -- 1 = Loadkey , 2 = PSNO , 3 = OrderKey , 4 = DropID, 5 = RefNo
    ,@cLangCode      NVARCHAR(3)
    ,@nErrNo         INT OUTPUT    
    ,@cErrMsg        NVARCHAR(20) OUTPUT -- screen limitation, 20 char max    
 )        
AS        
BEGIN    
    SET NOCOUNT ON        
    SET QUOTED_IDENTIFIER OFF        
    SET ANSI_NULLS OFF        
    SET CONCAT_NULL_YIELDS_NULL OFF        
        
    DECLARE @b_success             INT    
           ,@n_err                 INT    
           ,@c_errmsg              NVARCHAR(250)    
           ,@nTranCount            INT    
           ,@cLLottable            NVARCHAR(18)
           ,@nLottableCount        INT
           ,@cExecStatements  nvarchar(4000) 
           ,@cExecArguments   nvarchar(4000) 
               

    IF @cLottable = '1'
    BEGIN
        SET @cLLottable = 'LOTTABLE01'
    END

    IF @cLottable = '2'
    BEGIN
        SET @cLLottable = 'LOTTABLE02'
    END

    IF @cLottable = '3'
    BEGIN
        SET @cLLottable = 'LOTTABLE03'
    END

    IF @cLottable = '4'
    BEGIN
        SET @cLLottable = 'LOTTABLE04'
    END

    
    
    IF @cPPAType = '1'
    BEGIN
        SET @cExecStatements = ''
        
        SET @cExecStatements =N' SELECT @nLottableCount =  COUNT(LA.' + @cLLottable + ') FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
                              'INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey ' +
                              'INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey ) ' +
                              'INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU ' +
                              'WHERE LPD.Loadkey = @cLoadkey ' +
                              'AND PD.SKU = @cSKU ' +
                              'AND O.Storerkey = @cStorerkey ' +
                              'AND LA.' + @cLLottable + '= @cLLottableValue ' 
        
	  
									
        SET @cExecArguments = N'@cLLottable  NVARCHAR(18),  ' +
                                '@cLoadkey    NVARCHAR(10),   ' +
                                '@cSKU        NVARCHAR(20),   ' +
                                '@cLLottableValue NVARCHAR(10),  ' +
                                '@cStorerkey     NVARCHAR(10),'    +
                                '@nLottableCount int OUTPUT '
                                
         
                       
         EXEC sp_executesql @cExecStatements, @cExecArguments, 
                                              @cLLottableValue, 
                                              @cLoadkey,
                                              @cSKU,
                                              @cLLottableValue,
                                              @cStorerkey,
                                              @nLottableCount OUTPUT
         
         IF @nLottableCount = ''
         BEGIN
              IF @cLottable = '1'
              BEGIN
                  SET @nErrNo = 71641
              END
              ELSE IF @cLottable = '2'
              BEGIN
                  SET @nErrNo = 71642
              END
              ELSE IF @cLottable = '3'
              BEGIN
                  SET @nErrNo = 71643
              END
              ELSE IF @cLottable = '4'
              BEGIN
                  SET @nErrNo = 71644
              END
         END
         
         
        
    END
    
    IF @cPPAType = '2'
    BEGIN
        SET @cExecStatements = ''
        
        SET @cExecStatements =N' SELECT @nLottableCount =  COUNT(LA.' + @cLLottable + ') FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                               'INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU ' +
                               'WHERE PD.SKU = @cSKU ' +
                               'AND PD.Storerkey = @cStorerkey ' +
                               'AND PD.PickSlipNo = @cPickSlipNo ' +
                               'AND LA.' + @cLLottable + '= @cLLottableValue ' 
        
           

         SET @cExecArguments = N'@cLLottable  NVARCHAR(18),  ' +
                                '@cPickSlipNo NVARCHAR(10),   ' +
                                '@cSKU        NVARCHAR(20),   ' +
                                '@cLLottableValue NVARCHAR(10),  ' +
                                '@cStorerkey      NVARCHAR(10), ' +
                                '@nLottableCount  int OUTPUT '
                                
                                
         EXEC sp_executesql @cExecStatements, @cExecArguments, 
                                              @cLLottableValue, 
                                              @cPickSlipNo,
                                              @cSKU,
                                              @cLLottableValue, 
                                              @cStorerkey,
                                              @nLottableCount OUTPUT
         
         IF @nLottableCount = 0
         BEGIN
              IF @cLottable = '1'
              BEGIN
                  SET @nErrNo = 71645
              END
              ELSE IF @cLottable = '2'
              BEGIN
                  SET @nErrNo = 71646
              END
              ELSE IF @cLottable = '3'
              BEGIN
                  SET @nErrNo = 71647
              END
              ELSE IF @cLottable = '4'
              BEGIN
                  SET @nErrNo = 71648
              END
         END
    END
    
    
     IF @cPPAType = '3'
     BEGIN
        SET @cExecStatements = ''
        
        SET @cExecStatements =N' SELECT @nLottableCount =  COUNT(LA.' + @cLLottable + ') FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                               'INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU ' +
                               'WHERE PD.SKU = @cSKU ' +
                               'AND PD.Storerkey = @cStorerkey ' +
                               'AND PD.Orderkey = @cOrderkey ' +
                               'AND LA.' + @cLLottable + '= @cLLottableValue ' 
        
         
         SET @cExecArguments = N'@cLLottable  NVARCHAR(18),  ' +
                                '@cOrderkey   NVARCHAR(10),   ' +
                                '@cSKU        NVARCHAR(20),   ' +
                                '@cLLottableValue NVARCHAR(10),  ' +
                                '@cStorerkey     NVARCHAR(10), ' +
                                '@nLottableCount int OUTPUT '
                                
                                
         EXEC sp_executesql @cExecStatements, @cExecArguments, 
                                              @cLLottableValue, 
                                              @cOrderkey,
                                              @cSKU,
                                              @cLLottableValue, 
                                              @cStorerkey,
                                              @nLottableCount OUTPUT
         
         IF @nLottableCount = 0
         BEGIN
              IF @cLottable = '1'
              BEGIN
                  SET @nErrNo = 71649
              END
              ELSE IF @cLottable = '2'
              BEGIN
                  SET @nErrNo = 71650
              END
              ELSE IF @cLottable = '3'
              BEGIN
                  SET @nErrNo = 71651
              END
              ELSE IF @cLottable = '4'
              BEGIN
                  SET @nErrNo = 71652
              END
         END
      
     END
     
     IF @cPPAType = '4'
     BEGIN
        SET @cExecStatements = ''
        
        SET @cExecStatements =N' SELECT @nLottableCount =  COUNT(LA.' + @cLLottable + ') FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                               'INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU ' +
                               'WHERE PD.SKU = @cSKU ' +
                               'AND PD.Storerkey = @cStorerkey ' +
                               'AND PD.DropID = @cDropID ' +
                               'AND LA.' + @cLLottable + '= @cLLottableValue ' 
         
         
         SET @cExecArguments = N'@cLLottable    NVARCHAR(18),  ' +
                                '@cDropID       NVARCHAR(18),   ' +
                                '@cSKU          NVARCHAR(20),   ' +
                                '@cLLottableValue  NVARCHAR(10),  ' +
                                '@cStorerkey       NVARCHAR(10), ' +
                                '@nLottableCount int OUTPUT '
                                
                                
         EXEC sp_executesql @cExecStatements, @cExecArguments, 
                                              @cLLottableValue, 
                                              @cDropID,
                                              @cSKU,
                                              @cLLottableValue, 
                                              @cStorerkey,
                                              @nLottableCount OUTPUT
         
         IF @nLottableCount = ''
         BEGIN
              IF @cLottable = '1'
              BEGIN
                  SET @nErrNo = 71653
              END
              ELSE IF @cLottable = '2'
              BEGIN
                  SET @nErrNo = 71654
              END
              ELSE IF @cLottable = '3'
              BEGIN
                  SET @nErrNo = 71655
              END
              ELSE IF @cLottable = '4'
              BEGIN
                  SET @nErrNo = 71656
              END
         END
     END
    
     IF @cPPAType = '5'
     BEGIN
         SET @cExecStatements = ''
        
        SET @cExecStatements =N' SELECT @nLottableCount =  COUNT(LA.' + @cLLottable + ') FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                               'INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU ' +
                               'WHERE PD.SKU = @cSKU ' +
                               'AND PD.Storerkey = @cStorerkey ' +
                               'AND PD.DropID = @cDropID ' +
                               'AND LA.' + @cLLottable + '= @cLLottableValue ' 
         
         
         SET @cExecArguments = N'@cLLottable    NVARCHAR(18),  ' +
                                '@cDropID       NVARCHAR(18),   ' +
                                '@cSKU          NVARCHAR(20),   ' +
                                '@cLLottableValue  NVARCHAR(10),  ' +
                                '@cStorerkey       NVARCHAR(10), ' +
                                '@nLottableCount int OUTPUT '
                                
                                
         EXEC sp_executesql @cExecStatements, @cExecArguments, 
                                              @cLLottableValue, 
                                              @cDropID,
                                              @cSKU,
                                              @cLLottableValue,
                                              @cStorerkey,
                                              @nLottableCount OUTPUT
         
         IF @nLottableCount = ''
         BEGIN
              IF @cLottable = '1'
              BEGIN
                  SET @nErrNo = 71657
              END
              ELSE IF @cLottable = '2'
              BEGIN
                  SET @nErrNo = 71658
              END
              ELSE IF @cLottable = '3'
              BEGIN
                  SET @nErrNo = 71659
              END
              ELSE IF @cLottable = '4'
              BEGIN
                  SET @nErrNo = 71660
              END
         END
     END
    
    
    
  
        
    
END        


GO