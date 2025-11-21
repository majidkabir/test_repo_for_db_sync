SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840GetOrders03                                  */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Return orders using orders.externorderkey                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-12-17  1.0  James       WMS-15906. Created                      */
/* 2021-09-01  1.1  James       WMS17881-Add UD01 filter (james01)      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_840GetOrders03]
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
   DECLARE @cRefNo            NVARCHAR( 40)
   
   SELECT @cRefNo = Value FROM @tGetOrders WHERE Variable = '@cRefNo'  
   
   SET @cOrderKey = ''
   
   IF @nStep IN ( 1, 5) -- OrderKey/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Retrieve orderkey from pickdetail.dropid
         SELECT TOP 1 @cTempOrderKey = OrderKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   ExternOrderKey = @cRefNo
         AND   [Status] < '9'
         AND   DocType = 'E' 
         AND   UserDefine01 IN ('VC30', 'VCE0')
         ORDER BY 1
         
         IF ISNULL( @cTempOrderKey, '') <> ''
            SET @cOrderKey = @cTempOrderKey
         ELSE
            SET @cOrderKey = @cRefNo
      END
   END

Quit:
END

GO