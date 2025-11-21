SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840GetOrders07                                  */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Return orders using PickDetail.Dropid (Status < 5)          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2021-07-23  1.0  James       WMS-17435. Created                      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_840GetOrders07]
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
   
   SET @cOrderKey = ''
   
   IF @nStep IN ( 1, 5) -- OrderKey/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Retrieve orderkey from pickdetail.dropid
         SELECT TOP 1 @cTempOrderKey = OrderKey
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   [Status] < '5'
         AND   [Status] <> '4'
         AND   QtyMoved = 0
         AND   DropID = @cDropID
         ORDER BY 1
         
         IF ISNULL( @cTempOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 180751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Orders 
            GOTO Quit
         END

         IF EXISTS ( SELECT 1
                     FROM dbo.PICKDETAIL WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey
                     AND   OrderKey = @cTempOrderKey
                     AND   CaseID <> 'SORTED')
         BEGIN
            SET @nErrNo = 180752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Sorted 
            GOTO Quit
         END
         
         SET @cOrderKey = @cTempOrderKey
      END
   END

Quit:
END

GO