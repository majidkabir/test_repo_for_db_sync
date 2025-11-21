SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: ispLFALblNoDecode04                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 26-05-2015  1.0  ChewKP      SOS#342416. Created                     */  
/* 25-06-2018  1.1  James       WMS5311-Add function id, step (james01) */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispLFALblNoDecode04]  
   @c_LabelNo           NVARCHAR(40),  
   @c_Storerkey         NVARCHAR(15),  
   @c_ReceiptKey        NVARCHAR(10),  
   @c_POKey             NVARCHAR(10),  
   @c_LangCode          NVARCHAR(3),  
   @c_oFieled01         NVARCHAR(20) OUTPUT,  
   @c_oFieled02         NVARCHAR(20) OUTPUT,  
   @c_oFieled03         NVARCHAR(20) OUTPUT,  
   @c_oFieled04         NVARCHAR(20) OUTPUT,  
   @c_oFieled05         NVARCHAR(20) OUTPUT,  
   @c_oFieled06         NVARCHAR(20) OUTPUT,  
   @c_oFieled07         NVARCHAR(20) OUTPUT,  
   @c_oFieled08         NVARCHAR(20) OUTPUT,  
   @c_oFieled09         NVARCHAR(20) OUTPUT,  
   @c_oFieled10         NVARCHAR(20) OUTPUT,  
   @b_Success           INT = 1  OUTPUT,  
   @n_ErrNo             INT      OUTPUT,   
   @c_ErrMsg            NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @cSKU       NVARCHAR( 20),  
            @nQty       INT,  
            @nStep      INT,  
            @nSKUCnt    INT,  
            @nMobileNo  INT,  
            @nFunc      INT,  
            @nCountSKU  INT,  
            @cFromLoc   NVARCHAR(10),  
            @cFromID    NVARCHAR(18),  
            @cWaveKey   NVARCHAR(10),  
            @cReplenishmentKey NVARCHAR(10),
            @cUserName  NVARCHAR(18),
            @nCombineQty INT,
            @cRefNo     NVARCHAR(20),
            @cNotAllowSwapUCC      NVARCHAR(1),
            @cLot                  NVARCHAR(10),
            @cSuggSKU              NVARCHAR(20),
            @cLottable11           NVARCHAR(30),
            @cNotConfirmDPPReplen  NVARCHAR(1)

   SELECT @nStep = Step  
         ,@nFunc = Func  
         ,@nMobileNo = Mobile  
         ,@cFromLoc = V_Loc  
         ,@cFromID  = V_ID  
         ,@cWaveKey = V_String12 
         ,@cUserName = UserName
         ,@cLot     = V_Lot
         ,@cSuggSKU = V_String15
   FROM rdt.rdtMobrec WITH (NOLOCK)  
   WHERE UserName = (suser_sname())  

   IF @nFunc = 513
   BEGIN
      IF @nStep = 3
         GOTO DECODE_SKU
      ELSE
         GOTO Quit
   END

   DECODE_SKU:
   SET @cNotAllowSwapUCC = rdt.RDTGetConfig( @nFunc, 'NotAllowSwapUCC', @c_StorerKey)  
   IF @cNotAllowSwapUCC = '0'  
   BEGIN  
         SET @cNotAllowSwapUCC = ''  
   END  
     

   SET @cNotConfirmDPPReplen = rdt.RDTGetConfig( @nFunc, 'NotConfirmDPPReplen', @c_StorerKey)  
   IF @cNotConfirmDPPReplen = '0'  
      SET @cNotConfirmDPPReplen = ''  
   SET @c_oFieled01 = ''  
   SET @c_oFieled05 = ''  
   
     
   SELECT @cSKU = SKU  
         ,@nQty = Qty  
   FROM dbo.UCC WITH (NOLOCK)  
   WHERE StorerKey = @c_StorerKey  
     AND UCCNo = @c_LabelNo  
     AND Status IN ( '0','1')   
   
   
   IF @cNotAllowSwapUCC = '1' --UA HK Requirement
   BEGIN
      
      IF @cSKU <> @cSuggSKU 
      BEGIN

         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                        WHERE StorerKey = @c_Storerkey
                        AND WaveKey = @cWaveKey
                        AND FromLoc = @cFromLoc  
                        AND ID  = @cFromID  
                        --AND SKU = @cSKU  
                        AND RefNo = @c_LabelNo
                        --AND Confirmed = 'N'
                        AND Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE Confirmed END
                        AND Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN Remark ELSE 'NOTVERIFY' END)
         BEGIN
         
            SET @c_ErrMsg = 'SuggSKUNotSame'  
            GOTO QUIT  
         END
      END
      

      
