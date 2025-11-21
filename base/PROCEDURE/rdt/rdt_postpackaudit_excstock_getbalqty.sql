SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PostPackAudit_ExcStock_GetBalQty                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SOS137582 Get Balance QTY from Orders based on Consignee    */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 12-Jun-2006 1.0  MaryVong Created                                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PostPackAudit_ExcStock_GetBalQty] (
   @cStorer             NVARCHAR( 15),
   @cSKU                NVARCHAR( 20),
   @cBatch              NVARCHAR( 15),
   @cLangCode           NVARCHAR( 18),
   @cConsigneeKey       NVARCHAR( 15)    OUTPUT,
   @nBalQTY             INT          OUTPUT,
   @nErrNo              INT          OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   SET @nBalQTY = 0
   SET @nErrNo = 0
   SET @cErrMsg = ''
   
   DECLARE
      @nRecCnt       INT,
      @nCQTY         INT,
      @nPQTY         INT,
      @nPQTY_TypeC   INT,
      @nPQTY_TypeS   INT
      
   SET @nRecCnt = 0    
   SET @nCQTY = 0
   SET @nPQTY = 0
   SET @nPQTY_TypeC = 0
   SET @nPQTY_TypeS = 0
   
   DECLARE @tConsignee TABLE
   (
      RowID            INT NOT NULL IDENTITY( 1, 1),
      ConsigneeKey     NVARCHAR( 15) NOT NULL
   )   
   
   INSERT INTO @tConsignee (ConsigneeKey)
    -- Order Type = 'C'
   SELECT DISTINCT O.ConsigneeKey
   FROM dbo.Orders O (NOLOCK) 
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         INNER JOIN rdt.RDTCSAudit_BatchPO BPO WITH (NOLOCK) ON (BPO.OrderKey = O.OrderKey)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey AND OD.Lottable03 = BPO.PO_No)
   WHERE O.Status < '9'
      AND O.StorerKey = @cStorer
      AND PD.StorerKey = @cStorer
      AND PD.SKU = @cSKU
      AND PD.CaseID = ''
      AND PD.UOM = '6' -- Piece
      AND BPO.Batch = @cBatch
   UNION      
   -- Order Type = 'S'         
   SELECT DISTINCT O.ConsigneeKey
   FROM dbo.Orders O (NOLOCK) 
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
   WHERE O.Status < '9'
      AND O.StorerKey = @cStorer
      AND PD.StorerKey = @cStorer
      AND PD.SKU = @cSKU
      AND PD.CaseID = ''
      AND PD.UOM = '6' -- Piece
      AND OD.LoadKey = @cBatch             

   -- Get no. of consignee
   SELECT @nRecCnt = COUNT(1) FROM @tConsignee

   -- No matched Consignee
   IF @nRecCnt = 0
   BEGIN
      SET @nErrNo = 67201
      SET @cErrMsg = rdt.rdtgetmessage( 67201, @cLangCode, 'DSP') --'No Consignee'
      GOTO Fail
   END

   DECLARE @curCONS CURSOR
   SET @curCONS = CURSOR FOR
      SELECT ConsigneeKey FROM @tConsignee
      ORDER BY RowID
   OPEN @curCONS
   FETCH NEXT FROM @curCONS INTO @cConsigneeKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get the PickDetail balance for the SKU
      SELECT -- Order Type = 'C'
         @nPQTY_TypeC = IsNULL( SUM( DISTINCT PD.QTY), 0)
      FROM dbo.Orders O (NOLOCK) 
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         INNER JOIN rdt.RDTCSAudit_BatchPO BPO WITH (NOLOCK) ON (BPO.OrderKey = O.OrderKey)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey AND OD.Lottable03 = BPO.PO_No)          
      WHERE  O.ConsigneeKey = @cConsigneeKey 
         AND O.Status < '9'
         AND O.Type = 'C'
         AND O.StorerKey = @cStorer 
         AND PD.StorerKey = @cStorer
         AND PD.SKU = @cSKU 
         AND PD.Status = '5' -- picked 
         AND PD.UOM = '6' -- piece only 
         -- Blank   case ID = created from XDOCK allocation
         -- Numeric case ID = created by user in show pick tab
         AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 
         AND BPO.Batch = @cBatch         
      
      SELECT -- Order Type = 'S'
         @nPQTY_TypeS = IsNULL( SUM( DISTINCT PD.QTY), 0)
      FROM dbo.Orders O (NOLOCK) 
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      WHERE  O.ConsigneeKey = @cConsigneeKey 
         AND O.Status < '9'
         AND O.Type = 'S'
         AND O.StorerKey = @cStorer 
         AND PD.StorerKey = @cStorer
         AND PD.SKU = @cSKU 
         AND PD.Status = '5' -- picked 
         AND PD.UOM = '6' -- piece only 
         -- Blank   case ID = created from XDOCK allocation
         -- Numeric case ID = created by user in show pick tab
         AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 
         AND OD.LoadKey = @cBatch

      -- Sum-up QTY
      SET @nPQTY = @nPQTY_TypeC + @nPQTY_TypeS
           
      -- Get the QTY of the SKU currently in all workstation but not yet commit
      SELECT @nCQTY = IsNULL( SUM(CountQTY_B), 0)
      FROM rdt.rdtCSAudit (NOLOCK)
      WHERE StorerKey = @cStorer
         AND ConsigneeKey = @cConsigneeKey
         -- AND Workstation = @cWorkstation -- From all workstation
         AND PalletID = ''
         -- AND CaseID = @cID -- From all cases
         AND SKU = @cSKU
         AND Status = '0'
       
      -- Get Balance QTY
      SET @nBalQTY = @nPQTY - @nCQTY
      
      IF @nBalQTY > 0
         BREAK
      
      FETCH NEXT FROM @curCONS INTO @cConsigneeKey
   END
   CLOSE @curCONS
   DEALLOCATE @curCONS
  
   -- If Balance QTY <= 0, no need to proceed
   IF @nBalQTY <= 0
   BEGIN
      SET @nErrNo = 67202
      SET @cErrMsg = rdt.rdtgetmessage( 67202, @cLangCode, 'DSP') --'No BALQTY'
      GOTO Fail         
   END
      
   Fail: 

END

GO