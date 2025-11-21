SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840GetOrders08                                  */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Retrieve orderkey from salesman column                      */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2023-07-27  1.0  James       WMS-23152. Created                      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_840GetOrders08]
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

   DECLARE @cRefNo            NVARCHAR( 40)
   
   SET @cOrderKey = ''
   
   IF @nStep IN ( 1, 5) -- OrderKey/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
      	SELECT @cRefNo = Value FROM @tGetOrders WHERE Variable = '@cRefNo'
      	
         -- Retrieve orderkey from pickdetail.dropid
         SELECT TOP 1 @cOrderKey = OrderKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   SalesMan = @cRefNo
         ORDER BY 1
      END
   END

Quit:
END

GO