--      SELECT @cLottable11 = Lottable11 
--      FROM dbo.LotAttribute WITH (NOLOCK)
--      WHERE Lot = @cLot
--      AND StorerKey = @c_StorerKey
--      AND SKU = @cSKU
--      
--      IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--                  WHERE WaveKey = @cWaveKey
--                  AND StorerKey = @c_StorerKey
--                  AND SKU = @cSKU
--                  AND Lot = @cLot
--                  AND FromLoc = @cFromLoc
--                  AND ID = @cFromID
--                  AND ReplenNo <> 'RPL-COMBCA'  
--                  AND RefNo <> ''
--                  AND Confirmed = 'N' ) 
--      BEGIN
--         IF @c_LabelNo <> @cLottable11 
--         BEGIN
--            SET @c_ErrMsg = 'InvalidUCC'  
--            GOTO QUIT  
--         END
--      END
      
      
   END
     
  
     
   SELECT @nCountSKU = Count(Distinct SKU)  FROM dbo.UCC (NOLOCK)  
   WHERE StorerKey = @c_StorerKey  
   AND UCCNo = @c_LabelNo  
  
   IF @nFunc = 513   
   BEGIN  
      IF ISNULL(@nCountSKU , 0 ) > 1                  
      BEGIN  
         SET @c_ErrMsg = 'MULTI SKU UCC'  
         GOTO QUIT  
      END  
   END  
     
   IF ISNULL(RTRIM(@cSKU),'')  = ''  
   BEGIN  
           
           
       EXEC [RDT].[rdt_GETSKUCNT]  
        @cStorerKey  = @c_Storerkey  
       ,@cSKU        = @c_LabelNo  
       ,@nSKUCnt     = @nSKUCnt       OUTPUT  
       ,@bSuccess    = @b_Success     OUTPUT  
       ,@nErr        = @n_ErrNo       OUTPUT  
       ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
       -- Validate SKU/UPC  
       IF @nSKUCnt = 0  
       BEGIN  
          SET @c_ErrMsg = 'INVALID SKU'  
          GOTO QUIT  
       END  
  
       EXEC [RDT].[rdt_GETSKU]  
        @cStorerKey  = @c_Storerkey  
       ,@cSKU        = @c_LabelNo     OUTPUT  
       ,@bSuccess    = @b_Success     OUTPUT  
       ,@nErr        = @n_ErrNo       OUTPUT  
       ,@cErrMsg     = @c_ErrMsg      OUTPUT  
         
       SET @c_oFieled01 = @c_LabelNo 
       SET @c_oFieled05 = ''
