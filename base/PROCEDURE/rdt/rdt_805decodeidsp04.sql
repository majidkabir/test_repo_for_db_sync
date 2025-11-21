SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805DecodeIDSP04                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 25-09-2020 1.0 YeeKung     WMS-14910 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_805DecodeIDSP04] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cScanID      NVARCHAR( 20)  OUTPUT, 
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT,
   @nDefaultSKU  INT  OUTPUT,
   @nDefaultQty  INT  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 805 -- PTLStation
   BEGIN
      DECLARE @cstation1 NVARCHAR(20),
              @cstation2 NVARCHAR(20),
              @cstation3 NVARCHAR(20),
              @cstation4 NVARCHAR(20),
              @cstation5 NVARCHAR(20)
      
      SELECT @cstation1 = v_String1,
             @cstation2 = v_String2,
             @cstation3 = v_String3,
             @cstation4 = v_String4,
             @cstation5 = v_String5
      from rdt.RDTMOBREC (NOLOCK)
      where mobile=@nMobile

      SELECT  TOP 1
              @csku=pd.sku,
              @nqty=SUM(QTY)
      from pickdetail pd (nolock) join 
      rdt.rdtPTLStationLog PSL (nolock) ON
      pd.orderkey=PSL.orderkey and pd.storerkey=PSL.storerkey
      WHERE pd.Storerkey=@cStorerKey
         AND PSL.Station IN (@cstation1,@cstation2,@cstation3,@cstation4,@cstation5)
         AND pd.dropid=@cScanID
         AND pd.Status<5
      group by pd.sku
   END

Quit:

END

GO