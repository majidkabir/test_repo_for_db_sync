SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_895ExtValidSP01                                 */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-06-15 1.0  ChewKP     SOS#342435 Created                        */  
/* 2017-08-11 1.1  ChewKP     WMS-2428 Replen By Pallet (ChewKP01)      */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_895ExtValidSP01] (  
      @nMobile        INT, 
      @nFunc          INT, 
      @cLangCode      NVARCHAR( 3),  
      @nStep          INT, 
      @cStorerKey     NVARCHAR( 15), 
      @cReplenishmentKey  NVARCHAR( 20), 
      @cLabelNo           NVARCHAR( 20), 
      @nErrNo             INT           OUTPUT, 
      @cErrMsg            NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 895  
BEGIN  
    
    DECLARE  @cLottable09Validation NVARCHAR(10)
            ,@cLot                  NVARCHAR(10)
            ,@cLottable09           NVARCHAR(60)
            ,@nUCCQty               INT
            ,@nQty                  INT
            ,@cRefNo                NVARCHAR(20) 
            ,@cWaveKey              NVARCHAR(10) 
            ,@cSKU                  NVARCHAR(20) 
            ,@cUCCSKU               NVARCHAR(20)
            ,@nCountSKU             INT
            ,@cReplenNo             NVARCHAR(10)
            ,@cDBName               NVARCHAR(10)
            ,@cLottable03           NVARCHAR(18) 
            ,@cPONumber             NVARCHAR(20) 
            ,@cFromLoc              NVARCHAR(10) 
            ,@cID                   NVARCHAR(18)
            ,@nInputCount           INT
            ,@nCount                INT
      
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    
    SELECT @cDBName = DB_NAME() 
    
    
    IF @nStep = 5 
    BEGIN
       
       IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                       AND UCCNo = @cLabelNo ) 
       BEGIN
         SET @nErrNo = 93805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'
         GOTO QUIT
       END
       
       SELECT @nUCCQty = SUM(Qty)
             --,@cSKU    = SKU 
             --,@cPONumber = UserDefined02
       FROM dbo.UCC WITH (NOLOCK)
       WHERE UCCNo = @cLabelNo 
       AND Status IN ('0', '1') 
       --GROUP BY SKU, UserDefined02
       
       SELECT @nCountSKU = Count(DISTINCT SKU ) 
       FROM dbo.UCC WITH (NOLOCK)
       WHERE UCCNo = @cLabelNo 
       
       SELECT @nQty      = SUM(Qty)
             ,@cLot      = Lot 
             ,@cRefNo    = RefNo 
             ,@cWaveKey  = WaveKey
             --,@cUCCSKU   = SKU 
             ,@cReplenNo = ReplenNo 
       FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
       WHERE ReplenishmentKey = @cReplenishmentKey
       GROUP BY Lot, RefNo, WaveKey, ReplenNo
       
       
       
       SELECT @cLottable03 = Lottable03 
       FROM dbo.LotAttribute LA WITH (NOLOCK)
       WHERE Lot = @cLot
       
       IF @nCountSKU = 1
       BEGIN
         
         SELECT @cSKU    = SKU 
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cLabelNo 
         AND Status IN ('0', '1') 
         
         SELECT 
             @cUCCSKU   = SKU 
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE ReplenishmentKey = @cReplenishmentKey
       
       
         IF ISNULL(RTRIM(@cSKU),'')  <> ISNULL(RTRIM(@cUCCSKU),'') 
         BEGIN
            SET @nErrNo = 93806
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidSKU'
            GOTO QUIT
         END
         
