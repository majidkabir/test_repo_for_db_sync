SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_514ExtVal05                                     */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-03-26 1.0  James      WMS-8254 Created                          */ 
/* 2023-01-20 1.1  Ung        WMS-21577 Add unlimited UCC to move       */ 
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_514ExtVal05] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC           NVARCHAR( 20), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  

   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @tUCC  TABLE (UCC NVARCHAR( 20), i INT)
   DECLARE @tShipTo TABLE (FromConsigneeKey NVARCHAR( 15), ToConsigneeKey NVARCHAR( 15), i INT)
           
   IF @nFunc = 514 -- Move by UCC
   BEGIN  
      IF @nStep = 1 -- Key in UCC
      BEGIN
         INSERT INTO @tUCC (UCC, i) 
         SELECT UCCNo, RecNo
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()

         IF EXISTS ( SELECT 1 FROM @tUCC t
                     JOIN dbo.UCC UCC WITH (NOLOCK) ON T.UCC = UCC.UCCNo
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON UCC.SKU = SKU.SKU
                     WHERE SKU.StorerKey = @cStorerKey
                     AND   BUSR1 <> 'Y')
         BEGIN
            SET @nErrNo = 136751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Modulized'
            GOTO Quit
         END

         -- Need join ucc here because user might use this as normal move ucc.
         -- Those exists here is for pallet merge
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   EXISTS ( SELECT 1 FROM @tUCC t
                                    WHERE PD.RefNo2 = t.UCC
                                    AND   t.UCC <> '')) AND @cFromID = ''
         BEGIN
            SET @nErrNo = 136752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need From ID'
            GOTO Quit
         END
      END

      IF @nStep = 2 -- To Loc/To ID
      BEGIN
         INSERT INTO @tUCC (UCC, i) 
         SELECT UCCNo, RecNo
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()

         -- Need join ucc here because user might use this as normal move ucc.
         -- Those exists here is for pallet merge
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   EXISTS ( SELECT 1 FROM @tUCC t
                                    WHERE PD.RefNo2 = t.UCC
                                    AND   t.UCC <> '')) AND @cToID = ''
         BEGIN
            SET @nErrNo = 136753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need To ID'
            GOTO Quit
         END

         SELECT TOP 1 @cStatus = PH.Status 
         FROM dbo.PackHeader PH WITH (NOLOCK)
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
         WHERE PD.StorerKey = @cStorerKey
         AND   LabelNo = @cFromID
         ORDER BY 1 DESC   -- Status 9 come first
         
         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 136754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FromIDPackCfm'
            GOTO Quit
         END   

         SELECT TOP 1 @cStatus = PH.Status 
         FROM dbo.PackHeader PH WITH (NOLOCK)
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
         WHERE PD.StorerKey = @cStorerKey
         AND   LabelNo = @cToID
         ORDER BY 1 DESC   -- Status 9 come first
         
         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 136755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToID PackCfm'
            GOTO Quit
         END 

         INSERT INTO @tShipTo (FromConsigneeKey)
         SELECT TOP 1 O.ConsigneeKey
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.ID = @cFromID
         ORDER BY 1

         INSERT INTO @tShipTo (ToConsigneeKey)
         SELECT TOP 1 O.ConsigneeKey
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.ID = @cToID
         ORDER BY 1

         IF EXISTS ( SELECT 1 FROM @tShipTo WHERE FromConsigneeKey <> ToConsigneeKey)
         BEGIN
            SET @nErrNo = 136756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff Ship To'
            GOTO Quit
         END 
      END
   END  


Quit:  

END

GO