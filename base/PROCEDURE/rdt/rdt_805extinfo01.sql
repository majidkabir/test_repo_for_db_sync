SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 28-06-2017 1.0 Ung         WMS-2307 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_805ExtInfo01] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
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

   DECLARE @cStation1 NVARCHAR(10)
   DECLARE @cStation2 NVARCHAR(10)
   DECLARE @cStation3 NVARCHAR(10)
   DECLARE @cStation4 NVARCHAR(10)
   DECLARE @cStation5 NVARCHAR(10)
   DECLARE @nBal      INT

   DECLARE @tOrders TABLE
   (
      OrderKey NVARCHAR(10) NOT NULL
   )
   
   IF @nFunc = 805 -- PTLStation
   BEGIN
      IF @nAfterStep = 3 -- ID/UCC, SKU, QTY
      BEGIN
         -- Variable mapping
         SELECT @cStation1 = Value FROM @tVar WHERE Variable = '@cStation1'
         SELECT @cStation2 = Value FROM @tVar WHERE Variable = '@cStation2'
         SELECT @cStation3 = Value FROM @tVar WHERE Variable = '@cStation3'
         SELECT @cStation4 = Value FROM @tVar WHERE Variable = '@cStation4'
         SELECT @cStation5 = Value FROM @tVar WHERE Variable = '@cStation5'
         
          -- Get orders in station
         INSERT INTO @tOrders (OrderKey) 
         SELECT OrderKey
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND OrderKey <> ''
         
         SELECT @nBal = ISNULL( SUM( PD.QTY), 0)
         FROM @tOrders O 
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN Orders AO WITH (NOLOCK) ON (O.OrderKey = AO.OrderKey ) 
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status <= '5'
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND AO.Status <> 'CANC' 
            AND AO.SOStatus <> 'CANC'
      
         SET @nErrNo = 111701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAL:
         
         SET @cExtendedInfo = RTRIM( @cErrMsg) + ' ' + CAST( @nBal AS NVARCHAR(10))
         
         SET @nErrNo = 0
         SET @cErrMsg = ''
      END
   END

Quit:

END

GO