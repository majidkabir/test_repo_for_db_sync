SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Store procedure: rdt_1653ExtValid01                                  */        
/* Copyright      : IDS                                                 */        
/*                                                                      */        
/* Called from: rdtfnc_TrackNo_SortToPallet                             */        
/*                                                                      */        
/* Purpose: Insert TrackingID                                           */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2020-08-01  1.0  James    WMS-14248. Created                         */      
/* 2021-08-25  1.1  James    WMS-17773 Extend TrackNo to 40 chars       */
/* 2022-05-12  1.2  James    WMS-19645 Change pallet status to 9 when   */  
/*                           check pallet close (james02)               */  
/* 2022-05-24  1.3  James    WMS-18350 Filter short pick (james01)      */  
/* 2022-09-15  1.4  James    WMS-20667 Add Lane (james03)               */
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_1653ExtValid01] (        
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,    
   @nInputKey      INT,    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cTrackNo       NVARCHAR( 40),    
   @cOrderKey      NVARCHAR( 20),    
   @cPalletKey     NVARCHAR( 20),    
   @cMBOLKey       NVARCHAR( 10),    
   @cLane          NVARCHAR( 20),
   @tExtValidVar   VariableTable READONLY,    
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT    
) AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
       
   DECLARE @nQty_Picked    INT    
   DECLARE @nQty_Packed    INT    
   DECLARE @nMaxParcel     INT    
   DECLARE @nParcelCnt     INT    
   DECLARE @cOrderInfo04   NVARCHAR( 30)    
   DECLARE @cOrderType1    NVARCHAR( 10)    
   DECLARE @cOrderType2    NVARCHAR( 10)    
   DECLARE @cOrder2Check   NVARCHAR( 10)    
       
   IF @nStep = 1    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         -- If it is Sales type order only retrieve based on OrderInfo    
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                         WHERE C.ListName = 'HMORDTYPE'    
                         AND   C.Short = 'S'    
                         AND   O.OrderKey = @cOrderkey    
                         AND   O.StorerKey = @cStorerKey)    
         BEGIN    
            SELECT @cOrderInfo04 = OrderInfo04    
            FROM dbo.OrderInfo WITH (NOLOCK)    
            WHERE OrderKey = @cOrderKey    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)    
                            WHERE LISTNAME = 'HMSORTPLT'    
                            AND   Storerkey = @cStorerKey    
                            AND   Code = @cOrderInfo04)    
            BEGIN    
               SET @nErrNo = 156401    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CODELKUP    
               GOTO Quit    
            END    
         END    
    
         SELECT @nQty_Picked = ISNULL( SUM( Qty), 0)    
         FROM dbo.PickDetail WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
         AND Status <> '4'    -- ZG01  
           
         SELECT @nQty_Packed = ISNULL( SUM( Qty), 0)    
         FROM dbo.PackDetail PD WITH (NOLOCK)    
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)    
         WHERE PH.StorerKey = @cStorerKey    
         AND   PH.OrderKey = @cOrderKey    
    
         IF @nQty_Picked <> @nQty_Packed    
         BEGIN    
            SET @nErrNo = 156402    
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Not Pack    
            GOTO Quit    
         END    
      END       
   END    
    
   IF @nStep = 2    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND [Status] = '9')    
         BEGIN    
            SET @nErrNo = 156404    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Closed     
            GOTO Quit    
         END    
      END    
   END    
       
   IF @nStep = 3    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         -- If it is Sales type order only retrieve based on OrderInfo    
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                         WHERE C.ListName = 'HMORDTYPE'    
                         AND   C.Short = 'S'    
                         AND   O.OrderKey = @cOrderkey    
                         AND   O.StorerKey = @cStorerKey)    
         BEGIN    
            SELECT @cOrderInfo04 = OrderInfo04    
            FROM dbo.OrderInfo WITH (NOLOCK)    
            WHERE OrderKey = @cOrderKey    
             
            SELECT @nMaxParcel = Short    
            FROM dbo.CODELKUP WITH (NOLOCK)    
            WHERE LISTNAME = 'HMSORTPLT'    
            AND   Storerkey = @cStorerKey    
            AND   Code = @cOrderInfo04    
             
            SELECT @nParcelCnt = COUNT( DISTINCT CaseID)    
            FROM dbo.PALLETDETAIL PD WITH (NOLOCK)    
            JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)    
            WHERE P.PalletKey = @cPalletKey    
            AND   P.[Status] = '0'    
            AND   PD.StorerKey = @cStorerKey    
             
            IF @nParcelCnt > ( @nMaxParcel/2)    
            BEGIN    
               SET @nErrNo = 156405    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Limit    
               GOTO Quit    
            END    
         END    
    
         SELECT TOP 1 @cOrder2Check = UserDefine01    
         FROM dbo.PALLETDETAIL PD WITH (NOLOCK)    
         JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)    
         WHERE P.PalletKey = @cPalletKey    
         AND   P.[Status] = '0'    
         AND   PD.StorerKey = @cStorerKey    
         ORDER BY 1    
             
         SET @cOrderType1 = ''    
         SET @cOrderType2 = ''    
             
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                         WHERE C.ListName = 'HMORDTYPE'    
                         AND   C.Short = 'S'    
                         AND   O.OrderKey = @cOrder2Check    
                         AND   O.StorerKey = @cStorerKey)    
            SET @cOrderType1 = 'MOVE'    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                         WHERE C.ListName = 'HMORDTYPE'    
                         AND   C.Short = 'S'    
                         AND   O.OrderKey = @cOrderKey    
                         AND   O.StorerKey = @cStorerKey)    
            SET @cOrderType2 = 'MOVE'    
             
         IF @cOrderType1 <> @cOrderType2    
         BEGIN    
            SET @nErrNo = 156406    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltMix OrdType    
            GOTO Quit    
         END    
      END    
   END    
       
Quit:        
END        

GO