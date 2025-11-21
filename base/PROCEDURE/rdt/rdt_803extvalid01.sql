SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_803ExtValid01                                   */  
/* Purpose: Check whether station has orders not yet picked             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-11-21 1.0  James      WMS-11427. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_803ExtValid01] (  
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,  
   @nInputKey    INT,  
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15),  
   @cStation     NVARCHAR( 10),  
   @cMethod      NVARCHAR( 1),  
   @cSKU         NVARCHAR( 20),  
   @cLastPos     NVARCHAR( 10),  
   @cOption      NVARCHAR( 1),  
   @tExtValid    VariableTable READONLY,  
   @nErrNo       INT            OUTPUT,  
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cOrderKey   NVARCHAR( 10) = '',  
           @cLoadKey    NVARCHAR( 10) = '',  
           @cPosition   NVARCHAR( 10) = '',  
           @cErrMsg01   NVARCHAR( 20) = '',  
           @cErrMsg02   NVARCHAR( 20) = '',  
           @cErrMsg03   NVARCHAR( 20) = '',  
           @cErrMsg04   NVARCHAR( 20) = '',  
           @cErrMsg05   NVARCHAR( 20) = ''  
  
   SET @nErrNo = 0  
  
   IF @nStep = 1  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SELECT TOP 1 @cOrderKey = PTL.OrderKey,   
                      @cPosition = ptl.Position  
         FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)  
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey)  
         WHERE PTL.Station = @cStation   
         AND   PTL.Method = @cMethod   
         AND   PTL.SourceKey <> ''  
         AND   ISNULL( PD.Notes, '') <> 'SORTED'  
         ORDER BY 1  
  
         IF ISNULL( @cOrderKey, '') <> ''  
         BEGIN  
            SELECT @cLoadKey = LoadKey  
            FROM dbo.ORDERS WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
              
            SET @nErrNo = 0  
            SET @cErrMsg01 = rdt.rdtgetmessage( 147601, @cLangCode, 'DSP') + ' ' + @cPosition  
            SET @cErrMsg02 = rdt.rdtgetmessage( 147602, @cLangCode, 'DSP') + ': ' + @cOrderKey  
            SET @cErrMsg03 = rdt.rdtgetmessage( 147603, @cLangCode, 'DSP') + ': ' + @cLoadKey  
            SET @cErrMsg04 = rdt.rdtgetmessage( 147604, @cLangCode, 'DSP')  
  
            SET @nErrNo = 147604  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
         END  
      END  
   END  
     
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @cOption = '9'  
         BEGIN  
            SET @nErrNo = 147605  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --UNASSIGN CART  
         END  
      END  
   END  
     
   Quit:  

GO