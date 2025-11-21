SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PostPackAudit_Scan                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Post Pick Packing                                           */
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
/* Date       Rev  Author   Purposes                                    */
/* 2006-03-13 1.0  MaryVong Created                                     */
/* 2007-03-03 1.1  James    Add BatchID                                 */
/* 2009-06-02 1.2  MaryVong SOS137582 Add in Excess Stocks Scanning     */
/* 2015-12-21 1.3  Leong    SOS359525 - Revise variable size.           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PostPackAudit_Scan] (
   @nFunc         INT,
   @cStorer       NVARCHAR( 18),
   @cFacility     NVARCHAR( 5),
   @cWorkstation  NVARCHAR( 15),
   @cConsigneeKey NVARCHAR( 18),
   @cCaseID       NVARCHAR( 20), -- SOS359525
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @nQTY          INT,
   @cRefNo1       NVARCHAR( 20),
   @cRefNo2       NVARCHAR( 20),
   @cRefNo3       NVARCHAR( 20),
   @cRefNo4       NVARCHAR( 20),
   @cRefNo5       NVARCHAR( 20),
   @nErrNo        INT  OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cLangCode     NVARCHAR( 18),
   @nBatchID      INT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @nRowRef INT

-- Check if CSAudit record exists
SELECT TOP 1
   @nRowRef = RowRef
FROM rdt.rdtCSAudit (NOLOCK)
WHERE StorerKey = @cStorer
   AND Workstation = @cWorkstation
   AND CaseID = @cCaseID
   AND RefNo1 = @cRefNo1
   AND RefNo2 = @cRefNo2
   AND RefNo3 = @cRefNo3
   AND RefNo4 = @cRefNo4
   AND RefNo5 = @cRefNo5
   AND SKU = @cSKU
   AND Status = '0' -- Open

IF @@ROWCOUNT = 0
BEGIN
   -- Add CSAudit record
   INSERT INTO rdt.rdtCSAudit
      (StorerKey, Facility, WorkStation, ConsigneeKey, Type, PalletID, CaseID, SKU, Descr,
       RefNo1, RefNo2, RefNo3, RefNo4, RefNo5, CountQTY_A, CountQTY_B, BatchID)
   VALUES
      (@cStorer, @cFacility, @cWorkStation, @cConsigneeKey, 'T', ' ', @cCaseID, @cSKU, @cSKUDescr,
       @cRefNo1, @cRefNo2, @cRefNo3, @cRefNo4, @cRefNo5,
      CASE WHEN @nFunc = 561 THEN @nQTY ELSE 0 END, -- scanner A
      -- SOS137582
      -- CASE WHEN @nFunc = 563 THEN @nQTY ELSE 0 END, -- scanner B
      CASE WHEN @nFunc = 563 OR @nFunc = 894 THEN @nQTY ELSE 0 END, -- scanner B or Excess Stocks Scanning
      @nBatchID)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 60740
      SET @cErrMsg = rdt.rdtgetmessage( 60740, @cLangCode, 'DSP') --'Add QTY fail'
      GOTO Fail
   END
END
ELSE
BEGIN
   -- Update CSAudit record
   UPDATE rdt.rdtCSAudit SET
      CountQTY_A = CASE WHEN @nFunc = 561 THEN CountQTY_A + @nQTY ELSE CountQTY_A END, -- scanner A
      -- SOS137582
      -- CountQTY_B = CASE WHEN @nFunc = 563 THEN CountQTY_B + @nQTY ELSE CountQTY_B END  -- scanner B
      CountQTY_B = CASE WHEN @nFunc = 563 OR @nFunc = 894 THEN CountQTY_B + @nQTY ELSE CountQTY_B END  -- scanner B or Excess Stocks Scanning
   WHERE RowRef = @nRowRef
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 60741
      SET @cErrMsg = rdt.rdtgetmessage( 60741, @cLangCode, 'DSP') --'Update QTY fail'
      GOTO Fail
   END
END
RETURN

Fail:


GO