--       IF NOT EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)   
--                   WHERE StorerKey = @c_Storerkey  
--                   AND SKU = @c_LabelNo )   
--       BEGIN  
--          SET @c_ErrMsg = 'INVALID SKU'  
--          GOTO QUIT  
--       END  
--       ELSE  
--       BEGIN  
--         SET @c_oFieled01 = @c_LabelNo  
--         SET @c_oFieled05 = ''  
--       END  
   END  
   ELSE  
   BEGIN  

      

         -- Get ReplenishmentKey If LabelNo Scanned is Exists in the FromLoc, ID in the Replenishment  
         IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)  
                     WHERE StorerKey = @c_Storerkey
                     AND WaveKey = @cWaveKey   
                     AND FromLoc = @cFromLoc  
                     AND ID  = @cFromID  
                     AND SKU = @cSKU  
                     --AND Confirmed = 'N' 
                     AND Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE Confirmed END
                     AND Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN Remark ELSE 'NOTVERIFY' END
                     AND ReplenNo = 'RPL-COMBCA'  )
                     --AND Qty = @nQty )   
         BEGIN  

            DECLARE CursorReplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
      
            SELECT DISTINCT RefNo 
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @c_Storerkey    
            AND WaveKey = @cWaveKey       
            AND FromLoc = @cFromLoc      
            AND ID  = @cFromID      
            AND SKU = @cSKU      
            --AND Confirmed = 'N'     
            AND Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE Confirmed END
            AND Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN Remark ELSE 'NOTVERIFY' END
            AND ReplenNo = 'RPL-COMBCA' 
                        
            OPEN CursorReplen            
            
            FETCH NEXT FROM CursorReplen INTO @cRefNo
            WHILE @@FETCH_STATUS <> -1     
            BEGIN
               
               SELECT @nCombineQty = SUM(QTY) 
               FROM rdt.rdtReplenishmentLog WITH (NOLOCK) 
               WHERE StorerKey = @c_Storerkey    
               AND WaveKey = @cWaveKey       
               AND FromLoc = @cFromLoc      
               AND ID  = @cFromID      
               AND SKU = @cSKU      
               AND Confirmed = 'N'     
               AND ReplenNo = 'RPL-COMBCA' 
               AND RefNo = @cRefNo
               
               IF @nCombineQty = @nQty 
               BEGIN            
               
                  SELECT Top 1 @cReplenishmentKey = ReplenishmentKey      
                  FROM rdt.rdtReplenishmentLog WITH (NOLOCK)      
                  WHERE StorerKey = @c_Storerkey       
                  AND WaveKey = @cWaveKey      
                  AND FromLoc = @cFromLoc      
                  AND ID  = @cFromID      
                  AND SKU = @cSKU      
                  AND Confirmed = 'N'     
                  AND AddWho = @cUserName      
                  --AND Qty = @nQty      
                  AND ReplenNo = 'RPL-COMBCA'   
                  AND RefNo = @cRefNo 
                  Order By ReplenishmentKey   
                  
                  BREAK 
               END  
              
               FETCH NEXT FROM CursorReplen INTO @cRefNo
            END
            CLOSE CursorReplen            
            DEALLOCATE CursorReplen  
    
   
         END
         
       IF ISNULL(RTRIM(@cReplenishmentKey),'')  = ''
       BEGIN 
            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                     WHERE StorerKey = @c_Storerkey
                     AND WaveKey = @cWaveKey
                     AND FromLoc = @cFromLoc  
                     AND ID  = @cFromID  
                     AND SKU = @cSKU  
                     AND RefNo = @c_LabelNo
                     --AND Confirmed = 'N'
                     AND Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE Confirmed END
                     AND Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN Remark ELSE 'NOTVERIFY' END)
            BEGIN
               SELECT   
               Top 1 @cReplenishmentKey = ReplenishmentKey  
               FROM rdt.rdtReplenishmentLog WITH (NOLOCK)  
               WHERE StorerKey = @c_Storerkey   
               AND WaveKey = @cWaveKey  
               AND FromLoc = @cFromLoc  
               AND ID  = @cFromID  
               AND SKU = @cSKU  
               --AND Confirmed = 'N'   
               AND Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE Confirmed END
               AND Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN Remark ELSE 'NOTVERIFY' END
               --AND Qty = @nQty  
               AND RefNo = @c_LabelNo
               AND AddWho = @cUserName
               Order By ReplenishmentKey  
            END
            ELSE
            BEGIN
               
               
               SELECT   
               Top 1 @cReplenishmentKey = ReplenishmentKey  
               FROM rdt.rdtReplenishmentLog WITH (NOLOCK)  
               WHERE StorerKey = @c_Storerkey   
               AND WaveKey = @cWaveKey  
               AND FromLoc = @cFromLoc  
               AND ID  = @cFromID  
               AND SKU = @cSKU  
               --AND Confirmed = 'N'   
               AND Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE Confirmed END
               AND Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN Remark ELSE 'NOTVERIFY' END
               AND Qty = @nQty  
               AND AddWho = @cUserName
               Order By ReplenishmentKey  
               
               
            END  
       END
       
       IF @cReplenishmentKey <> ''   
       BEGIN  
          SET @c_oFieled01 = @cSKU  

          -- Get correct UCC Qty by SKU
          IF @cSKU = @cSuggSKU  
          BEGIN
            SET @c_oFieled05 = @nQty  
          END
          ELSE
          BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                        WHERE StorerKey = @c_StorerKey
                        AND UCCNo = @c_LabelNo
                        AND SKU = @cSuggSKU ) 
            BEGIN
                  SELECT @nQty = Qty  
                  FROM dbo.UCC WITH (NOLOCK)  
                  WHERE StorerKey = @c_StorerKey  
                    AND UCCNo = @c_LabelNo  
                    AND SKU   = @cSuggSKU
                    AND Status IN ( '0','1')   
                    
                  SET @c_oFieled05 = @nQty  
            END
          END

          SET @c_oFieled09 = @cReplenishmentKey  
       END  
       ELSE  
       BEGIN  
          SET @c_ErrMsg = 'INVALID UCC'  
          GOTO QUIT  
       END  
   END  
  
     
     
     
     
QUIT:  
END -- End Procedure  


GO