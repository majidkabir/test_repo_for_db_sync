SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840GetOrders04                                  */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Return orders using pickdetail.dropid                       */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2021-04-20  1.0  James       WMS-16841. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_840GetOrders04]
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

   DECLARE @cTempOrderKey     NVARCHAR( 10) = ''
   DECLARE @nCnt              INT
   
   SET @cOrderKey = ''
   
   IF @nStep IN ( 1, 5) -- OrderKey/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Retrieve orderkey from pickdetail.dropid
         SELECT @cTempOrderKey = OrderKey
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   DropID = @cDropID
         AND   [Status] < '9'
         AND   [Status] <> '4'  
         GROUP BY OrderKey      
         SET @nCnt = @@ROWCOUNT

         IF @cTempOrderKey = ''
         BEGIN
            SET @nErrNo = 166351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Orders
            GOTO Quit
         END
   
         IF @nCnt > 1
         BEGIN
            SET @nErrNo = 166352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID > 1 Orders
            GOTO Quit
         END
         
         SET @cOrderKey = @cTempOrderKey
      END
   END

Quit:
END

GO