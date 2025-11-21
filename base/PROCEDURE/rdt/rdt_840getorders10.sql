SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

  
/************************************************************************/  
/* Store procedure: rdt_840GetOrders10                                  */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Purpose: Return orders using PickDetail.Dropid (Status < 5)          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author      Purposes                                */  
/* 2025-02-19  1.0  James       FCR-2690. Created                       */  
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_840GetOrders10]  
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
   DECLARE @curORD            CURSOR  
   DECLARE @nPickQty          INT  
   DECLARE @nPackQty          INT  
   DECLARE @nFound            INT = 0  
  
   SET @cOrderKey = ''  

     
   IF @nStep IN ( 1, 5) -- OrderKey/DropID  
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN  
         SET @curORD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT DISTINCT OrderKey  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   [Status] <> '4'  
         AND   [Status] < '9'  
         AND   DropID = @cDropID  
         ORDER BY 1  
         OPEN @curORD  
         FETCH NEXT FROM @curORD INTO @cTempOrderKey  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  


            SET @nPickQty = 0  
            SELECT @nPickQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE Storerkey = @cStorerKey  
            AND   OrderKey = @cTempOrderKey  
            AND   [Status] <> '4'  
            AND   [Status] < '9'  
            AND   DropID = @cDropID  
  
            SET @nPackQty = 0  
            SELECT @nPackQty = ISNULL( SUM( PD.Qty), 0)  
            FROM dbo.PACKDETAIL PD WITH (NOLOCK)  
            JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)  
            WHERE PH.Storerkey = @cStorerKey  
            AND   PH.OrderKey = @cTempOrderKey  

  
            IF @nPickQty > @nPackQty  
            BEGIN  
               SET @nFound = 1  
               BREAK  
            END  
            FETCH NEXT FROM @curORD INTO @cTempOrderKey  
         END  

           
         IF ISNULL( @cTempOrderKey, '') <> '' AND @nFound = 1  
            SET @cOrderKey = @cTempOrderKey  
      END  
   END  
  
Quit:  
           
END  

GO