--         IF ISNULL(@nUCCQty,0) <> ISNULL(@nQty,0 )     
--         BEGIN    
--            SET @nErrNo = 93802   
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCQty'    
--            GOTO QUIT    
--         END  
         
         
       END
       ELSE
       BEGIN    

         SET @nQty = 0 

         SELECT @nQty      = SUM(Qty)  
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)  
         WHERE RefNo = @cRefNo  
         
         IF ISNULL(@nUCCQty,0) <> ISNULL(@nQty,0 )     
         BEGIN    
            SET @nErrNo = 93809    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCQty'    
            GOTO QUIT    
         END  

       END  
       
       IF ISNULL(RTRIM(@cReplenNo),'')  <> 'RPL-COMBCA' 
       BEGIN
          
          IF ISNULL(@nUCCQty,0) <> ISNULL(@nQty,0 ) 
          BEGIN
            SET @nErrNo = 93802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCQty'
            GOTO QUIT
          END
          
       END
       
       IF ISNULL(RTRIM(@cRefNo),'')  <> '' AND ISNULL(RTRIM(@cReplenNo),'')  <> 'RPL-COMBCA'
       BEGIN
         IF ISNULL(RTRIM(@cLabelNo),'')  <> ISNULL(RTRIM(@cRefNo),'') 
         BEGIN
            SET @nErrNo = 93803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'
            GOTO QUIT
         END
       END
       
       IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK) 
                   WHERE WaveKey = @cWaveKey
                   AND DropID = @cLabelNo ) 
       BEGIN
            SET @nErrNo = 93804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCScanned'
            GOTO QUIT
       END
       
       
       IF EXISTS ( SELECT 1 FROM dbo.WaveDetail WD WITH (NOLOCK)
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
                  INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey  = O.OrderKey
                  INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON PD.PickslipNo = PH.PickslipNo 
                  WHERE WD.WaveKey = @cWaveKey
                  AND PD.DropID = @cLabelNo )
       BEGIN
            SET @nErrNo = 93807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCScanned'
            GOTO QUIT
       END

                  
       
       
       SELECT @cLottable09Validation = Short 
       FROM dbo.Codelkup WITH (NOLOCK) 
       WHERE ListName = 'REPLENUA'
       AND Code = 'LOT09'
       
           
       SELECT @cLottable09 = Lottable09 
       FROM dbo.LotAttribute WITH (NOLOCK)
       WHERE Lot = @cLot 

       
       IF ISNULL(RTRIM(@cLottable09Validation),'')  <> ISNULL(RTRIM(@cLottable09),'') 
       BEGIN
         SET @nErrNo = 93801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLot09'
         GOTO QUIT
       END  
       
       
       IF @cDBName <> 'IDSCN'
       BEGIN
          SELECT TOP 1 
             @cPONumber = UserDefined02
          FROM dbo.UCC WITH (NOLOCK)
          WHERE UCCNo = @cLabelNo 
          AND Status IN ('0', '1') 

          IF ISNULL(RTRIM(@cLottable03),'')  <> ISNULL(RTRIM(@cPONumber),'') 
          BEGIN
            SET @nErrNo = 93808
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PONotMatch'
            GOTO QUIT
          END  
       
       END
       
    END
    
    IF @nStep = 10
    BEGIN
       SELECT  @nInputCount   = I_Field03
              ,@cFromLoc      = V_LOC
              ,@cID           = V_ID
              ,@cWaveKey      = V_String12
       FROM rdt.rdtMobrec WITH (NOLOCK) 
       WHERE Mobile = @nMobile 
       
       --SELECT  @cFromLoc   = FromLoc
       --       ,@cID        = ID 
       --FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
       --WHERE ReplenishmentKey = @cReplenishmentKey
       --GROUP BY Lot, RefNo, WaveKey, ReplenNo, FromLoc, ID

       
       
       SELECT @nCount = Count(RefNo)  FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
       WHERE StorerKey = @cStorerKey
       AND WaveKey = @cWaveKey
       AND FromLoc = @cFromLoc
       AND ID      = @cID
       AND Confirmed = 'N'
       --GROUP BY StorerKey, WaveKey, FromLoc, ID, Confirmed
       
       IF @nInputCount <> @nCount 
       BEGIN
            
            SET @nErrNo = 93810
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CountNotMatch'
            GOTO QUIT
       END
       
       
    END
    
    
    
    
   
END  
  
QUIT:  

 

GO