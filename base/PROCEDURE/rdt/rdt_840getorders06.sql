SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840GetOrders06                                  */  
/* Copyright      : LF logistics                                        */  
/*                                                                      */  
/* Purpose: Return orders using PTL piece log (filter qtymoved = 0)     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-07-23  1.0  James       WMS-17435. Created                      */  
/* 2022-02-23  1.1  James       WMS-18931 After tote sort only can start*/
/*                              do packing (james01)                    */
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_840GetOrders06]  
   @nMobile                   INT,  
   @nFunc                     INT,  
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,  
   @nInputKey                 INT,  
   @cStorerkey                NVARCHAR( 15),  
   @cDropID                   NVARCHAR( 20),  
   @tGetOrders                VariableTable READONLY,  
   @cOrderKey                 NVARCHAR( 10) OUTPUT,  
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cTempOrderKey     NVARCHAR( 10)  
   DECLARE @cRefNo            NVARCHAR( 20)  
     
   SELECT @cRefNo = Value FROM @tGetOrders WHERE Variable = '@cRefNo'  
     
   SET @cOrderKey = ''  
     
   IF @nStep IN ( 1, 5) -- OrderKey/DropID  
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN  
         -- Retrieve orderkey from pickdetail.dropid  
         SELECT TOP 1 @cTempOrderKey = PD.OrderKey  
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
         JOIN rdt.rdtPTLPieceLog PTL WITH (NOLOCK) ON ( PD.OrderKey = PTL.OrderKey)  
         WHERE PD.Storerkey = @cStorerkey  
         AND   PD.[Status] < '9'  
         AND   PD.[Status] <> '4'  
         AND   PD.QtyMoved = 0  
         AND   PTL.LOC = @cRefNo  
         ORDER BY 1  
           
         IF ISNULL( @cTempOrderKey, '') = ''  
         BEGIN  
            SET @nErrNo = 171701  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Orders   
            GOTO Quit  
         END  

         IF EXISTS ( SELECT 1   
                     FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                     JOIN rdt.rdtPTLPieceLog PTL WITH (NOLOCK) ON ( PD.OrderKey = PTL.OrderKey)  
                     WHERE PD.Storerkey = @cStorerkey  
                     AND   PD.[Status] < '9'  
                     AND   PD.[Status] <> '4'  
                     AND   PD.QtyMoved = 0  
                     AND   PTL.LOC = @cRefNo  
                     AND   PD.CaseID <> 'SORTED')
         BEGIN  
            SET @nErrNo = 171702  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Sorted   
            GOTO Quit  
         END 
                     
         SET @cOrderKey = @cTempOrderKey  
      END  
   END  
  
Quit:  
END  

GO