SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803DecodeSP03                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Lightup the light when show stop                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-02-15  yeekung   1.0   WMS-16066 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_803DecodeSP03] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cStation     NVARCHAR( 10),
   @cMethod      NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cUPC         NVARCHAR( 30)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUCnt int
           ,@bSuccess int
           ,@cDevicePos nvarchar(20)
           ,@cResult01    NVARCHAR( 20)
           ,@cResult02    NVARCHAR( 20)
           ,@cResult03    NVARCHAR( 20)
           ,@cResult04    NVARCHAR( 20)
           ,@cResult05    NVARCHAR( 20)
           ,@cResult06    NVARCHAR( 20)
           ,@cResult07    NVARCHAR( 20)
           ,@cResult08    NVARCHAR( 20)
           ,@cResult09    NVARCHAR( 20)
           ,@cResult10    NVARCHAR( 20)

   DECLARE @cSKU NVARCHAR(20),
         @cReceiptkey NVARCHAR(20),
         @cPOKey NVARCHAR(20),
         @nQty INT,
         @cLoc NVARCHAR(20),
         @cPosition NVARCHAR(20),
         @cLogicalName NVARCHAR(10),
         @cDisplay NVARCHAR(20),
         @cLight NVARCHAR(5)='1',
         @cIPAddress NVARCHAR(20)
                  

   IF @nStep = 3 -- SKU
   BEGIN
      -- Check SKU valid
      IF @cBarcode='STOP'
      BEGIN

         SELECT TOP 1   
           @cReceiptkey=L.BatchKey 
           ,@cPOKey=RD.POKEY
           ,@nQty=CAST(L.userdefine02 AS INT)
           ,@cSKU=L.SKU
           ,@cLoc=L.loc
           ,@cPosition=L.Position
         FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)   
            JOIN receipt R WITH (NOLOCK) ON (R.Receiptkey = L.BatchKey)  
            JOIN receiptdetail RD WITH (NOLOCK) ON (RD.receiptkey = R.receiptkey)  
         WHERE L.Station = @cStation  
            AND ISNULL(L.userdefine02,'')<>''
         ORDER BY L.Position  

          
         SELECT @cLogicalName = LogicalName,@cIPAddress=ipaddress  
         FROM DeviceProfile WITH (NOLOCK)  
         WHERE DeviceType = 'STATION'  
         AND DeviceID = @cStation  
         AND DevicePosition = @cPosition  
         and loc=@cLoc

         set @cDisplay=@cLogicalName+ CAST (@nQty AS NVARCHAR(2))

         SET @cLight=0

          -- Draw matrix (and light up)  
         EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey  
            ,@cLight  
            ,@cStation  
            ,@cMethod  
            ,@cSKU  
            ,@cIPAddress   
            ,@cPosition  
            ,@cDisplay  
            ,@nErrNo     OUTPUT  
            ,@cErrMsg    OUTPUT  
            ,@cResult01  OUTPUT  
            ,@cResult02  OUTPUT  
            ,@cResult03  OUTPUT  
            ,@cResult04  OUTPUT  
            ,@cResult05  OUTPUT  
            ,@cResult06  OUTPUT  
            ,@cResult07  OUTPUT  
            ,@cResult08  OUTPUT  
            ,@cResult09  OUTPUT  
            ,@cResult10  OUTPUT  
         IF @nErrNo <> 0  
            GOTO QUIT

         SET @nErrNo='-1'

      END
   END

Quit:

END

GO