SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCReceiveAudit_GetVariance                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 10-Dec-2019  1.0  Chermaine   WMS-11357 - Created                          */
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCReceiveAudit_GetVariance] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 20),
   @cUCCNo        NVARCHAR( 20),
   @cOutField01   NVARCHAR( 60) OUTPUT,
   @cOutField02   NVARCHAR( 60) OUTPUT,
   @cOutField03   NVARCHAR( 60) OUTPUT,
   @cOutField04   NVARCHAR( 60) OUTPUT,
   @cOutField05   NVARCHAR( 60) OUTPUT,
   @cOutField06   NVARCHAR( 60) OUTPUT,
   @cOutField07   NVARCHAR( 60) OUTPUT,
   @cOutField08   NVARCHAR( 60) OUTPUT,
   @cOutField09   NVARCHAR( 60) OUTPUT,
   @cOutField10   NVARCHAR( 60) OUTPUT,
   @cOutField11   NVARCHAR( 60) OUTPUT,
   @cOutField12   NVARCHAR( 60) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE 
@nCount     INT
,@cSKUCode  NVARCHAR( 15)
,@nVariance NVARCHAR( 4)
,@TSQL nvarchar(max) 

SET @nCount = 1


DECLARE @curSKU CURSOR
SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT SKU, CASE WHEN CQty <0 THEN CQty ELSE (CQty - ISNULL(PQty,0)) END AS v
FROM rdt.RDTReceiveAudit WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCCNo
   AND receiptKey = @cReceiptKey
   AND CQty <>  ISNULL(PQty,0)
   
OPEN @curSKU
   FETCH NEXT FROM @curSKU INTO @cSKUCode, @nVariance
   WHILE @@FETCH_STATUS = 0 
   BEGIN
	   IF @nCount = 1
      BEGIN
      	SET @cOutField01  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 2
      BEGIN
      	SET @cOutField02  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 3
      BEGIN
      	SET @cOutField03  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 4
      BEGIN
      	SET @cOutField04  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 5
      BEGIN
      	SET @cOutField05  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 6
      BEGIN
      	SET @cOutField06  = @cSKUCode + ':' +@nVariance
      END
           
      IF @nCount = 7
      BEGIN
      	SET @cOutField07  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 8
      BEGIN
      	SET @cOutField08  = @cSKUCode + ':' +@nVariance
      END
            
      IF @nCount = 9
      BEGIN
      	SET @cOutField09  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 10
      BEGIN
      	SET @cOutField10  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 11
      BEGIN
      	SET @cOutField11  = @cSKUCode + ':' +@nVariance
      END
      
      IF @nCount = 12
      BEGIN
      	SET @cOutField12  = @cSKUCode + ':' +@nVariance
      END
	   
	   SET @nCount = @nCount + 1
	FETCH NEXT FROM @curSKU INTO @cSKUCode, @nVariance 
   END
   

GO