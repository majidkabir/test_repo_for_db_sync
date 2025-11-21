SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_808ExtInfo05                                          */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2021-11-21 1.0  yeekung   WMS18418. Created                                */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_808ExtInfo05] (  
   @nMobile        INT,            
   @nFunc          INT,            
   @cLangCode      NVARCHAR( 3),   
   @nStep          INT,            
   @nAfterStep     INT,            
   @nInputKey      INT,            
   @cFacility      NVARCHAR( 5),   
   @cStorerKey     NVARCHAR( 15),  
   @cLight         NVARCHAR( 1),    
   @cDPLKey        NVARCHAR( 10),  
   @cCartID        NVARCHAR( 10),  
   @cPickZone      NVARCHAR( 10),  
   @cMethod        NVARCHAR( 10),  
   @cLOC           NVARCHAR( 10),  
   @cSKU           NVARCHAR( 20),  
   @cToteID        NVARCHAR( 20),  
   @nQTY           INT,            
   @cNewToteID     NVARCHAR( 20),  
   @cLottable01    NVARCHAR( 18),  
   @cLottable02    NVARCHAR( 18),  
   @cLottable03    NVARCHAR( 18),  
   @dLottable04    DATETIME,       
   @dLottable05    DATETIME,       
   @cLottable06    NVARCHAR( 30),  
   @cLottable07    NVARCHAR( 30),  
   @cLottable08    NVARCHAR( 30),  
   @cLottable09    NVARCHAR( 30),  
   @cLottable10    NVARCHAR( 30),  
   @cLottable11    NVARCHAR( 30),  
   @cLottable12    NVARCHAR( 30),  
   @dLottable13    DATETIME,       
   @dLottable14    DATETIME,       
   @dLottable15    DATETIME,       
   @tVar           VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,    
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT     
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cMethodSP SYSNAME  
   DECLARE @cUserName NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
  
   IF @nFunc = 808 -- PTLCart  
   BEGIN  
      IF 3 IN ( @nAfterStep, @nStep) -- SKU  
      BEGIN  
         -- Get method info  
         SET @cMethodSP = ''  
         SELECT @cMethodSP = ISNULL( UDF01, '')  
         FROM CodeLKUP WITH (NOLOCK)   
         WHERE ListName = 'CartMethod'   
            AND Code = @cMethod   
            AND StorerKey = @cStorerKey  
           
         -- Assign PickslipPosTote_Lottable  
         IF @cMethodSP = 'rdt_PTLCart_Assign_WavSKUPosTote'  
         BEGIN  
                 
            SELECT TOP 1 @cExtendedInfo = ISNULL(pd.Notes,'')
            FROM rdt.rdtPTLCartLog CART WITH (NOLOCK)
            JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.Storerkey = CART.StorerKey AND PD.WaveKey = CART.WaveKey AND PD.Sku = CART.SKU
            WHERE CART.StorerKey = @cStorerKey
               AND CART.SKU = @cSKU
               AND PD.LOC = @cLOC
               AND CART.CartID = @cCartID
               AND CART.AddWho = @cUserName
               AND CART.Method = @cMethod
         END  
      END  
   END  
     
Quit:  
  
END  

GO